import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_history_service.dart';
import '../services/usage_logger.dart';
import 'emergency_history_screen.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

const Color _bg = Color(0xFF020607);
const Color _card = Color(0xFF121417);
const Color _border = Color(0xFF2D3238);
const Color _red = Color(0xFFE81218);
const Color _green = Color(0xFF39D74A);
const Color _muted = Color(0xFFB7BABF);
const String _ambulanceNumber = '123';
const int _sosHoldSeconds = 3;

enum _SosStage { button, activated, help, details, tracking, resolved }

class EmergencyServicesScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  const EmergencyServicesScreen({super.key, this.onLocaleChanged});

  @override
  State<EmergencyServicesScreen> createState() =>
      _EmergencyServicesScreenState();
}

class _EmergencyServicesScreenState extends State<EmergencyServicesScreen> {
  _SosStage _stage = _SosStage.button;
  Timer? _countdownTimer;
  Timer? _autoFlowTimer;
  int _countdown = _sosHoldSeconds;
  String _locationText = '5th Settlement, New Cairo,\nCairo Governorate, Egypt';
  bool _shareLocation = true;
  bool _isHoldingSos = false;
  bool _sosLogged = false;
  bool _notifiedContacts = false;
  bool _contactedServices = false;
  bool _dispatchingAmbulance = false;

  @override
  void initState() {
    super.initState();
    UsageLogger.logScreenView('EmergencyServicesScreen');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoFlowTimer?.cancel();
    super.dispose();
  }

  void _startSosHold() {
    if (_stage != _SosStage.button || _isHoldingSos) return;

    _countdownTimer?.cancel();
    _autoFlowTimer?.cancel();
    setState(() {
      _isHoldingSos = true;
      _countdown = _sosHoldSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        _completeSosHold();
        return;
      }
      setState(() => _countdown--);
    });
  }

  void _cancelSosHold() {
    if (!_isHoldingSos) return;

    _countdownTimer?.cancel();
    setState(() {
      _isHoldingSos = false;
      _countdown = _sosHoldSeconds;
    });
  }

  Future<void> _completeSosHold() async {
    if (!_isHoldingSos) return;

    _countdownTimer?.cancel();
    setState(() => _isHoldingSos = false);
    await _activateSos();
  }

  Future<void> _activateSos() async {
    _countdownTimer?.cancel();
    setState(() {
      _stage = _SosStage.activated;
      _isHoldingSos = false;
      _notifiedContacts = false;
      _contactedServices = false;
      _dispatchingAmbulance = true;
    });

    await _callEmergencyServices();
    await _resolveLocation();

    if (!_sosLogged) {
      _sosLogged = true;
      await EmergencyHistoryService.logEvent(
        type: 'sos',
        title: 'SOS Activated',
        description: 'SOS flow activated from app',
        location: _locationText.replaceAll('\n', ' '),
        status: 'In Progress',
      );
    }

    if (!mounted) return;

    setState(() => _notifiedContacts = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _contactedServices = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _dispatchingAmbulance = false);

    _scheduleStage(_SosStage.help, const Duration(seconds: 1));
  }

  Future<void> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _locationText =
          'Lat ${position.latitude.toStringAsFixed(4)}, '
          'Lng ${position.longitude.toStringAsFixed(4)}';
    } catch (_) {
      // Keep the mock-friendly fallback location.
    }
  }

  void _scheduleStage(_SosStage nextStage, Duration delay) {
    _autoFlowTimer?.cancel();
    _autoFlowTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _stage = nextStage);
    });
  }

  void _setStage(_SosStage stage) {
    _autoFlowTimer?.cancel();
    setState(() => _stage = stage);
  }

  Future<void> _callEmergencyServices() async {
    final uri = Uri(scheme: 'tel', path: _ambulanceNumber);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start the ambulance call.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start the ambulance call.')),
      );
    }
  }

  void _openBottomTab(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoiceAssistantScreen()),
      );
      return;
    }
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EmergencyHistoryScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettingsScreen(onLocaleChanged: widget.onLocaleChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _bg,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            children: [
              _SosHeader(
                title: _titleForStage,
                showCancel: _stage == _SosStage.activated,
                onCancel: () => _setStage(_SosStage.button),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStage(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _SosBottomNavigationBar(onTap: _openBottomTab),
      ),
    );
  }

  String get _titleForStage {
    switch (_stage) {
      case _SosStage.activated:
        return 'SOS ACTIVATED';
      case _SosStage.help:
        return 'HELP IS ON THE WAY!';
      case _SosStage.details:
        return 'EMERGENCY DETAILS';
      case _SosStage.tracking:
        return 'LIVE TRACKING';
      case _SosStage.resolved:
        return 'EMERGENCY RESOLVED';
      case _SosStage.button:
        return 'SOS';
    }
  }

  Widget _buildStage() {
    switch (_stage) {
      case _SosStage.button:
        return _SosButtonStage(
          key: const ValueKey('button'),
          isHolding: _isHoldingSos,
          secondsRemaining: _countdown,
          onHoldStart: _startSosHold,
          onHoldCancel: _cancelSosHold,
        );
      case _SosStage.activated:
        return _ActivatedStage(
          key: const ValueKey('activated'),
          notifiedContacts: _notifiedContacts,
          contactedServices: _contactedServices,
          dispatchingAmbulance: _dispatchingAmbulance,
        );
      case _SosStage.help:
        return _HelpStage(
          key: const ValueKey('help'),
          location: _locationText,
          shareLocation: _shareLocation,
          onShareChanged: (value) => setState(() => _shareLocation = value),
          onNext: () => _setStage(_SosStage.details),
        );
      case _SosStage.details:
        return _DetailsStage(
          key: const ValueKey('details'),
          onCall: _callEmergencyServices,
          onNext: () => _setStage(_SosStage.tracking),
        );
      case _SosStage.tracking:
        return _TrackingStage(
          key: const ValueKey('tracking'),
          onResolved: () => _setStage(_SosStage.resolved),
        );
      case _SosStage.resolved:
        return _ResolvedStage(
          key: const ValueKey('resolved'),
          onSummary: () => _setStage(_SosStage.details),
          onHome: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        );
    }
  }
}

class _SosHeader extends StatelessWidget {
  final String title;
  final bool showCancel;
  final VoidCallback onCancel;

  const _SosHeader({
    required this.title,
    required this.showCancel,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (showCancel)
            Positioned(
              right: 0,
              top: 1,
              child: TextButton.icon(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  minimumSize: const Size(0, 30),
                  backgroundColor: Colors.white.withValues(alpha: 0.09),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.close, color: Colors.white, size: 14),
                label: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SosButtonStage extends StatelessWidget {
  final bool isHolding;
  final int secondsRemaining;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldCancel;

  const _SosButtonStage({
    super.key,
    required this.isHolding,
    required this.secondsRemaining,
    required this.onHoldStart,
    required this.onHoldCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => onHoldStart(),
          onPointerUp: (_) => onHoldCancel(),
          onPointerCancel: (_) => onHoldCancel(),
          child: _SosHoldButton(
            isHolding: isHolding,
            secondsRemaining: secondsRemaining,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          isHolding ? 'Keep holding' : 'Hold 3 Seconds',
          style: TextStyle(
            color: _red,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'What happens when you press SOS?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: 'Your location will be shared',
              ),
              SizedBox(height: 14),
              _InfoRow(
                icon: Icons.groups_outlined,
                text: 'Emergency contacts will be notified',
              ),
              SizedBox(height: 14),
              _InfoRow(
                icon: Icons.emergency_share_outlined,
                text: 'Ambulance will be dispatched',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivatedStage extends StatelessWidget {
  final bool notifiedContacts;
  final bool contactedServices;
  final bool dispatchingAmbulance;

  const _ActivatedStage({
    super.key,
    required this.notifiedContacts,
    required this.contactedServices,
    required this.dispatchingAmbulance,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 14),
        const _PulseSosButton(size: 166),
        const SizedBox(height: 14),
        const Text(
          'Sending your location...',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _DarkCard(
          child: Column(
            children: [
              _ProgressRow(
                text: 'Notifying emergency contacts',
                done: notifiedContacts,
              ),
              const SizedBox(height: 16),
              _ProgressRow(
                text: 'Contacting emergency services',
                done: contactedServices,
              ),
              const SizedBox(height: 16),
              _ProgressRow(
                text: 'Dispatching ambulance',
                done: !dispatchingAmbulance,
                loading: dispatchingAmbulance,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpStage extends StatelessWidget {
  final String location;
  final bool shareLocation;
  final ValueChanged<bool> onShareChanged;
  final VoidCallback onNext;

  const _HelpStage({
    super.key,
    required this.location,
    required this.shareLocation,
    required this.onShareChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: const [
              Positioned.fill(child: CustomPaint(painter: _CityPainter())),
              Positioned(bottom: 0, child: _AmbulanceIcon()),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DarkCard(
          child: Column(
            children: const [
              Text(
                'Estimated Time of Arrival',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              SizedBox(height: 10),
              Text(
                '6 min',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.location_on_outlined, text: location),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.share_location_outlined,
                    color: _green,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Share Live Location',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Switch(
                    value: shareLocation,
                    activeColor: _green,
                    onChanged: onShareChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(text: 'View Emergency Details', onPressed: onNext),
      ],
    );
  }
}

class _DetailsStage extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onNext;

  const _DetailsStage({super.key, required this.onCall, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Who was contacted',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              SizedBox(height: 14),
              _ContactRow(
                name: 'Amir (Brother)',
                phone: '01030802134',
                status: 'Notified',
                time: '10:30 AM',
                icon: Icons.person,
              ),
              SizedBox(height: 12),
              _ContactRow(
                name: 'Nayera (Mom)',
                phone: '01012345678',
                status: 'Notified',
                time: '10:30 AM',
                icon: Icons.person,
              ),
              SizedBox(height: 12),
              _ContactRow(
                name: 'Hospital',
                phone: 'Dar Al Fouad Hospital',
                status: 'Contacted',
                time: '10:31 AM',
                icon: Icons.local_hospital,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Ambulance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 14),
              _DetailLine(label: 'Provider', value: 'AMN Emergency'),
              SizedBox(height: 12),
              _DetailLine(label: 'Status', value: 'On the way'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(text: 'Call Emergency Services', onPressed: onCall),
        const SizedBox(height: 12),
        _SecondaryButton(text: 'Open Live Tracking', onPressed: onNext),
      ],
    );
  }
}

class _TrackingStage extends StatelessWidget {
  final VoidCallback onResolved;

  const _TrackingStage({super.key, required this.onResolved});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const SizedBox(
            height: 236,
            width: double.infinity,
            child: CustomPaint(painter: _TrackingMapPainter()),
          ),
        ),
        const SizedBox(height: 14),
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Ambulance is on the way',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '6 min away   •   2.4 km',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFF2A3137),
                    child: Icon(Icons.person, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Ahmed Hassan',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '4.8 ★',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _red,
                    child: Icon(Icons.call, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(text: 'Mark Emergency Resolved', onPressed: onResolved),
      ],
    );
  }
}

class _ResolvedStage extends StatelessWidget {
  final VoidCallback onSummary;
  final VoidCallback onHome;

  const _ResolvedStage({
    super.key,
    required this.onSummary,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Container(
          width: 174,
          height: 174,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _green.withValues(alpha: 0.22),
          ),
          child: Center(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withValues(alpha: 0.88),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 78),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'We hope you are safe',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Thank you for using AMN.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 34),
        _SecondaryButton(text: 'View Summary', onPressed: onSummary),
        const SizedBox(height: 12),
        _SecondaryButton(text: 'Back to Home', onPressed: onHome),
      ],
    );
  }
}

class _SosHoldButton extends StatelessWidget {
  final bool isHolding;
  final int secondsRemaining;

  const _SosHoldButton({
    required this.isHolding,
    required this.secondsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    if (!isHolding) {
      return const _PulseSosButton(size: 188);
    }

    final safeSeconds = secondsRemaining.clamp(1, _sosHoldSeconds).toInt();
    final progress = safeSeconds / _sosHoldSeconds;

    return SizedBox(
      width: 188,
      height: 188,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: const Color(0xFF151B20),
              color: _red,
              strokeCap: StrokeCap.round,
            ),
          ),
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF4A4D), width: 6),
              boxShadow: [
                BoxShadow(
                  color: _red.withValues(alpha: 0.45),
                  blurRadius: 26,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$safeSeconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseSosButton extends StatelessWidget {
  final double size;

  const _PulseSosButton({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.32),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: size * 0.67,
            height: size * 0.67,
            decoration: BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF4A4D), width: 6),
              boxShadow: [
                BoxShadow(
                  color: _red.withValues(alpha: 0.45),
                  blurRadius: 26,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkCard extends StatelessWidget {
  final Widget child;

  const _DarkCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String text;
  final bool done;
  final bool loading;

  const _ProgressRow({
    required this.text,
    required this.done,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.radio_button_checked, color: Colors.white70, size: 17),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        if (loading)
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2, color: _muted),
          )
        else if (done)
          const Icon(Icons.check_circle, color: _green, size: 18),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String name;
  final String phone;
  final String status;
  final String time;
  final IconData icon;

  const _ContactRow({
    required this.name,
    required this.phone,
    required this.status,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: icon == Icons.local_hospital
              ? Colors.white
              : const Color(0xFFFFE1D8),
          child: Icon(
            icon,
            color: icon == Icons.local_hospital
                ? _red
                : const Color(0xFFD06A50),
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, color: _green, size: 13),
              ],
            ),
            const SizedBox(height: 3),
            Text(time, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _card,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _AmbulanceIcon extends StatelessWidget {
  const _AmbulanceIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 82,
      child: CustomPaint(painter: _AmbulancePainter()),
    );
  }
}

class _AmbulancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = Colors.white;
    final redPaint = Paint()..color = _red;
    final dark = Paint()..color = const Color(0xFF1B2228);
    final glass = Paint()..color = const Color(0xFFB9D4E3);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(18, 25, size.width - 36, 38),
      const Radius.circular(7),
    );
    canvas.drawRRect(bodyRect, body);
    canvas.drawRect(Rect.fromLTWH(35, 13, 62, 25), body);
    canvas.drawRect(Rect.fromLTWH(41, 18, 26, 17), glass);
    canvas.drawRect(Rect.fromLTWH(72, 18, 20, 17), glass);
    canvas.drawRect(Rect.fromLTWH(102, 38, 26, 7), redPaint);
    canvas.drawRect(Rect.fromLTWH(113, 28, 6, 26), redPaint);
    canvas.drawCircle(Offset(48, 65), 11, dark);
    canvas.drawCircle(Offset(123, 65), 11, dark);
    canvas.drawCircle(Offset(48, 65), 5, Paint()..color = Colors.white70);
    canvas.drawCircle(Offset(123, 65), 5, Paint()..color = Colors.white70);
    canvas.drawRect(Rect.fromLTWH(75, 8, 18, 5), redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CityPainter extends CustomPainter {
  const _CityPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF151A20);
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [_red.withValues(alpha: 0.38), Colors.transparent],
          ).createShader(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height * 0.72),
              width: size.width * 0.9,
              height: size.height * 0.8,
            ),
          );

    canvas.drawRect(Offset.zero & size, glow);
    final widths = [18.0, 28.0, 20.0, 34.0, 22.0, 26.0, 18.0];
    var x = size.width * 0.12;
    for (var i = 0; i < widths.length; i++) {
      final h = 45 + (i % 3) * 18.0;
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, widths[i], h), paint);
      x += widths[i] + 12;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrackingMapPainter extends CustomPainter {
  const _TrackingMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF11161A),
    );

    final grid = Paint()
      ..color = const Color(0xFF2A333A)
      ..strokeWidth = 1;
    for (double x = -20; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x + 45, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 18), grid);
    }

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.72)
      ..lineTo(size.width * 0.35, size.height * 0.63)
      ..lineTo(size.width * 0.42, size.height * 0.48)
      ..lineTo(size.width * 0.58, size.height * 0.43)
      ..lineTo(size.width * 0.76, size.height * 0.32);

    canvas.drawPath(
      route,
      Paint()
        ..color = _red
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      route.shift(const Offset(2, -2)),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    final pin = Offset(size.width * 0.82, size.height * 0.26);
    canvas.drawCircle(pin, 14, Paint()..color = _red);
    canvas.drawCircle(pin, 5, Paint()..color = _bg);

    canvas.save();
    canvas.translate(size.width * 0.15, size.height * 0.66);
    _AmbulancePainter().paint(canvas, const Size(76, 40));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SosBottomNavigationBar extends StatelessWidget {
  final ValueChanged<int> onTap;

  const _SosBottomNavigationBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: _border.withValues(alpha: 0.45), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: true,
                onTap: () => onTap(0),
              ),
              _BottomNavItem(
                icon: Icons.mic_none,
                label: 'Assistant',
                onTap: () => onTap(1),
              ),
              _BottomNavItem(
                icon: Icons.history,
                label: 'History',
                onTap: () => onTap(2),
              ),
              _BottomNavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.45);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 27),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
