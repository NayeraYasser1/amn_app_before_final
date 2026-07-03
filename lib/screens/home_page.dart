import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_history_service.dart';
import '../services/maintenance_reminders_service.dart';
import '../services/usage_logger.dart';
import 'settings_screen.dart';
import 'emergency_services_screen.dart';
import 'parking_map_screen.dart';
import 'map_picker_screen.dart';
import 'maintenance_reminders_screen.dart';
import 'voice_assistant_screen.dart';
import 'pairing_unpaired_screen.dart';
import 'emergency_history_screen.dart';
import 'roadside_assistance_screen.dart';
import 'safety_hub_screen.dart';

const Color _background = Color(0xFF020607);
const Color _card = Color(0xFF121417);
const Color _cardRaised = Color(0xFF17191D);
const Color _border = Color(0xFF2C3136);
const Color _red = Color(0xFFE81218);
const Color _yellow = Color(0xFFFFC928);
const Color _muted = Color(0xFFB7BABF);
const String _ambulanceNumber = '123';
const int _sosHoldSeconds = 3;

class HomePage extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  const HomePage({super.key, this.onLocaleChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'Nayera';
  Timer? _sosHoldTimer;
  bool _isHoldingSos = false;
  bool _suppressNextSosTap = false;

  // Navigation card: a user-chosen destination. Distance and ETA are computed
  // with free, keyless OpenStreetMap services (Nominatim geocoding + OSRM
  // routing) and the card opens Google Maps directions to the destination.
  static const _destLatKey = 'nav_dest_latitude';
  static const _destLngKey = 'nav_dest_longitude';
  static const _destLabelKey = 'nav_dest_label';
  double? _destLat;
  double? _destLng;
  String? _destLabel;
  String _navDistanceText = '--';
  String _navDurationText = '--';
  bool _navLoading = false;

  // Live weather from free, keyless Open-Meteo. Icon reflects the condition.
  String _weatherTemp = '--°C';
  String _weatherLabel = 'Weather';
  IconData _weatherIcon = Icons.wb_cloudy;
  Color _weatherColor = _yellow;
  List<_HourWeather> _hourly = const [];

  // Maintenance alert card: the reminder pinned on the Maintenance
  // Reminders screen (falls back to engine / nearest), with its own icon.
  String _maintAlertTitle = 'Engine check';
  String _maintAlertSubtitle = 'scheduled !';
  Color _maintAlertSubtitleColor = Colors.white;
  IconData _maintAlertIcon = Icons.settings_input_component;

  @override
  void initState() {
    super.initState();
    _getUserName();
    _loadDestination();
    _loadWeather();
    _loadMaintenanceAlert();
    UsageLogger.logScreenView('HomePage');
  }

  Future<void> _loadMaintenanceAlert() async {
    final items = await MaintenanceRemindersService.load();
    if (!mounted) return;
    final alert = MaintenanceRemindersService.homeAlertItem(items);
    if (alert == null) {
      setState(() {
        _maintAlertTitle = 'Maintenance';
        _maintAlertSubtitle = 'No reminders';
        _maintAlertSubtitleColor = Colors.white;
        _maintAlertIcon = Icons.build;
      });
      return;
    }
    final title = (alert['title'] ?? 'Maintenance').toString();
    final days = MaintenanceRemindersService.daysUntil(
      MaintenanceRemindersService.dueOf(alert),
    );
    setState(() {
      _maintAlertTitle = title;
      _maintAlertSubtitle = MaintenanceRemindersService.daysLeftLabel(days);
      _maintAlertSubtitleColor = days < 0
          ? _red
          : (days <= 7 ? _yellow : Colors.white);
      _maintAlertIcon = MaintenanceRemindersService.iconFor(title);
    });
  }

  @override
  void dispose() {
    _sosHoldTimer?.cancel();
    super.dispose();
  }

  void _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName =
            user.displayName ??
            (user.email?.split('@')[0].capitalize() ?? 'Nayera');
      });
    }
  }

  // Quietly fetch the current GPS position (no snackbars). Returns null if
  // location is unavailable or permission is denied.
  Future<Position?> _currentPositionQuiet() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_destLatKey);
    final lng = prefs.getDouble(_destLngKey);
    final label = prefs.getString(_destLabelKey);
    if (!mounted || lat == null || lng == null) return;
    setState(() {
      _destLat = lat;
      _destLng = lng;
      _destLabel = label;
    });
    _computeRoute();
  }

  // Fetches current + hourly weather from Open-Meteo (free, no API key) for the
  // user's location, and picks an icon/label from the WMO weather code.
  Future<void> _loadWeather() async {
    final position = await _currentPositionQuiet();
    if (position == null || !mounted) return;
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${position.latitude}',
        'longitude': '${position.longitude}',
        'current': 'temperature_2m,weather_code',
        'hourly': 'temperature_2m,weather_code',
        'timezone': 'auto',
        'forecast_days': '1',
      });
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final current = data['current'] as Map<String, dynamic>;
      final temp = (current['temperature_2m'] as num).round();
      final wx = _weatherFor((current['weather_code'] as num).toInt());

      final hourly = data['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List).cast<String>();
      final temps = hourly['temperature_2m'] as List;
      final codes = hourly['weather_code'] as List;
      final list = <_HourWeather>[];
      for (var i = 0; i < times.length && i < 24; i++) {
        final hourWx = _weatherFor((codes[i] as num).toInt());
        list.add(
          _HourWeather(
            hour: _formatHour(times[i]),
            temp: '${(temps[i] as num).round()}°',
            icon: hourWx.icon,
            color: hourWx.color,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _weatherTemp = '$temp°C';
        _weatherLabel = wx.label;
        _weatherIcon = wx.icon;
        _weatherColor = wx.color;
        _hourly = list;
      });
    } catch (_) {
      // Leave the placeholder values on failure.
    }
  }

  // Maps a WMO weather code to an icon, label and colour.
  _Wx _weatherFor(int code) {
    if (code == 0) return const _Wx(Icons.wb_sunny, 'Clear', _yellow);
    if (code == 1 || code == 2) {
      return const _Wx(Icons.wb_cloudy, 'Partly cloudy', _yellow);
    }
    if (code == 3) return const _Wx(Icons.cloud, 'Cloudy', Colors.white70);
    if (code == 45 || code == 48) {
      return const _Wx(Icons.foggy, 'Fog', Colors.white70);
    }
    if (code >= 51 && code <= 57) {
      return const _Wx(Icons.grain, 'Drizzle', Colors.lightBlueAccent);
    }
    if (code >= 61 && code <= 67) {
      return const _Wx(Icons.umbrella, 'Rain', Colors.lightBlueAccent);
    }
    if (code >= 71 && code <= 77) {
      return const _Wx(Icons.ac_unit, 'Snow', Colors.lightBlueAccent);
    }
    if (code >= 80 && code <= 82) {
      return const _Wx(Icons.grain, 'Rain showers', Colors.lightBlueAccent);
    }
    if (code >= 85 && code <= 86) {
      return const _Wx(Icons.ac_unit, 'Snow showers', Colors.lightBlueAccent);
    }
    if (code >= 95) {
      return const _Wx(Icons.thunderstorm, 'Thunderstorm', Colors.amber);
    }
    return const _Wx(Icons.wb_cloudy, 'Weather', _yellow);
  }

  // "2026-07-01T15:00" -> "3 PM"
  String _formatHour(String iso) {
    final h = iso.length >= 13 ? int.tryParse(iso.substring(11, 13)) ?? 0 : 0;
    final period = h < 12 ? 'AM' : 'PM';
    var hour12 = h % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12 $period';
  }

  void _showWeatherSheet() {
    UsageLogger.logAction('weather_alert_tap');
    if (_hourly.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weather is still loading…')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(_weatherIcon, color: _weatherColor, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    _weatherTemp,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _weatherLabel,
                    style: const TextStyle(color: _muted, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Temperature through today',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _hourly.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final h = _hourly[i];
                    return Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _cardRaised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            h.hour,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                          Icon(h.icon, color: h.color, size: 22),
                          Text(
                            h.temp,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Opens the in-app draggable map so the user can pick a destination
  // visually, then saves it and computes the route.
  Future<void> _pickDestination() async {
    final position = await _currentPositionQuiet();
    // Fall back to Cairo if there's no GPS fix yet; the user can pan anywhere.
    final startLat = position?.latitude ?? 30.0444;
    final startLng = position?.longitude ?? 31.2357;
    if (!mounted) return;

    final result = await Navigator.push<PickedDestination>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(initialLat: startLat, initialLng: startLng),
      ),
    );
    if (result == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_destLatKey, result.latitude);
    await prefs.setDouble(_destLngKey, result.longitude);
    await prefs.setString(_destLabelKey, result.label);

    if (!mounted) return;
    setState(() {
      _destLat = result.latitude;
      _destLng = result.longitude;
      _destLabel = result.label;
    });
    await _computeRoute();
  }

  // Clears the active destination ("Cancel" / "I've arrived").
  Future<void> _clearDestination() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_destLatKey);
    await prefs.remove(_destLngKey);
    await prefs.remove(_destLabelKey);

    if (!mounted) return;
    setState(() {
      _destLat = null;
      _destLng = null;
      _destLabel = null;
      _navDistanceText = '--';
      _navDurationText = '--';
      _navLoading = false;
    });
  }

  // Real driving distance + time via OSRM (free, no key). Falls back to a
  // straight-line estimate if routing is unavailable.
  Future<void> _computeRoute() async {
    final destLat = _destLat;
    final destLng = _destLng;
    if (destLat == null || destLng == null) return;

    setState(() => _navLoading = true);
    final position = await _currentPositionQuiet();
    if (!mounted) return;

    if (position == null) {
      setState(() {
        _navDistanceText = '--';
        _navDurationText = 'GPS off';
        _navLoading = false;
      });
      return;
    }

    double meters;
    double seconds;
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${position.longitude},${position.latitude};$destLng,$destLat'
        '?overview=false',
      );
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (response.statusCode == 200 && routes != null && routes.isNotEmpty) {
        final route = routes.first as Map<String, dynamic>;
        meters = (route['distance'] as num).toDouble();
        seconds = (route['duration'] as num).toDouble();
      } else {
        throw Exception('No route');
      }
    } catch (_) {
      // Fallback: straight-line distance, assume ~40 km/h average.
      meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        destLat,
        destLng,
      );
      seconds = meters / (40 * 1000 / 3600);
    }

    if (!mounted) return;
    setState(() {
      // Prefixed with "~" because this is an estimate (no live traffic);
      // Google Maps shows the exact, traffic-aware figure when navigating.
      _navDistanceText = '~${_formatDistance(meters)}';
      _navDurationText = '~${_formatDuration(seconds)}';
      _navLoading = false;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  // Opens Google Maps with turn-by-turn directions to the chosen destination.
  Future<void> _openDirectionsToDestination() async {
    final destLat = _destLat;
    final destLng = _destLng;
    if (destLat == null || destLng == null) return;

    UsageLogger.logAction('navigation_directions_opened');
    final position = await _currentPositionQuiet();
    final params = <String, String>{
      'api': '1',
      'destination': '$destLat,$destLng',
      'travelmode': 'driving',
    };
    if (position != null) {
      params['origin'] = '${position.latitude},${position.longitude}';
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }

  void _onNavigationCardTap() {
    UsageLogger.logAction('navigation_card_tap');
    if (_destLat == null || _destLng == null) {
      _pickDestination();
    } else {
      _openDirectionsToDestination();
    }
  }

  Future<void> _cancelTrip() async {
    UsageLogger.logAction('navigation_trip_canceled');
    await _clearDestination();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trip canceled.')));
  }

  void _openEmergencyServices(String actionName) {
    UsageLogger.logAction(actionName);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmergencyServicesScreen()),
    );
  }

  void _handleSosTap() {
    if (_suppressNextSosTap) {
      _suppressNextSosTap = false;
      return;
    }

    _openEmergencyServices('sos_card_tap');
  }

  void _startSosHold() {
    if (_isHoldingSos) return;

    _sosHoldTimer?.cancel();
    _suppressNextSosTap = false;
    HapticFeedback.lightImpact();
    setState(() => _isHoldingSos = true);
    _sosHoldTimer = Timer(
      const Duration(seconds: _sosHoldSeconds),
      _completeSosHold,
    );
  }

  void _cancelSosHold() {
    if (!_isHoldingSos) return;

    _sosHoldTimer?.cancel();
    setState(() => _isHoldingSos = false);
  }

  Future<void> _completeSosHold() async {
    if (!_isHoldingSos || !mounted) return;

    _sosHoldTimer?.cancel();
    _suppressNextSosTap = true;
    setState(() => _isHoldingSos = false);
    HapticFeedback.heavyImpact();
    unawaited(
      UsageLogger.logAction(
        'sos_home_hold_completed',
        data: const {'number': _ambulanceNumber},
      ).catchError((_) {}),
    );
    unawaited(
      EmergencyHistoryService.logEvent(
        type: 'sos',
        title: 'SOS Ambulance Call Started',
        description: 'SOS long press from home screen',
        status: 'Started',
      ).catchError((_) {}),
    );
    await _callAmbulance();
    // Land on the live SOS screen so returning from the dialer shows real
    // status (elapsed time, location, contacts) instead of the plain home.
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyServicesScreen(startActive: true),
      ),
    );
  }

  Future<void> _callAmbulance() async {
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
    if (index == 0) return;

    if (index == 1) {
      UsageLogger.logAction('voice_assistant_open');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoiceAssistantScreen()),
      );
      return;
    }

    if (index == 2) {
      UsageLogger.logAction('emergency_history_open');
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
        statusBarColor: _background,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            children: [
              _HomeHeader(userName: _userName),
              const SizedBox(height: 18),
              _SosButton(
                isHolding: _isHoldingSos,
                onTap: _handleSosTap,
                onHoldStart: _startSosHold,
                onHoldCancel: _cancelSosHold,
              ),
              const SizedBox(height: 7),
              const Center(
                child: Text(
                  'Hold $_sosHoldSeconds seconds to call ambulance '
                  '($_ambulanceNumber) · Tap for options',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Quick Actions'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.settings_input_antenna,
                      label: 'Pairing',
                      onTap: () {
                        UsageLogger.logAction('quick_action_pairing');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PairingUnpairedScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.local_parking,
                      label: 'Parking',
                      onTap: () {
                        UsageLogger.logAction('quick_action_parking_pin');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ParkingMapScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.build,
                      label: 'Car Service',
                      onTap: () {
                        UsageLogger.logAction('quick_action_car_service');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarServiceScreen(
                              onLocaleChanged: widget.onLocaleChanged,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.shield_outlined,
                      label: 'Safety Hub',
                      onTap: () {
                        UsageLogger.logAction('quick_action_safety_hub');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SafetyHubScreen(
                              onLocaleChanged: widget.onLocaleChanged,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Navigation'),
              const SizedBox(height: 9),
              _NavigationCard(
                distanceText: _navDistanceText,
                durationText: _navDurationText,
                label: _destLabel,
                loading: _navLoading,
                onTap: _onNavigationCardTap,
                onEdit: _pickDestination,
              ),
              if (_destLabel != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelTrip,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel Trip'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _SectionTitle('Alerts'),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _AlertCard(
                      icon: _maintAlertIcon,
                      title: _maintAlertTitle,
                      subtitle: _maintAlertSubtitle,
                      subtitleColor: _maintAlertSubtitleColor,
                      onTap: () async {
                        UsageLogger.logAction('maintenance_alert_tap');
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MaintenanceRemindersScreen(),
                          ),
                        );
                        _loadMaintenanceAlert();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AlertCard(
                      icon: _weatherIcon,
                      iconColor: _weatherColor,
                      title: _weatherTemp,
                      subtitle: _weatherLabel,
                      onTap: _showWeatherSheet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
        bottomNavigationBar: _HomeBottomNavigationBar(
          currentIndex: 0,
          onTap: _openBottomTab,
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String userName;

  const _HomeHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $userName \u{1F44B}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'May 10 \u2022 10:30 AM   BMW iX \u2022 Connected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SosButton extends StatefulWidget {
  final bool isHolding;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldCancel;

  const _SosButton({
    required this.isHolding,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldCancel,
  });

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  // A finger that drifts further than this is scrolling, not holding —
  // cancel the hold so a slow scroll over SOS can never dial by accident.
  static const double _moveSlop = 18;

  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _sosHoldSeconds),
  );
  Offset? _downPosition;

  @override
  void didUpdateWidget(covariant _SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHolding && !oldWidget.isHolding) {
      _progress.forward(from: 0);
    } else if (!widget.isHolding && oldWidget.isHolding) {
      _progress.reset();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _downPosition;
    if (down != null && (event.position - down).distance > _moveSlop) {
      widget.onHoldCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'SOS. Hold three seconds to call an ambulance on 123. Tap for options.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: _red.withValues(alpha: 0.25),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 63,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF11A21), Color(0xFFD9080E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                _downPosition = event.position;
                widget.onHoldStart();
              },
              onPointerMove: _onPointerMove,
              onPointerUp: (_) => widget.onHoldCancel(),
              onPointerCancel: (_) => widget.onHoldCancel(),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(9),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) {
                    // The label flips to HOLD only after ~150 ms so a quick
                    // tap doesn't flicker.
                    final showHold =
                        widget.isHolding &&
                        _progress.value > 0.15 / _sosHoldSeconds;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _progress.value,
                              heightFactor: 1,
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                          ),
                          Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 120),
                              child: Text(
                                showHold ? 'HOLD' : 'SOS',
                                key: ValueKey(showHold),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 31,
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1,
        letterSpacing: 0,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 82,
        decoration: BoxDecoration(
          color: _cardRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 27),
                const SizedBox(height: 11),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  final String distanceText;
  final String durationText;
  final String? label;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _NavigationCard({
    required this.distanceText,
    required this.durationText,
    required this.label,
    required this.loading,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasDestination = label != null;
    final subtitle = hasDestination ? label! : 'Tap to set a destination';

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 84,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _border, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const CustomPaint(painter: _MiniMapPainter()),
                      Center(
                        child: Transform.rotate(
                          angle: 0.5,
                          child: const Icon(
                            Icons.navigation,
                            color: _red,
                            size: 36,
                            shadows: [
                              Shadow(color: Colors.white, blurRadius: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loading)
                          Row(
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _red,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Calculating\u2026',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Text(
                                distanceText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '\u2022',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 14,
                                    height: 1,
                                  ),
                                ),
                              ),
                              Text(
                                durationText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Change destination',
                  icon: const Icon(
                    Icons.edit_location_alt_outlined,
                    color: _muted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF11161A);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final thinLine = Paint()
      ..color = const Color(0xFF394048).withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final softLine = Paint()
      ..color = const Color(0xFF242B31).withValues(alpha: 0.9)
      ..strokeWidth = 2;

    final paths = <Path>[
      Path()
        ..moveTo(-8, size.height * 0.28)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.12,
          size.width + 12,
          size.height * 0.18,
        ),
      Path()
        ..moveTo(size.width * 0.2, -8)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.5,
          size.width * 0.18,
          size.height + 8,
        ),
      Path()
        ..moveTo(size.width * 0.64, -6)
        ..lineTo(size.width * 0.28, size.height + 8),
      Path()
        ..moveTo(-8, size.height * 0.72)
        ..lineTo(size.width + 8, size.height * 0.42),
      Path()
        ..moveTo(size.width * 0.72, -6)
        ..quadraticBezierTo(
          size.width * 0.9,
          size.height * 0.46,
          size.width * 0.72,
          size.height + 6,
        ),
    ];

    for (final path in paths) {
      canvas.drawPath(path, softLine);
    }

    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.18 + i * 0.22);
      canvas.drawLine(Offset(x, -4), Offset(x - 34, size.height + 4), thinLine);
    }

    canvas.drawLine(
      Offset(-4, size.height * 0.55),
      Offset(size.width + 4, size.height * 0.8),
      thinLine,
    );
  }

  @override
  bool shouldRepaint(_MiniMapPainter oldDelegate) => false;
}

// Weather condition: icon + label + colour for a WMO weather code.
class _Wx {
  final IconData icon;
  final String label;
  final Color color;

  const _Wx(this.icon, this.label, this.color);
}

// One hour of the day's temperature forecast.
class _HourWeather {
  final String hour;
  final String temp;
  final IconData icon;
  final Color color;

  const _HourWeather({
    required this.hour,
    required this.temp,
    required this.icon,
    required this.color,
  });
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color subtitleColor;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = _yellow,
    this.subtitleColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 63,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _border, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          height: 1.1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _HomeBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _background,
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
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _BottomNavItem(
                icon: Icons.mic_none,
                label: 'Assistant',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _BottomNavItem(
                icon: Icons.history,
                label: 'History',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _BottomNavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: currentIndex == 3,
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
    required this.selected,
    required this.onTap,
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
