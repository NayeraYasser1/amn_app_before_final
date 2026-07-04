import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_contacts_repository.dart';
import '../services/emergency_history_service.dart';
import '../services/maintenance_reminders_service.dart';
import '../services/usage_logger.dart';
import '../services/voice_command_sync_service.dart';
import '../utils/emergency_numbers.dart';
import 'engine_status_screen.dart';
import 'edit_profile_screen.dart';
import 'emergency_history_screen.dart';
import 'emergency_services_screen.dart';
import 'home_page.dart';
import 'maintenance_reminders_screen.dart';
import 'map_picker_screen.dart';
import 'pairing_unpaired_screen.dart';
import 'parking_map_screen.dart';
import 'roadside_assistance_screen.dart';
import 'safety_hub_screen.dart';
import 'settings_screen.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
  final _sync = VoiceCommandSyncService.instance;

  bool _available = false;
  bool _ttsAvailable = false;
  bool _initializing = true;
  bool _listening = false;
  bool _thinking = false;
  bool _handlingFinalResult = false;
  bool _cancelRequested = false;
  bool _bridgeConnected = false;
  // Bumped on every new listen attempt so a stale watchdog can tell it belongs
  // to an older session and must not touch the current one.
  int _listenSession = 0;
  String _recognizedText = '';
  String _assistantReply = 'Tap the microphone and tell AMN what you need.';
  List<Map<String, dynamic>> _catalog = const [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initAssistant();
    UsageLogger.logScreenView('VoiceAssistantScreen');
  }

  Future<void> _initAssistant() async {
    // Any step here (TTS engine missing, catalog decode, bridge probe) can
    // throw; without this guard a throw leaves _initializing true forever and
    // the whole screen is stuck on "Preparing voice assistant...".
    try {
      await _initTts();
      await _initSpeech();
      _catalog = await _sync.loadCatalog();
      await _refreshBridgeStatus();
    } catch (e) {
      debugPrint('Voice assistant init failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  void _openBottomTab(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
      return;
    }
    if (index == 1) return;
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EmergencyHistoryScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            _maybeHandleFinalUtterance();
          }
        },
        onError: (error) {
          if (!mounted) return;
          // A user-initiated cancel aborts the engine, which reports an
          // error — keep the "Canceled" message in that case.
          if (_cancelRequested) return;
          // Distinguish "heard nothing" from a real access problem. When the
          // recognizer started fine but caught no usable speech it reports
          // error_no_match / error_speech_timeout — that must NOT be shown as a
          // permission failure, which wrongly tells the user to grant access.
          final msg = error.errorMsg;
          final String reply;
          if (msg == 'error_no_match' || msg == 'error_speech_timeout') {
            reply =
                'I did not catch that. Tap the microphone and try again, speaking clearly.';
          } else if (msg == 'error_no_permission') {
            reply =
                'I could not access the microphone. Please allow microphone and speech recognition permissions in Settings, then try again.';
          } else {
            reply =
                'Something interrupted listening. Please tap the microphone and try again.';
          }
          setState(() {
            _listening = false;
            _thinking = false;
            _assistantReply = reply;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _available = available;
        _assistantReply = available
            ? 'I am ready. Say a command and I will route it correctly.'
            : 'Microphone or speech recognition is not available on this device.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _assistantReply =
            'Voice assistant could not start. Please check app permissions and try again.';
      });
    }
  }

  Future<void> _initTts() async {
    // Every TTS call has a 3s timeout: on the Samsung engines these can hang on
    // a dead binding, and because _initTts is awaited before speech init, a
    // hang would freeze the screen on "Preparing voice assistant..." forever.
    // A timeout just abandons the wait; the assistant still starts.
    const limit = Duration(seconds: 3);
    try {
      // Prefer Google TTS when it is installed. Some Samsung devices default to
      // an engine that repeatedly disconnects (DeadObjectException) and never
      // actually speaks; Google TTS is far more reliable.
      try {
        // Only switch engines when the device default is NOT already Google.
        // Re-binding an already-Google engine disturbs the shared audio path
        // and can make the very next speech-recognition start fail.
        final current = (await _tts.getDefaultEngine.timeout(limit))?.toString();
        if (current != 'com.google.android.tts') {
          final engines = await _tts.getEngines.timeout(limit);
          if (engines is List && engines.contains('com.google.android.tts')) {
            await _tts.setEngine('com.google.android.tts').timeout(limit);
          }
        }
      } catch (_) {}
      // Use the user's saved speaking speed (Settings -> Voice Preferences),
      // defaulting to a natural pace. Key matches VoicePreferencesScreen.rateKey.
      final rate =
          (await SharedPreferences.getInstance())
              .getDouble('voice_speech_rate') ??
          0.48;
      await _tts.setSpeechRate(rate).timeout(limit);
      await _tts.setPitch(1.0).timeout(limit);
      await _tts.setVolume(1.0).timeout(limit);
      _ttsAvailable = true;
    } catch (e) {
      // No usable TTS engine (or it hung) — spoken replies become a no-op, but
      // the assistant must still start and work on-screen via the tap commands.
      _ttsAvailable = false;
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        // Join contractions ("what's" -> "whats") before stripping symbols.
        .replaceAll("'", '')
        .replaceAll('’', '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Compiled patterns are cached so we don't rebuild a RegExp for every phrase
  // of every command on each recognized utterance.
  final Map<String, RegExp> _patternCache = {};

  RegExp _compiledPattern(String phrase) {
    return _patternCache.putIfAbsent(phrase, () {
      final placeholder = RegExp(r'\[(\w+)\]');
      const slotMarker = 'slotmarker';
      final normalized = _normalize(phrase.replaceAll(placeholder, slotMarker));
      final body = RegExp.escape(normalized)
          .replaceAll(slotMarker, '(.+)')
          .replaceAll(' ', r'\s+');
      // Anchored so a command matches the whole utterance, not a fragment of
      // an unrelated sentence.
      return RegExp('^$body\$');
    });
  }

  bool _phraseHasSlot(String phrase) => phrase.contains('[');

  Map<String, dynamic>? _findCatalogMatch(String recognized) {
    final normalized = _normalize(recognized);
    Map<String, dynamic>? best;
    var bestScore = -1;
    for (final item in _catalog) {
      final phrases = (item['phrases'] as List?) ?? const [];
      for (final phrase in phrases) {
        final rawPhrase = phrase.toString();
        if (!_compiledPattern(rawPhrase).hasMatch(normalized)) continue;
        // Prefer the most specific phrase: an exact (no-slot) phrase beats a
        // slotted one, and among equals the longest literal wins. This stops
        // a generic "call [name]" from shadowing a specific "call police",
        // regardless of catalog order.
        final score =
            (_phraseHasSlot(rawPhrase) ? 0 : 100000) + rawPhrase.length;
        if (score > bestScore) {
          bestScore = score;
          best = item;
        }
      }
    }
    return best;
  }

  // Extracts the first [slot] value (e.g. the name in "call [name]") from the
  // phrase that matched the recognized text.
  String? _extractSlot(Map<String, dynamic> item, String recognized) {
    final normalized = _normalize(recognized);
    final phrases = (item['phrases'] as List?) ?? const [];
    for (final phrase in phrases) {
      final match = _compiledPattern(phrase.toString()).firstMatch(normalized);
      if (match != null && match.groupCount >= 1) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  Future<void> _setAssistantReply(String reply, {bool speak = false}) async {
    if (!mounted) return;
    setState(() {
      _assistantReply = reply;
      _thinking = false;
    });
    if (speak) {
      await _speak(reply);
    }
  }

  Future<void> _refreshBridgeStatus() async {
    final payload = await _sync.getBridgeStatus();
    if (!mounted) return;
    setState(() {
      _bridgeConnected =
          payload['bridge_connected'] == true && payload['ok'] == true;
    });
  }

  // Runs a suggestion chip exactly as if the user had spoken it.
  Future<void> _runTypedCommand(String command) async {
    // Guard against a double-tap firing the same command twice (e.g. dialing
    // or sending SOS twice).
    if (_handlingFinalResult) return;
    if (_listening) {
      await _cancelVoice();
    }
    _handlingFinalResult = true;
    await _tts.stop();
    if (!mounted) {
      _handlingFinalResult = false;
      return;
    }
    setState(() {
      _recognizedText = command;
      _thinking = true;
      _assistantReply = 'Processing your command...';
    });
    try {
      await _handleCommand(command);
    } catch (e) {
      debugPrint('Voice command handling failed: $e');
      if (mounted) {
        setState(() {
          _assistantReply = 'Something went wrong handling that command.';
        });
      }
    } finally {
      _handlingFinalResult = false;
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<bool> _handleLocalAppAction(
    Map<String, dynamic> item,
    String recognized,
  ) async {
    final action = (item['app_action'] ?? '').toString();
    final reply = (item['confirmation'] ?? 'Done.').toString();

    // Actions with custom behaviour.
    switch (action) {
      case 'dial_police':
        return _callEmergencyService('Police', EmergencyNumbers.police, reply);
      case 'dial_ambulance':
        return _callEmergencyService(
          'Ambulance',
          EmergencyNumbers.ambulance,
          reply,
        );
      case 'dial_fire':
        return _callEmergencyService('Fire', EmergencyNumbers.fire, reply);
      case 'dial_traffic':
        return _callEmergencyService(
          'Traffic Police',
          EmergencyNumbers.traffic,
          reply,
        );
      case 'call_contact':
        return _callContactByName(_extractSlot(item, recognized));
      case 'find_my_car':
        return _findMyCarByVoice();
      case 'set_destination':
        return _setDestinationByVoice();
      case 'cancel_trip':
        return _cancelTripByVoice();
      case 'weather_report':
        return _speakWeather();
      case 'send_sos':
        return _sendSosByVoice();
      case 'where_am_i':
        return _speakWhereAmI();
      case 'send_my_location':
        return _sendMyLocation();
      case 'nearby_hospitals':
        return _openMapsSearch('hospitals', reply);
      case 'find_gas_station':
        return _openMapsSearch('gas station', reply);
      case 'open_maps_app':
        return _openMapsApp(reply);
      case 'search_place_app':
        return _openMapsSearch(_extractSlot(item, recognized) ?? '', reply);
      case 'navigate_place_app':
        return _navigateToPlaceApp(_extractSlot(item, recognized));
      case 'show_maintenance':
        return _speakMaintenance(openScreen: true);
      case 'next_maintenance':
        return _speakMaintenance(openScreen: false);
      case 'go_home':
        if (!mounted) return false;
        Navigator.popUntil(context, (route) => route.isFirst);
        await _setAssistantReply(reply, speak: true);
        return true;
      case 'voice_help':
        await _setAssistantReply(reply, speak: true);
        return true;
    }

    // Actions that simply open a screen.
    Widget? screen;
    switch (action) {
      case 'open_profile':
        screen = const EditProfileScreen();
        break;
      case 'open_emergency_contacts':
        // Route to the live Safety Hub (same data the SOS button uses) rather
        // than the legacy screen, which stored contacts under a different key.
        screen = const SafetyHubScreen(initialSection: 'contacts');
        break;
      case 'open_hospital_insurance':
        screen = const SafetyHubScreen(initialSection: 'hospitals');
        break;
      case 'open_pairing':
        screen = const PairingUnpairedScreen();
        break;
      case 'open_car_status':
        screen = const EngineStatusScreen();
        break;
      case 'open_parking_map':
        screen = const ParkingMapScreen();
        break;
      case 'save_parking':
        screen = const ParkingMapScreen(startOnSave: true);
        break;
      case 'open_safety_hub':
        screen = const SafetyHubScreen();
        break;
      case 'open_emergency_numbers':
        screen = const SafetyHubScreen(initialSection: 'numbers');
        break;
      case 'open_first_aid':
        screen = const SafetyHubScreen(initialSection: 'firstAid');
        break;
      case 'first_aid_topic':
        screen = SafetyHubScreen(
          initialSection: 'firstAid',
          initialFirstAidTopic: _extractSlot(item, recognized),
        );
        break;
      case 'find_car_repair':
        screen = const CarServiceScreen();
        break;
      case 'open_history':
        screen = const EmergencyHistoryScreen();
        break;
      case 'open_settings':
        screen = const SettingsScreen();
        break;
      case 'open_emergency_services':
        screen = const EmergencyServicesScreen();
        break;
      default:
        return false;
    }

    if (!mounted) return false;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    await _setAssistantReply(reply, speak: true);
    return true;
  }

  Future<void> _launchDial(String number) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    // Surface a failure instead of silently pretending the call started —
    // critical for emergency numbers.
    if (!launched) {
      await _setAssistantReply(
        'I could not open the dialer. Please dial $number yourself.',
        speak: true,
      );
    }
  }

  // Speaks a confirmation and opens the dialer with an emergency number.
  Future<bool> _callEmergencyService(
    String label,
    String number,
    String reply,
  ) async {
    // Dial FIRST, and never let a history write block or fail the call: the
    // log is fire-and-forget with its error swallowed. Previously a throwing
    // logEvent ran before the dial and could stop an emergency call entirely.
    await _setAssistantReply(reply, speak: true);
    await _launchDial(number);
    unawaited(
      EmergencyHistoryService.logEvent(
        type: 'emergency_call',
        title: '$label Call',
        description: 'Called $number by voice',
        status: 'Completed',
      ).catchError((_) {}),
    );
    return true;
  }

  // Finds a saved emergency contact by name or relationship and dials it.
  Future<bool> _callContactByName(String? slot) async {
    final query = (slot ?? '').trim().toLowerCase();
    if (query.isEmpty) {
      await _setAssistantReply(
        'Who should I call? Say, for example, call mom.',
        speak: true,
      );
      return true;
    }

    final contacts = await EmergencyContactsRepository.loadContacts();
    if (contacts.isEmpty) {
      // Never dial a placeholder/seed number — it could belong to a real
      // stranger. Tell the user to add a real contact instead.
      await _setAssistantReply(
        'You have no emergency contacts saved yet. Add one in the Safety Hub first.',
        speak: true,
      );
      return true;
    }

    Map<String, dynamic>? found;
    for (final contact in contacts) {
      final name = (contact['name'] ?? '').toString().toLowerCase();
      final relation = (contact['relationship'] ?? '').toString().toLowerCase();
      final nameHit =
          name.isNotEmpty && (name.contains(query) || query.contains(name));
      final relationHit =
          relation.isNotEmpty &&
          (relation.contains(query) || query.contains(relation));
      if (nameHit || relationHit) {
        found = contact;
        break;
      }
    }

    if (found == null) {
      await _setAssistantReply(
        'I could not find $query in your emergency contacts.',
        speak: true,
      );
      return true;
    }

    final name = (found['name'] ?? '').toString();
    final phone = (found['phone'] ?? '').toString();
    // Dial first; log fire-and-forget so a history-write failure can never
    // block the call.
    await _setAssistantReply('Calling $name.', speak: true);
    await _launchDial(phone);
    unawaited(
      EmergencyHistoryService.logEvent(
        type: 'contact_call',
        title: 'Contact Call',
        description: 'Called $name by voice',
        status: 'Completed',
      ).catchError((_) {}),
    );
    return true;
  }

  // Launches walking directions to the saved parking spot, or opens parking.
  Future<bool> _findMyCarByVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('saved_parking_latitude');
    final lng = prefs.getDouble('saved_parking_longitude');

    if (lat == null || lng == null) {
      if (!mounted) return true;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParkingMapScreen()),
      );
      await _setAssistantReply(
        'You have no saved parking yet. Opening parking so you can save it.',
        speak: true,
      );
      return true;
    }

    await EmergencyHistoryService.logEvent(
      type: 'parking_navigate',
      title: 'Navigate to Car',
      description: 'Started by voice',
      status: 'Completed',
    );
    await _setAssistantReply(
      'Starting walking directions to your car.',
      speak: true,
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return true;
  }

  // Opens the map picker and saves the chosen point as the home-card trip.
  Future<bool> _setDestinationByVoice() async {
    var startLat = 30.0444;
    var startLng = 31.2357;
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        startLat = position.latitude;
        startLng = position.longitude;
      }
    } catch (_) {}
    if (!mounted) return true;

    final result = await Navigator.push<PickedDestination>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(initialLat: startLat, initialLng: startLng),
      ),
    );
    if (result == null) {
      await _setAssistantReply('Destination selection canceled.', speak: true);
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('nav_dest_latitude', result.latitude);
    await prefs.setDouble('nav_dest_longitude', result.longitude);
    await prefs.setString('nav_dest_label', result.label);
    await _setAssistantReply(
      'Destination set to ${result.label}. Open the home navigation card to start.',
      speak: true,
    );
    return true;
  }

  Future<bool> _cancelTripByVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final hadTrip = prefs.containsKey('nav_dest_latitude');
    await prefs.remove('nav_dest_latitude');
    await prefs.remove('nav_dest_longitude');
    await prefs.remove('nav_dest_label');
    await _setAssistantReply(
      hadTrip ? 'Your trip has been canceled.' : 'You have no active trip.',
      speak: true,
    );
    return true;
  }

  // Fetches live weather (Open-Meteo, keyless) and speaks it.
  Future<bool> _speakWeather() async {
    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (position == null) {
      await _setAssistantReply(
        'I could not get your location for the weather.',
        speak: true,
      );
      return true;
    }

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${position.latitude}',
        'longitude': '${position.longitude}',
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;
      final temp = (current['temperature_2m'] as num).round();
      final label = _weatherLabel((current['weather_code'] as num).toInt());
      await _setAssistantReply(
        'It is $temp degrees and $label right now.',
        speak: true,
      );
    } catch (_) {
      await _setAssistantReply(
        'I could not fetch the weather right now.',
        speak: true,
      );
    }
    return true;
  }

  String _weatherLabel(int code) {
    if (code == 0) return 'clear';
    if (code == 1 || code == 2) return 'partly cloudy';
    if (code == 3) return 'cloudy';
    if (code == 45 || code == 48) return 'foggy';
    if (code >= 51 && code <= 57) return 'drizzling';
    if (code >= 61 && code <= 67) return 'raining';
    if (code >= 71 && code <= 77) return 'snowing';
    if (code >= 80 && code <= 82) return 'raining';
    if (code >= 85 && code <= 86) return 'snowing';
    if (code >= 95) return 'stormy';
    return 'cloudy';
  }

  Future<Position?> _quietPosition() async {
    try {
      var position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 8));
      return position;
    } catch (_) {
      return null;
    }
  }

  // "Send SOS": dials the ambulance and opens the full active-SOS screen so
  // the same alert path as the home button runs — location resolve + SOS SMS
  // to the default emergency contact + live timer — not just a bare dial.
  //
  // No explicit "Started" log here: the active-SOS screen records its own SOS
  // events (SMS sent/failed, marked safe) and the caller logs a generic
  // "Voice Command" entry, so a log here would just duplicate history.
  Future<bool> _sendSosByVoice() async {
    await _setAssistantReply(
      'Sending SOS. Calling the ambulance and alerting your emergency contact now.',
      speak: true,
    );
    await _launchDial(EmergencyNumbers.ambulance);
    if (!mounted) return true;
    // Await the active-SOS screen so we can clear the stale "Sending SOS..."
    // reply once the user returns, instead of leaving the voice screen frozen
    // mid-action.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EmergencyServicesScreen(startActive: true),
      ),
    );
    if (mounted) {
      setState(() {
        _recognizedText = '';
        _assistantReply =
            'I am ready. Say a command and I will route it correctly.';
      });
    }
    return true;
  }

  // "Where am I": reverse-geocodes the GPS position and speaks the address.
  Future<bool> _speakWhereAmI() async {
    final position = await _quietPosition();
    if (position == null) {
      await _setAssistantReply(
        'I could not get your location. Check that GPS is enabled.',
        speak: true,
      );
      return true;
    }

    var described =
        'latitude ${position.latitude.toStringAsFixed(4)}, '
        'longitude ${position.longitude.toStringAsFixed(4)}';
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
      if (name != null && name.isNotEmpty) {
        described = name.split(',').take(4).join(',').trim();
      }
    } catch (_) {}

    await _setAssistantReply('You are near $described.', speak: true);
    return true;
  }

  // "Send my location": opens the messaging app with a Google Maps link to
  // the current position prefilled (clipboard fallback).
  Future<bool> _sendMyLocation() async {
    final position = await _quietPosition();
    if (position == null) {
      await _setAssistantReply(
        'I could not get your location. Check that GPS is enabled.',
        speak: true,
      );
      return true;
    }

    final link =
        'https://www.google.com/maps/search/?api=1&query='
        '${position.latitude},${position.longitude}';
    final message = 'My location: $link';
    await EmergencyHistoryService.logEvent(
      type: 'location_share',
      title: 'Location Shared',
      description: 'Location link prepared by voice',
      location:
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}',
      status: 'Completed',
    );

    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse('sms:?body=${Uri.encodeComponent(message)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}

    if (launched) {
      await _setAssistantReply(
        'Opening messages with your location link. Choose who to send it to.',
        speak: true,
      );
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      await _setAssistantReply(
        'Your location link is copied. Paste it anywhere to share.',
        speak: true,
      );
    }
    return true;
  }

  // Opens Google Maps with a nearby search (hospitals, gas stations, or any
  // spoken query).
  Future<bool> _openMapsSearch(String query, String reply) async {
    final search = query.trim().isEmpty ? 'places near me' : query;
    final position = await _quietPosition();
    final target = position == null
        ? search
        : '$search near ${position.latitude},${position.longitude}';
    await _setAssistantReply(reply, speak: true);
    try {
      await launchUrl(
        Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': target,
        }),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    return true;
  }

  // "Open maps": launches Google Maps centred on the current position.
  Future<bool> _openMapsApp(String reply) async {
    final position = await _quietPosition();
    final uri = position == null
        ? Uri.parse('https://www.google.com/maps')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query='
            '${position.latitude},${position.longitude}',
          );
    await _setAssistantReply(reply, speak: true);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return true;
  }

  // "Navigate to X": Google Maps driving directions to the spoken place.
  Future<bool> _navigateToPlaceApp(String? slot) async {
    final place = (slot ?? '').trim();
    if (place.isEmpty) {
      await _setAssistantReply(
        'Where should I navigate? Say: navigate to, then the place name.',
        speak: true,
      );
      return true;
    }
    await _setAssistantReply('Starting navigation to $place.', speak: true);
    try {
      await launchUrl(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': place,
          'travelmode': 'driving',
        }),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    return true;
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Future<bool> _speakMaintenance({required bool openScreen}) async {
    final items = await MaintenanceRemindersService.load();

    if (openScreen && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MaintenanceRemindersScreen()),
      );
    }

    if (items.isEmpty) {
      await _setAssistantReply(
        openScreen
            ? 'You have no maintenance reminders. Opening maintenance '
                  'reminders so you can add one.'
            : 'You have no maintenance reminders.',
        speak: true,
      );
      return true;
    }

    items.sort(
      (a, b) => MaintenanceRemindersService.dueOf(
        a,
      ).compareTo(MaintenanceRemindersService.dueOf(b)),
    );

    final next = items.first;
    final nextLine =
        '${next['title']} on ${_formatDate(MaintenanceRemindersService.dueOf(next))}';

    if (openScreen) {
      await _setAssistantReply(
        'Opening maintenance reminders. You have ${items.length}; '
        'the nearest one is $nextLine.',
        speak: true,
      );
    } else {
      await _setAssistantReply(
        'Your next maintenance is $nextLine.',
        speak: true,
      );
    }
    return true;
  }

  Future<void> _handleCommand(String recognized) async {
    final text = recognized.trim();
    if (text.isEmpty) {
      await _setAssistantReply(
        'I did not catch that. Please try again.',
        speak: true,
      );
      return;
    }

    final match = _findCatalogMatch(text);
    // Unmatched speech is NEVER forwarded to the car bridge — doing so would
    // POST arbitrary utterances to external hardware. Give a clear reply and
    // record it as an unmatched command instead.
    if (match == null) {
      await _setAssistantReply(
        'I did not understand that command. Try one of the suggestions below.',
        speak: true,
      );
      unawaited(
        EmergencyHistoryService.logEvent(
          type: 'voice_command',
          title: 'Voice Command (unrecognized)',
          description: text,
          status: 'Failed',
        ).catchError((_) {}),
      );
      return;
    }

    final targets = ((match['targets'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    final shouldSendToCar = targets.contains('software');
    if (shouldSendToCar) {
      await _refreshBridgeStatus();
      if (!_bridgeConnected) {
        // The car is unreachable — fall back to the app action when the
        // command also supports the app target.
        if (targets.contains('app')) {
          final handled = await _handleLocalAppAction(match, text);
          if (handled) {
            unawaited(
              EmergencyHistoryService.logEvent(
                type: 'voice_command',
                title: 'Voice Command',
                description: text,
                status: 'Completed',
              ).catchError((_) {}),
            );
            return;
          }
        }
        await _setAssistantReply(
          'The car software is not reachable right now. Check the Pi voice bridge connection first.',
          speak: true,
        );
        return;
      }

      final result = await _sync.sendCommand(text, source: 'app');
      final reply = (result['reply'] ?? 'Command received.').toString();
      await UsageLogger.logAction(
        'voice_command_sent_to_car',
        data: <String, dynamic>{
          'command': text,
          'intent': result['intent']?.toString() ?? '',
          'ok': result['ok'] == true,
        },
      );
      unawaited(
        EmergencyHistoryService.logEvent(
          type: 'voice_command',
          title: 'Voice Command',
          description: text,
          status: result['ok'] == true ? 'Completed' : 'Failed',
        ).catchError((_) {}),
      );
      await _setAssistantReply(reply, speak: true);
      await _refreshBridgeStatus();
      return;
    }

    final handled = await _handleLocalAppAction(match, text);
    if (handled) {
      unawaited(
        EmergencyHistoryService.logEvent(
          type: 'voice_command',
          title: 'Voice Command',
          description: text,
          status: 'Completed',
        ).catchError((_) {}),
      );
    }
    if (!handled) {
      await _setAssistantReply(
        'This command is recognized, but its app action is not connected yet.',
        speak: true,
      );
    }
  }

  Future<void> _maybeHandleFinalUtterance() async {
    if (_handlingFinalResult) return;
    if (_recognizedText.trim().isEmpty) {
      // The session ended without hearing anything — reset the mic UI.
      if (mounted && _listening) {
        setState(() {
          _listening = false;
          _assistantReply =
              'I did not hear anything. Tap the microphone and try again.';
        });
      }
      return;
    }

    _handlingFinalResult = true;
    try {
      await _speech.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _listening = false;
      _thinking = true;
      _assistantReply = 'Processing your command...';
    });

    // try/finally so a throw inside a command handler (e.g. a history write
    // that fails) cannot leave the UI stuck on "Processing..." forever with
    // the mic permanently blocked.
    try {
      await _handleCommand(_recognizedText);
    } catch (e) {
      debugPrint('Voice command handling failed: $e');
      if (mounted) {
        setState(() {
          _assistantReply = 'Something went wrong handling that command.';
        });
      }
    } finally {
      _handlingFinalResult = false;
      if (mounted) setState(() => _thinking = false);
    }
  }

  // Hard-stops listening, processing and speech output without running the
  // captured command.
  Future<void> _cancelVoice() async {
    UsageLogger.logAction('voice_assistant_cancel');
    _cancelRequested = true;
    _handlingFinalResult = true;
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    if (!mounted) {
      _handlingFinalResult = false;
      return;
    }
    setState(() {
      _listening = false;
      _thinking = false;
      _recognizedText = '';
      _assistantReply = 'Canceled. Tap the microphone when you are ready.';
    });
    _handlingFinalResult = false;
  }

  Future<void> _toggleListening() async {
    if (_initializing) return;

    if (!_available) {
      await _initSpeech();
      if (!_available) {
        await _setAssistantReply(
          'I still cannot access speech recognition. Please enable microphone permission in device settings.',
          speak: true,
        );
        return;
      }
    }

    if (_listening) {
      await _speech.stop();
      UsageLogger.logAction('voice_assistant_stop');
      await _maybeHandleFinalUtterance();
      return;
    }

    await _tts.stop();
    if (!mounted) return;
    _cancelRequested = false;
    setState(() {
      _recognizedText = '';
      _assistantReply = 'Listening...';
      _thinking = false;
      _handlingFinalResult = false;
      // Optimistic: show the listening state (red mic + cancel button)
      // immediately — the engine can take a few seconds to confirm.
      _listening = true;
    });
    final int sessionId = ++_listenSession;

    bool started = await _beginListenSession();
    if (!started && mounted) {
      // The device recognizer sometimes rejects the first start when a previous
      // session (or a just-spoken reply) is still releasing the microphone.
      // Reset and try once more before telling the user it failed.
      try {
        await _speech.cancel();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      started = await _beginListenSession();
    }

    if (!mounted) return;
    if (started) {
      UsageLogger.logAction('voice_assistant_start');
      // Safety net for the rare case where the platform accepts listen() but
      // never actually starts and never fires a status/error callback: the mic
      // would otherwise sit on "Listening..." forever. After the max listen
      // window, if THIS session is still listening with nothing captured and no
      // command in flight, reset it. It never retries, so it cannot cause a
      // false "could not start listening". The session id guards against a
      // newer listen having started in the meantime.
      Future.delayed(const Duration(seconds: 16), () {
        if (!mounted || sessionId != _listenSession) return;
        if (_listening && !_handlingFinalResult && _recognizedText.isEmpty) {
          setState(() {
            _listening = false;
            _assistantReply =
                'I did not hear anything. Tap the microphone and try again.';
          });
        }
      });
    } else {
      setState(() => _listening = false);
      await _setAssistantReply(
        'I could not start listening. Please try again.',
        speak: true,
      );
    }
  }

  /// Starts one speech-recognition session. Returns true when the recognizer
  /// actually began listening. Extracted so the caller can retry on a transient
  /// start failure.
  Future<bool> _beginListenSession() async {
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _recognizedText = result.recognizedWords;
          });
          // Commands run only on the FINAL result — never on partial text, so
          // a long sentence is never cut off half-way.
          if (result.finalResult) {
            _maybeHandleFinalUtterance();
          }
        },
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 2),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
      // IMPORTANT (speech_to_text 7.x): listen() does not return a usable
      // value — it completes with null and signals failure by THROWING, not by
      // returning false. Reading its result as a bool previously threw
      // "'Null' is not a subtype of bool" on every tap, which surfaced as
      // "I could not start listening" even though the recognizer had started.
      // isListening is only set later by an async status callback, so it is not
      // reliable here. Reaching this line without an exception means listening
      // started; the watchdog in _toggleListening covers a silent non-start.
      return true;
    } catch (e) {
      // A real failure (e.g. ListenFailedException) must not strand the mic in
      // the listening state.
      debugPrint('speech listen() failed to start: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // cancel() hard-aborts the recognizer on teardown; stop() would try to
    // finalize and can emit a late result after the widget is gone.
    _tts.stop();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _initializing
        ? 'Preparing voice assistant...'
        : _listening
        ? 'Listening...'
        : _available
        ? 'Tap and speak, or tap a command below'
        : 'Voice input is unavailable on this device';
    // True when the device cannot hear you and/or cannot speak back, so we tell
    // the user the tap commands still work rather than leaving them stuck.
    final voiceLimited = !_initializing && (!_available || !_ttsAvailable);

    // Curated, tappable examples — tapping one runs it like a spoken command.
    const suggestions = [
      'call police',
      'call ambulance',
      'call mom',
      'send sos',
      'where am i',
      'send my location',
      'show nearby hospitals',
      'find nearest gas station',
      'find my car',
      'save my parking',
      "what's the weather",
      'first aid for bleeding',
      'open safety hub',
      'set a destination',
      'when is my next maintenance',
      'find a mechanic',
    ];
    final commandChips = [
      for (final suggestion in suggestions)
        _CommandChip(
          label: suggestion,
          onTap: () => _runTypedCommand(suggestion),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Voice Assistant',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (voiceLimited) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1705),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          !_available
                              ? "Voice is not working on this tablet, so it can't hear or speak. You can still tap any command below to run it."
                              : "Spoken replies are off on this tablet, but your voice commands and the buttons below still work.",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Keeps the microphone centred when the cancel button shows.
                  const SizedBox(width: 76),
                  Semantics(
                    button: true,
                    label: _listening
                        ? 'Stop listening'
                        : 'Start a voice command',
                    child: GestureDetector(
                      onTap: _toggleListening,
                      child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: _listening ? 124 : 112,
                      height: _listening ? 124 : 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _listening
                              ? const [Colors.redAccent, Colors.orangeAccent]
                              : const [Color(0xFF2E7DFF), Color(0xFF8E24AA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_listening ? Colors.redAccent : Colors.blue)
                                    .withValues(alpha: 0.45),
                            blurRadius: _listening ? 38 : 26,
                            spreadRadius: _listening ? 8 : 3,
                          ),
                        ],
                      ),
                        child: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: (_listening || _thinking)
                        ? Center(
                            child: GestureDetector(
                              onTap: _cancelVoice,
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.8,
                                    ),
                                    width: 1.4,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.redAccent,
                                  size: 26,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: commandChips,
              ),
              const SizedBox(height: 26),
              Expanded(
                child: _AssistantPanel(
                  title: 'You said',
                  text: _recognizedText.isEmpty
                      ? 'Your voice command will appear here.'
                      : _recognizedText,
                ),
              ),
              const SizedBox(height: 14),
              _AssistantPanel(
                title: 'AMN reply',
                text: _thinking
                    ? 'Processing your command...'
                    : _assistantReply,
                fixedHeight: 138,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _VoiceBottomNavigationBar(
        currentIndex: 1,
        onTap: _openBottomTab,
      ),
    );
  }
}

class _VoiceBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _VoiceBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[850]!, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              _VoiceBottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _VoiceBottomNavItem(
                icon: Icons.mic_none,
                label: 'Assistant',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _VoiceBottomNavItem(
                icon: Icons.history,
                label: 'History',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _VoiceBottomNavItem(
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

class _VoiceBottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VoiceBottomNavItem({
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
                style: TextStyle(color: color, fontSize: 12, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CommandChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantPanel extends StatelessWidget {
  final String title;
  final String text;
  final double? fixedHeight;

  const _AssistantPanel({
    required this.title,
    required this.text,
    this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );

    if (fixedHeight == null) return panel;
    return SizedBox(height: fixedHeight, child: panel);
  }
}
