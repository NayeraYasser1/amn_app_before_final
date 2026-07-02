import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_history_service.dart';

class SosEmergencyScreen extends StatefulWidget {
  const SosEmergencyScreen({super.key});

  @override
  State<SosEmergencyScreen> createState() => _SosEmergencyScreenState();
}

class _SosEmergencyScreenState extends State<SosEmergencyScreen> {
  String? _locationText;
  String? _lastUpdatedText;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initLocationAndLog();
  }

  Future<void> _initLocationAndLog() async {
    setState(() {
      _loadingLocation = true;
    });

    String? loc;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        loc = 'Location services disabled';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          loc = 'Location permission denied';
        } else {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          loc =
              'Lat: ${position.latitude.toStringAsFixed(4)}, '
              'Lng: ${position.longitude.toStringAsFixed(4)}';
        }
      }
    } catch (_) {
      loc = 'Location unavailable';
    }

    final now = DateTime.now();

    await EmergencyHistoryService.logEvent(
      type: 'sos',
      title: 'SOS Activated',
      description: 'SOS emergency triggered from app',
      location: loc,
      status: 'In Progress',
    );

    if (!mounted) return;

    setState(() {
      _locationText = loc;
      _lastUpdatedText =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _loadingLocation = false;
    });
  }

  Future<void> _callEmergency() async {
    const number = '122'; // Egypt police / general emergency
    final uri = Uri(scheme: 'tel', path: number);
    await launchUrl(uri);
  }

  Future<void> _notifyContacts() async {
    final message =
        'SOS emergency! Please help. My last location: ${_locationText ?? 'Unknown'}';

    // This opens the SMS app; you can configure phone numbers later.
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {'body': message},
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F6FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Emergency SOS',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Emergency SOS',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Press the SOS button in case of emergency',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _callEmergency,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to call emergency services',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.phone_in_talk, color: Colors.black87),
                      SizedBox(width: 8),
                      Text(
                        'Quick Info',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.phone, size: 18, color: Colors.black54),
                      SizedBox(width: 8),
                      Text(
                        'Emergency: 122',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadingLocation
                              ? 'Fetching your location...'
                              : (_locationText ??
                                    'Location: Not available right now'),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _lastUpdatedText == null
                            ? 'Last updated: --:--:--'
                            : 'Last updated: $_lastUpdatedText',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Emergency Circle',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your emergency contacts will be notified.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _notifyContacts,
                      icon: const Icon(Icons.sms, color: Colors.white),
                      label: const Text(
                        'Notify Emergency Contacts',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This opens your SMS app so you can send an alert.',
                    style: TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
