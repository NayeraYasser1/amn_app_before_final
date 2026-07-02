import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_history_service.dart';
import '../services/sos_alert_service.dart';
import '../services/usage_logger.dart';
import 'emergency_history_screen.dart';
import 'safety_hub_screen.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

const Color _bg = Color(0xFF020607);
const Color _card = Color(0xFF121417);
const Color _border = Color(0xFF2D3238);
const Color _red = Color(0xFFE81218);
const Color _green = Color(0xFF39D74A);
const Color _muted = Color(0xFFB7BABF);
const String _ambulanceNumber = '123';
const String _policeNumber = '122';
const String _fireNumber = '180';
const int _sosHoldSeconds = 3;

enum _SosStage { button, active, resolved }

enum _AlertState { sending, sent, failed }

class EmergencyServicesScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  /// When true the screen opens directly in the active-SOS state without
  /// dialing again — used by the Home screen hold-to-call, which has
  /// already opened the dialer and logged the event.
  final bool startActive;

  const EmergencyServicesScreen({
    super.key,
    this.onLocaleChanged,
    this.startActive = false,
  });

  @override
  State<EmergencyServicesScreen> createState() =>
      _EmergencyServicesScreenState();
}

class _EmergencyServicesScreenState extends State<EmergencyServicesScreen> {
  _SosStage _stage = _SosStage.button;
  Timer? _countdownTimer;
  Timer? _elapsedTimer;
  int _countdown = _sosHoldSeconds;
  bool _isHoldingSos = false;

  // Real state of the active emergency.
  DateTime? _sosStartedAt;
  bool _dialStarted = false;
  bool _locating = false;
  Position? _position;
  String? _address;
  List<Map<String, dynamic>> _contacts = [];

  // Automatic SOS alert SMS to the first contact and first hospital.
  bool _alertsTriggered = false;
  String _alertMessage = '';
  String? _contactAlertLabel;
  String? _contactAlertPhone;
  _AlertState? _contactAlertState;
  String? _hospitalAlertLabel;
  String? _hospitalAlertPhone;
  _AlertState? _hospitalAlertState;

  @override
  void initState() {
    super.initState();
    UsageLogger.logScreenView('EmergencyServicesScreen');
    // Ask for the SMS permission up front so the automatic SOS alerts can
    // go out silently when a real emergency happens.
    unawaited(SosAlertService.ensureSmsPermission());
    if (widget.startActive) {
      // Home already dialed 123 and logged the SOS; just show live status.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activateSos(dial: false);
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startSosHold() {
    if (_stage != _SosStage.button || _isHoldingSos) return;

    _countdownTimer?.cancel();
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
    HapticFeedback.heavyImpact();
    setState(() => _isHoldingSos = false);
    await _activateSos();
  }

  /// Starts a real SOS: dials 123 (unless the caller already did), starts
  /// the elapsed timer, resolves the live location, loads the user's real
  /// emergency contacts and logs the event to History.
  Future<void> _activateSos({bool dial = true}) async {
    _sosStartedAt = DateTime.now();
    _dialStarted = !dial;
    setState(() => _stage = _SosStage.active);

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    unawaited(_loadContacts());
    // Alerts wait for the location attempt so the SMS can carry the live
    // position; they are sent either way (without the link if GPS fails).
    unawaited(
      _resolveLocation().whenComplete(() {
        if (mounted) unawaited(_sendSosAlerts());
      }),
    );

    if (dial) {
      await _dialNumber(_ambulanceNumber);
      if (mounted) setState(() => _dialStarted = true);
      unawaited(
        EmergencyHistoryService.logEvent(
          type: 'sos',
          title: 'SOS Ambulance Call Started',
          description: 'SOS activated from Emergency Services screen',
          status: 'Started',
        ).catchError((_) {}),
      );
    }
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('safety_hub_contacts_json');
    final contacts = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          contacts.addAll(decoded.whereType<Map<String, dynamic>>());
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _contacts = contacts);
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _locating = true;
      _position = null;
      _address = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('location off');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() => _position = position);

      // Free keyless reverse geocoding (same pattern as the voice
      // assistant's verified "where am I").
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'lat': '${position.latitude}',
          'lon': '${position.longitude}',
          'format': 'json',
          'zoom': '17',
        });
        final response = await http
            .get(uri, headers: {'User-Agent': 'amn_app/1.0 (safety app)'})
            .timeout(const Duration(seconds: 8));
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final name = data['display_name']?.toString();
        if (name != null && name.isNotEmpty && mounted) {
          setState(
            () => _address = name.split(',').take(4).join(',').trim(),
          );
        }
      } catch (_) {}
    } catch (_) {
      // _position stays null → the UI shows a truthful "unavailable" state.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Sends the SOS alert SMS to the first emergency contact and the first
  /// saved hospital — silently, in the background, so the 123 call is not
  /// interrupted. Runs once per SOS.
  Future<void> _sendSosAlerts() async {
    if (_alertsTriggered) return;
    _alertsTriggered = true;

    final link = _locationLink;
    _alertMessage = link == null
        ? 'SOS EMERGENCY from AMN: I need help. '
              '(My GPS location is unavailable right now.)'
        : 'SOS EMERGENCY from AMN: I need help. My location: $link';

    final contact = await SosAlertService.firstEmergencyContact();
    final hospital = await SosAlertService.firstHospital();
    if (!mounted) return;
    setState(() {
      if (contact != null) {
        final relation = (contact['relationship'] ?? '').trim();
        _contactAlertLabel = relation.isEmpty
            ? contact['name']
            : '${contact['name']} ($relation)';
        _contactAlertPhone = contact['phone'];
        _contactAlertState = _AlertState.sending;
      }
      if (hospital != null) {
        _hospitalAlertLabel = hospital['name'];
        _hospitalAlertPhone = hospital['phone'];
        _hospitalAlertState = _AlertState.sending;
      }
    });

    if (contact != null) {
      final ok = await SosAlertService.sendSms(
        phone: contact['phone']!,
        message: _alertMessage,
      );
      if (mounted) {
        setState(
          () => _contactAlertState = ok ? _AlertState.sent : _AlertState.failed,
        );
      }
      unawaited(
        EmergencyHistoryService.logEvent(
          type: 'sos',
          title: ok ? 'SOS Alert SMS Sent' : 'SOS Alert SMS Failed',
          description: 'To $_contactAlertLabel (${contact['phone']})',
          status: ok ? 'Completed' : 'Failed',
        ).catchError((_) {}),
      );
    }

    if (hospital != null) {
      final ok = await SosAlertService.sendSms(
        phone: hospital['phone']!,
        message: _alertMessage,
      );
      if (mounted) {
        setState(
          () =>
              _hospitalAlertState = ok ? _AlertState.sent : _AlertState.failed,
        );
      }
      unawaited(
        EmergencyHistoryService.logEvent(
          type: 'sos',
          title: ok ? 'SOS Alert SMS Sent' : 'SOS Alert SMS Failed',
          description: 'To $_hospitalAlertLabel (${hospital['phone']})',
          status: ok ? 'Completed' : 'Failed',
        ).catchError((_) {}),
      );
    }
  }

  /// Fallback when a silent send fails (e.g. SMS permission denied): open
  /// the Messages composer prefilled with the same alert.
  Future<void> _openSmsComposer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    try {
      await launchUrl(
        Uri.parse('sms:$phone?body=${Uri.encodeComponent(_alertMessage)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  String? get _locationLink {
    final position = _position;
    if (position == null) return null;
    return 'https://www.google.com/maps/search/?api=1&query='
        '${position.latitude},${position.longitude}';
  }

  Future<void> _sendLocationSms() async {
    final link = _locationLink;
    if (link == null) return;
    final message = 'EMERGENCY - I need help. My location: $link';
    unawaited(
      EmergencyHistoryService.logEvent(
        type: 'location_share',
        title: 'Location Shared',
        description: 'Location link prepared during SOS',
        location:
            '${_position!.latitude.toStringAsFixed(6)}, '
            '${_position!.longitude.toStringAsFixed(6)}',
        status: 'Completed',
      ).catchError((_) {}),
    );
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse('sms:?body=${Uri.encodeComponent(message)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open messages. Link copied instead.'),
        ),
      );
    }
  }

  Future<void> _copyLocationLink() async {
    final link = _locationLink;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location link copied.')),
    );
  }

  Future<void> _openNearbyHospitals() async {
    UsageLogger.logAction('sos_nearby_hospitals');
    try {
      await launchUrl(
        Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': 'hospitals near me',
        }),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _dialNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open the dialer with $number.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open the dialer with $number.')),
      );
    }
  }

  String get _elapsedText {
    final startedAt = _sosStartedAt;
    if (startedAt == null) return '0:00';
    final elapsed = DateTime.now().difference(startedAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = elapsed.inSeconds % 60;
    final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  String get _startedAtText {
    final startedAt = _sosStartedAt;
    if (startedAt == null) return '';
    final hour12 = startedAt.hour % 12 == 0 ? 12 : startedAt.hour % 12;
    final minute = startedAt.minute.toString().padLeft(2, '0');
    final period = startedAt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  Future<void> _endSos() async {
    _elapsedTimer?.cancel();
    unawaited(
      EmergencyHistoryService.logEvent(
        type: 'sos',
        title: 'SOS Ended - Marked Safe',
        description: 'User marked themselves safe after $_elapsedText',
        location: _address ??
            (_position == null
                ? null
                : '${_position!.latitude.toStringAsFixed(6)}, '
                    '${_position!.longitude.toStringAsFixed(6)}'),
        status: 'Resolved',
      ).catchError((_) {}),
    );
    setState(() => _stage = _SosStage.resolved);
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
              _SosHeader(title: _titleForStage),
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
      case _SosStage.active:
        return 'SOS ACTIVE';
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
      case _SosStage.active:
        return _ActiveStage(
          key: const ValueKey('active'),
          elapsedText: _elapsedText,
          startedAtText: _startedAtText,
          dialStarted: _dialStarted,
          locating: _locating,
          position: _position,
          address: _address,
          contacts: _contacts,
          contactAlertLabel: _contactAlertLabel,
          contactAlertState: _contactAlertState,
          hospitalAlertLabel: _hospitalAlertLabel,
          hospitalAlertState: _hospitalAlertState,
          onContactAlertRetry: () => _openSmsComposer(_contactAlertPhone),
          onHospitalAlertRetry: () => _openSmsComposer(_hospitalAlertPhone),
          onCallAmbulance: () => _dialNumber(_ambulanceNumber),
          onCallPolice: () => _dialNumber(_policeNumber),
          onCallFire: () => _dialNumber(_fireNumber),
          onCallContact: (phone) => _dialNumber(phone),
          onRetryLocation: _resolveLocation,
          onSendLocation: _sendLocationSms,
          onCopyLocation: _copyLocationLink,
          onNearbyHospitals: _openNearbyHospitals,
          onOpenSafetyHub: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SafetyHubScreen()),
            ).then((_) => _loadContacts());
          },
          onMarkSafe: _endSos,
        );
      case _SosStage.resolved:
        return _ResolvedStage(
          key: const ValueKey('resolved'),
          onHistory: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmergencyHistoryScreen(),
              ),
            );
          },
          onHome: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        );
    }
  }
}

class _SosHeader extends StatelessWidget {
  final String title;

  const _SosHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Center(
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
                icon: Icons.sms_outlined,
                text:
                    'An SOS SMS with your live location is sent automatically '
                    'to your first emergency contact and your first hospital',
              ),
              SizedBox(height: 14),
              _InfoRow(
                icon: Icons.call_outlined,
                text:
                    'The phone dialer opens with the ambulance number '
                    '($_ambulanceNumber) — press the green button to call',
              ),
              SizedBox(height: 14),
              _InfoRow(
                icon: Icons.history,
                text: 'Everything is saved to your History with the time',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveStage extends StatelessWidget {
  final String elapsedText;
  final String startedAtText;
  final bool dialStarted;
  final bool locating;
  final Position? position;
  final String? address;
  final List<Map<String, dynamic>> contacts;
  final String? contactAlertLabel;
  final _AlertState? contactAlertState;
  final String? hospitalAlertLabel;
  final _AlertState? hospitalAlertState;
  final VoidCallback onContactAlertRetry;
  final VoidCallback onHospitalAlertRetry;
  final VoidCallback onCallAmbulance;
  final VoidCallback onCallPolice;
  final VoidCallback onCallFire;
  final ValueChanged<String> onCallContact;
  final VoidCallback onRetryLocation;
  final VoidCallback onSendLocation;
  final VoidCallback onCopyLocation;
  final VoidCallback onNearbyHospitals;
  final VoidCallback onOpenSafetyHub;
  final VoidCallback onMarkSafe;

  const _ActiveStage({
    super.key,
    required this.elapsedText,
    required this.startedAtText,
    required this.dialStarted,
    required this.locating,
    required this.position,
    required this.address,
    required this.contacts,
    required this.contactAlertLabel,
    required this.contactAlertState,
    required this.hospitalAlertLabel,
    required this.hospitalAlertState,
    required this.onContactAlertRetry,
    required this.onHospitalAlertRetry,
    required this.onCallAmbulance,
    required this.onCallPolice,
    required this.onCallFire,
    required this.onCallContact,
    required this.onRetryLocation,
    required this.onSendLocation,
    required this.onCopyLocation,
    required this.onNearbyHospitals,
    required this.onOpenSafetyHub,
    required this.onMarkSafe,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = position != null;
    return Column(
      children: [
        // Live elapsed time — real and ticking.
        _DarkCard(
          child: Column(
            children: [
              const Text(
                'SOS active for',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                elapsedText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Started at $startedAtText',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // What actually happened.
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(
                done: dialStarted,
                doneText: 'Dialer opened with $_ambulanceNumber — press the '
                    'green button if you have not called yet',
                pendingText: 'Opening the dialer with $_ambulanceNumber…',
              ),
              const SizedBox(height: 14),
              if (locating)
                const _StatusRow(
                  done: false,
                  loading: true,
                  doneText: '',
                  pendingText: 'Finding your location…',
                )
              else if (hasLocation)
                _StatusRow(
                  done: true,
                  doneText: address == null
                      ? 'Location found: '
                            '${position!.latitude.toStringAsFixed(5)}, '
                            '${position!.longitude.toStringAsFixed(5)}'
                      : 'You are near $address',
                  pendingText: '',
                )
              else
                Row(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: Colors.orangeAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Location unavailable — check that GPS is on',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: onRetryLocation,
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              if (contactAlertState != null) ...[
                const SizedBox(height: 14),
                _AlertRow(
                  label: contactAlertLabel ?? '',
                  state: contactAlertState!,
                  onTapWhenFailed: onContactAlertRetry,
                ),
              ],
              if (hospitalAlertState != null) ...[
                const SizedBox(height: 14),
                _AlertRow(
                  label: hospitalAlertLabel ?? '',
                  state: hospitalAlertState!,
                  onTapWhenFailed: onHospitalAlertRetry,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Real actions.
        _PrimaryButton(
          text: 'Call Ambulance ($_ambulanceNumber) again',
          onPressed: onCallAmbulance,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                text: 'Police $_policeNumber',
                icon: Icons.local_police_outlined,
                onPressed: onCallPolice,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SecondaryButton(
                text: 'Fire $_fireNumber',
                icon: Icons.local_fire_department_outlined,
                onPressed: onCallFire,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                text: 'Send location by SMS',
                icon: Icons.sms_outlined,
                onPressed: hasLocation ? onSendLocation : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SecondaryButton(
                text: 'Copy location link',
                icon: Icons.copy,
                onPressed: hasLocation ? onCopyLocation : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          text: 'Show nearby hospitals on the map',
          icon: Icons.local_hospital_outlined,
          onPressed: onNearbyHospitals,
        ),
        const SizedBox(height: 12),
        // Real emergency contacts from the Safety Hub.
        _DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Call an emergency contact',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (contacts.isEmpty) ...[
                const SizedBox(height: 4),
                const Text(
                  'You have no saved emergency contacts yet.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpenSafetyHub,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Add contacts in Safety Hub',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ] else
                ...contacts.take(4).map(
                  (contact) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 17,
                          backgroundColor: Color(0xFF2A3137),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  (contact['name'] ?? '').toString(),
                                  if ((contact['relationship'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    '(${contact['relationship']})',
                                ].join(' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (contact['phone'] ?? '').toString(),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onCallContact(
                            (contact['phone'] ?? '').toString(),
                          ),
                          icon: const CircleAvatar(
                            radius: 17,
                            backgroundColor: _green,
                            child: Icon(
                              Icons.call,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                          tooltip: 'Call',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onMarkSafe,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'I am safe — end SOS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String label;
  final _AlertState state;
  final VoidCallback onTapWhenFailed;

  const _AlertRow({
    required this.label,
    required this.state,
    required this.onTapWhenFailed,
  });

  @override
  Widget build(BuildContext context) {
    final Widget leading;
    final String text;
    switch (state) {
      case _AlertState.sending:
        leading = const SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(strokeWidth: 2, color: _muted),
        );
        text = 'Sending SOS SMS to $label…';
        break;
      case _AlertState.sent:
        leading = const Icon(Icons.check_circle, color: _green, size: 18);
        text = 'SOS SMS with your location sent to $label';
        break;
      case _AlertState.failed:
        leading = const Icon(
          Icons.error_outline,
          color: Colors.orangeAccent,
          size: 18,
        );
        text = 'SMS to $label failed — tap to open Messages';
        break;
    }

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );

    if (state != _AlertState.failed) return row;
    return InkWell(onTap: onTapWhenFailed, child: row);
  }
}

class _StatusRow extends StatelessWidget {
  final bool done;
  final bool loading;
  final String doneText;
  final String pendingText;

  const _StatusRow({
    required this.done,
    required this.doneText,
    required this.pendingText,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2, color: _muted),
          )
        else if (done)
          const Icon(Icons.check_circle, color: _green, size: 18)
        else
          const Icon(Icons.radio_button_checked, color: Colors.white70, size: 17),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            done ? doneText : pendingText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResolvedStage extends StatelessWidget {
  final VoidCallback onHistory;
  final VoidCallback onHome;

  const _ResolvedStage({
    super.key,
    required this.onHistory,
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
          'This SOS was saved to your History.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 34),
        _SecondaryButton(text: 'View History', onPressed: onHistory),
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
  final IconData? icon;
  final VoidCallback? onPressed;

  const _SecondaryButton({required this.text, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(text, style: const TextStyle(fontSize: 14))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          );
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _card,
          disabledForegroundColor: Colors.white38,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: child,
      ),
    );
  }
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
