import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_history_service.dart';
import '../services/usage_logger.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import 'emergency_history_screen.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

const Color _bg = AppColors.background;
const Color _card = AppColors.card;
const Color _border = AppColors.border;
const Color _red = AppColors.red;
const Color _muted = AppColors.muted;

// Car Service opens the device's Google Maps app with a "car repair near me"
// search at the user's location. This needs no Google Maps API key or billing
// (it just launches the external Maps app, the same way the Parking and
// Hospital screens do).
class CarServiceScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  const CarServiceScreen({super.key, this.onLocaleChanged});

  @override
  State<CarServiceScreen> createState() => _CarServiceScreenState();
}

class _CarServiceScreenState extends State<CarServiceScreen> {
  Position? _currentPosition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    UsageLogger.logScreenView('CarServiceScreen');
    _refreshLocation();
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

  Future<Position?> _getCurrentPosition({bool showErrors = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (showErrors && mounted) {
        _showMessage('Location services are disabled. Please enable GPS.');
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (showErrors && mounted) {
        _showMessage(
          'Location permission is required to find nearby services.',
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      // A high-accuracy fix can hang/timeout indoors; fall back to the last
      // known position so "car repair near me" still works.
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final position = await _getCurrentPosition(showErrors: false);
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _loading = false;
    });
  }

  Future<void> _openCarRepairInMaps() async {
    UsageLogger.logAction('car_service_open_maps');

    var position = _currentPosition;
    if (position == null) {
      position = await _getCurrentPosition();
      if (!mounted) return;
      if (position != null) setState(() => _currentPosition = position);
    }

    final query = position == null
        ? 'car repair near me'
        : 'car repair near ${position.latitude},${position.longitude}';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });

    await EmergencyHistoryService.logEvent(
      type: 'car_service_search',
      title: 'Car Service Search',
      description: 'Opened car repair search in Google Maps',
      location: position == null
          ? ''
          : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      status: 'Completed',
    );

    await _launchExternal(uri);
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('Unable to open Google Maps on this device.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to open Google Maps on this device.');
    }
  }

  void _showMessage(String message) => showAppSnack(context, message);

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
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      child: _IconButton(
                        icon: Icons.chevron_left,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const Text(
                      'Car Service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CurrentLocationCard(
                currentPosition: _currentPosition,
                loading: _loading,
                onRefresh: _refreshLocation,
              ),
              const SizedBox(height: 18),
              _DarkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.handyman_outlined,
                        color: _red,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Find Nearby Car Service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Open Google Maps to see nearby car repair workshops, '
                      'mechanics and tyre shops around your current location, '
                      'with live directions and contact details.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PrimaryButton(
                      icon: Icons.map_outlined,
                      text: 'Find Car Repair Near Me',
                      onPressed: _openCarRepairInMaps,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _ServiceBottomNavigationBar(onTap: _openBottomTab),
      ),
    );
  }
}

class _CurrentLocationCard extends StatelessWidget {
  final Position? currentPosition;
  final bool loading;
  final VoidCallback onRefresh;

  const _CurrentLocationCard({
    required this.currentPosition,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final locationText = currentPosition == null
        ? (loading ? 'Locating…' : 'Location not loaded yet')
        : 'Lat ${currentPosition!.latitude.toStringAsFixed(4)}, '
              'Lng ${currentPosition!.longitude.toStringAsFixed(4)}';

    return _DarkCard(
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Location',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          _IconButton(
            icon: loading ? Icons.hourglass_top : Icons.my_location,
            onTap: loading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.64),
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: FittedBox(child: Text(text)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _ServiceBottomNavigationBar extends StatelessWidget {
  final ValueChanged<int> onTap;

  const _ServiceBottomNavigationBar({required this.onTap});

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
