import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
// Hide latlong2's `Path` so it doesn't clash with dart:ui's Path (painters).
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'emergency_history_screen.dart';
import '../services/emergency_history_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

const Color _bg = AppColors.background;
const Color _card = AppColors.card;
const Color _border = AppColors.border;
const Color _red = AppColors.red;
const Color _blue = AppColors.blue;
const Color _green = AppColors.green;
const Color _muted = AppColors.muted;

const String _osmTileTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

enum _ParkingStage { save, saved, find, navigate, arrived }

class _SavedParkingLocation {
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  const _SavedParkingLocation({
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });
}

class ParkingMapScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  /// Open on the save stage even when a spot is already saved (used by the
  /// voice "save parking" intent). By default the screen opens on Find My
  /// Car whenever a saved spot exists.
  final bool startOnSave;

  const ParkingMapScreen({
    super.key,
    this.onLocaleChanged,
    this.startOnSave = false,
  });

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  _ParkingStage _stage = _ParkingStage.save;
  _SavedParkingLocation? _savedLocation;
  Position? _currentPosition;
  String? _note;
  bool _isSaving = false;
  bool _isLocating = false;

  static const _parkingLatKey = 'saved_parking_latitude';
  static const _parkingLngKey = 'saved_parking_longitude';
  static const _parkingSavedAtKey = 'saved_parking_saved_at';
  static const _parkingNoteKey = 'saved_parking_note';

  @override
  void initState() {
    super.initState();
    _loadSavedParkingLocation();
  }

  void _setStage(_ParkingStage stage) {
    setState(() => _stage = stage);
  }

  Future<void> _loadSavedParkingLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_parkingLatKey);
    final lng = prefs.getDouble(_parkingLngKey);
    final savedAt = DateTime.tryParse(
      prefs.getString(_parkingSavedAtKey) ?? '',
    );

    final note = prefs.getString(_parkingNoteKey);

    if (!mounted) return;

    if (lat != null && lng != null) {
      setState(() {
        _savedLocation = _SavedParkingLocation(
          latitude: lat,
          longitude: lng,
          savedAt: savedAt ?? DateTime.now(),
        );
        _note = (note != null && note.isNotEmpty) ? note : null;
        // A spot is already saved — open on Find My Car so returning users
        // see their pinned parking instead of being asked to save again.
        if (!widget.startOnSave) _stage = _ParkingStage.find;
      });
    }

    // Always fetch the live position, also when nothing is saved yet —
    // otherwise the save stage sits on "Enable location" with GPS on.
    await _refreshCurrentPosition(showErrors: false);
  }

  // Lets the user attach a note to the parking spot (e.g. "Level 3, Bay 22").
  Future<void> _addNote() async {
    final controller = TextEditingController(text: _note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          title: const Text(
            'Parking note',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'e.g. Level 3, Bay 22, near the lift',
              hintStyle: TextStyle(color: _muted),
              counterStyle: TextStyle(color: _muted),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _blue),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save note'),
            ),
          ],
        );
      },
    );
    // Dispose after the dialog's exit animation finishes; the TextField is
    // still bound to this controller while the route animates out, so an
    // immediate dispose triggers a "used after being disposed" assertion.
    Future.delayed(
      const Duration(milliseconds: 400),
      controller.dispose,
    );
    if (result == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_parkingNoteKey, result);
    if (!mounted) return;
    setState(() => _note = result.isEmpty ? null : result);
    _showMessage(result.isEmpty ? 'Note cleared.' : 'Note saved.');
  }

  // Copies a shareable Google Maps link to the parking spot to the clipboard.
  Future<void> _shareLocation() async {
    final location = _savedLocation;
    if (location == null) {
      _showMessage('Save your parking location first.');
      return;
    }
    final link =
        'https://www.google.com/maps/search/?api=1&query='
        '${location.latitude},${location.longitude}';
    final text = _note == null ? link : 'My parking ($_note): $link';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage('Parking location copied — paste it anywhere to share.');
  }

  /// Called from the Arrived stage: the parking session is over, so the
  /// saved spot (and its note) is cleared — next time Parking opens on the
  /// save stage instead of offering navigation to an old spot.
  Future<void> _finishParking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_parkingLatKey);
    await prefs.remove(_parkingLngKey);
    await prefs.remove(_parkingSavedAtKey);
    await prefs.remove(_parkingNoteKey);
    await EmergencyHistoryService.logEvent(
      type: 'parking_found',
      title: 'Car Found',
      description: 'Parking completed; saved spot cleared',
      status: 'Completed',
    );
    if (!mounted) return;
    _showMessage('Car found! Your saved parking spot was cleared.');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Removes the saved parking note.
  Future<void> _deleteNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_parkingNoteKey);
    if (!mounted) return;
    setState(() => _note = null);
    _showMessage('Note removed.');
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
        _showMessage('Location permission is required to save parking.');
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        if (showErrors && mounted) {
          _showMessage('Unable to get your location. Please try again.');
        }
        return null;
      }
    }
  }

  Future<void> _refreshCurrentPosition({bool showErrors = true}) async {
    if (_isLocating || !mounted) return;

    setState(() => _isLocating = true);
    final position = await _getCurrentPosition(showErrors: showErrors);
    if (!mounted) return;
    setState(() {
      _currentPosition = position ?? _currentPosition;
      _isLocating = false;
    });
  }

  Future<void> _saveParkingLocation() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final position = await _getCurrentPosition();
      if (!mounted) return;

      if (position == null) {
        _showMessage('Could not save parking because no location was found.');
        return;
      }

      // A 12s high-accuracy fix can time out (e.g. entering a garage) and fall
      // back to the last known position, which may be minutes and kilometres
      // stale. Warn the user rather than silently pinning the wrong spot.
      final fixAge = DateTime.now().difference(position.timestamp);
      final isStale = fixAge.inMinutes >= 2;

      final savedLocation = _SavedParkingLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        savedAt: DateTime.now(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_parkingLatKey, savedLocation.latitude);
      await prefs.setDouble(_parkingLngKey, savedLocation.longitude);
      await prefs.setString(
        _parkingSavedAtKey,
        savedLocation.savedAt.toIso8601String(),
      );
      await EmergencyHistoryService.logEvent(
        type: 'parking_saved',
        title: 'Parking Location Saved',
        description: 'Saved parking coordinates',
        location:
            '${savedLocation.latitude.toStringAsFixed(6)}, ${savedLocation.longitude.toStringAsFixed(6)}',
        status: 'Completed',
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _savedLocation = savedLocation;
        _stage = _ParkingStage.saved;
      });

      await _openSavedPinInGoogleMaps();
      if (isStale && mounted) {
        _showMessage(
          'Saved, but this GPS fix may be a few minutes old. If the pin looks '
          'wrong, recenter on the map and save again.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to save parking location. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openSavedPinInGoogleMaps() async {
    final location = _savedLocation;
    if (location == null) {
      _showMessage('Save your parking location first.');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );
    await _launchExternal(uri);
  }

  Future<void> _openCurrentLocationInGoogleMaps() async {
    var position = _currentPosition;
    if (position == null) {
      position = await _getCurrentPosition();
      if (!mounted) return;
      if (position != null) setState(() => _currentPosition = position);
    }
    if (position == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}',
    );
    await _launchExternal(uri);
  }

  Future<void> _openNavigationToCar() async {
    final location = _savedLocation;
    if (location == null) {
      _showMessage('Save your parking location first.');
      return;
    }

    await _refreshCurrentPosition(showErrors: false);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}&travelmode=walking',
    );
    await _launchExternal(uri);

    if (!mounted) return;
    _setStage(_ParkingStage.navigate);
  }

  double? get _distanceToCarMeters {
    final current = _currentPosition;
    final saved = _savedLocation;
    if (current == null || saved == null) return null;

    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      saved.latitude,
      saved.longitude,
    );
  }

  void _showMessage(String message) => showAppSnack(context, message);

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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildStage(),
          ),
        ),
        bottomNavigationBar: _ParkingBottomNavigationBar(onTap: _openBottomTab),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _ParkingStage.save:
        return _SaveParkingStage(
          key: const ValueKey('save'),
          savedLocation: _savedLocation,
          currentPosition: _currentPosition,
          distanceMeters: _distanceToCarMeters,
          note: _note,
          isSaving: _isSaving,
          isLocating: _isLocating,
          onBack: () => Navigator.pop(context),
          onRefreshLocation: _refreshCurrentPosition,
          onOpenCurrentMap: _openCurrentLocationInGoogleMaps,
          onSave: _saveParkingLocation,
          onAddNote: _addNote,
          onDeleteNote: _deleteNote,
        );
      case _ParkingStage.saved:
        return _ParkingSavedStage(
          key: const ValueKey('saved'),
          savedLocation: _savedLocation,
          currentPosition: _currentPosition,
          distanceMeters: _distanceToCarMeters,
          note: _note,
          onBack: () => _setStage(_ParkingStage.save),
          onViewMap: _openSavedPinInGoogleMaps,
          onNavigate: _openNavigationToCar,
          onAddNote: _addNote,
          onDeleteNote: _deleteNote,
          onDone: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        );
      case _ParkingStage.find:
        return _FindMyCarStage(
          key: const ValueKey('find'),
          savedLocation: _savedLocation,
          currentPosition: _currentPosition,
          distanceMeters: _distanceToCarMeters,
          note: _note,
          onBack: () => Navigator.pop(context),
          onNavigate: _openNavigationToCar,
          onViewMap: _openSavedPinInGoogleMaps,
          onSaveNew: () => _setStage(_ParkingStage.save),
          onAddNote: _addNote,
          onDeleteNote: _deleteNote,
        );
      case _ParkingStage.navigate:
        return _NavigateStage(
          key: const ValueKey('navigate'),
          savedLocation: _savedLocation,
          currentPosition: _currentPosition,
          distanceMeters: _distanceToCarMeters,
          onBack: () => _setStage(_ParkingStage.find),
          onStop: () => _setStage(_ParkingStage.find),
          onArrived: () => _setStage(_ParkingStage.arrived),
        );
      case _ParkingStage.arrived:
        return _ArrivedStage(
          key: const ValueKey('arrived'),
          onFound: _finishParking,
          onShare: _shareLocation,
        );
    }
  }
}

class _ScreenShell extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;

  const _ScreenShell({required this.title, required this.child, this.onBack});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      children: [
        SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (onBack != null)
                Positioned(
                  left: 0,
                  child: _IconButton(icon: Icons.chevron_left, onTap: onBack),
                ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _SaveParkingStage extends StatelessWidget {
  final _SavedParkingLocation? savedLocation;
  final Position? currentPosition;
  final double? distanceMeters;
  final String? note;
  final VoidCallback onDeleteNote;
  final bool isSaving;
  final bool isLocating;
  final VoidCallback onBack;
  final VoidCallback onRefreshLocation;
  final VoidCallback onOpenCurrentMap;
  final VoidCallback onSave;
  final VoidCallback onAddNote;

  const _SaveParkingStage({
    super.key,
    required this.savedLocation,
    required this.currentPosition,
    required this.distanceMeters,
    required this.note,
    required this.onDeleteNote,
    required this.isSaving,
    required this.isLocating,
    required this.onBack,
    required this.onRefreshLocation,
    required this.onOpenCurrentMap,
    required this.onSave,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Save Parking Location',
      onBack: onBack,
      child: Column(
        children: [
          _ParkingMap(
            currentPosition: currentPosition,
            savedLocation: savedLocation,
            height: 246,
            isLocating: isLocating,
            onRetry: onRefreshLocation,
          ),
          const SizedBox(height: 14),
          _DarkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Parking Location',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  savedLocation == null
                      ? 'Press Save Parking to store your current GPS location.'
                      : _coordinateText(savedLocation),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  currentPosition == null
                      ? 'Current GPS: not loaded yet'
                      : 'Current GPS: ${currentPosition!.latitude.toStringAsFixed(6)}, '
                            '${currentPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Distance to car',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      savedLocation == null
                          ? 'No parking saved yet'
                          : _distanceText(distanceMeters),
                      style: const TextStyle(color: _green, fontSize: 12),
                    ),
                    const SizedBox(width: 7),
                    const Icon(Icons.my_location, color: _muted, size: 16),
                  ],
                ),
                if (note != null) ...[
                  const SizedBox(height: 12),
                  _NoteLine(note: note!, onDelete: onDeleteNote),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  text: isLocating ? 'Locating...' : 'Use Current GPS',
                  onPressed: onRefreshLocation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryButton(
                  text: 'Open Map',
                  onPressed: onOpenCurrentMap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            text: isSaving ? 'Saving...' : 'Save Parking',
            onPressed: onSave,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            text: note == null ? 'Add Note (Optional)' : 'Edit Note',
            onPressed: onAddNote,
          ),
        ],
      ),
    );
  }
}

class _ParkingSavedStage extends StatelessWidget {
  final _SavedParkingLocation? savedLocation;
  final Position? currentPosition;
  final double? distanceMeters;
  final String? note;
  final VoidCallback onDeleteNote;
  final VoidCallback onBack;
  final VoidCallback onViewMap;
  final VoidCallback onNavigate;
  final VoidCallback onAddNote;
  final VoidCallback onDone;

  const _ParkingSavedStage({
    super.key,
    required this.savedLocation,
    required this.currentPosition,
    required this.distanceMeters,
    required this.note,
    required this.onDeleteNote,
    required this.onBack,
    required this.onViewMap,
    required this.onNavigate,
    required this.onAddNote,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Parking Saved',
      onBack: onBack,
      child: Column(
        children: [
          _ParkingMap(
            currentPosition: currentPosition,
            savedLocation: savedLocation,
            height: 286,
          ),
          const SizedBox(height: 14),
          _DarkCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: _green,
                  child: Icon(Icons.check, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parking location saved\nsuccessfully!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _coordinateText(savedLocation),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_savedAtText(savedLocation?.savedAt)}  |  ${_distanceText(distanceMeters)} away',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      if (note != null) ...[
                        const SizedBox(height: 10),
                        _NoteLine(note: note!, onDelete: onDeleteNote),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SecondaryButton(
            text: 'Open Pin in Google Maps',
            onPressed: onViewMap,
          ),
          const SizedBox(height: 12),
          _PrimaryButton(text: 'Navigate to Car', onPressed: onNavigate),
          const SizedBox(height: 12),
          _SecondaryButton(
            text: note == null ? 'Add Note (Optional)' : 'Edit Note',
            onPressed: onAddNote,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(text: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}

class _FindMyCarStage extends StatelessWidget {
  final _SavedParkingLocation? savedLocation;
  final Position? currentPosition;
  final double? distanceMeters;
  final String? note;
  final VoidCallback onDeleteNote;
  final VoidCallback onBack;
  final VoidCallback onNavigate;
  final VoidCallback onViewMap;
  final VoidCallback onSaveNew;
  final VoidCallback onAddNote;

  const _FindMyCarStage({
    super.key,
    required this.savedLocation,
    required this.currentPosition,
    required this.distanceMeters,
    required this.note,
    required this.onDeleteNote,
    required this.onBack,
    required this.onNavigate,
    required this.onViewMap,
    required this.onSaveNew,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Find My Car',
      onBack: onBack,
      child: Column(
        children: [
          _ParkingMap(
            currentPosition: currentPosition,
            savedLocation: savedLocation,
            height: 286,
          ),
          const SizedBox(height: 14),
          _DarkCard(
            child: Column(
              children: [
                const Text(
                  'Distance to your car',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  _distanceText(distanceMeters),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _walkTimeText(distanceMeters),
                  style: const TextStyle(color: _green, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  _coordinateText(savedLocation),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 12),
                  _NoteLine(note: note!, onDelete: onDeleteNote),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryButton(text: 'Navigate to Car', onPressed: onNavigate),
          const SizedBox(height: 12),
          _SecondaryButton(
            text: 'Open Pin in Google Maps',
            onPressed: onViewMap,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            text: note == null ? 'Add Note (Optional)' : 'Edit Note',
            onPressed: onAddNote,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            text: 'Save New Parking (I re-parked)',
            onPressed: onSaveNew,
          ),
        ],
      ),
    );
  }
}

class _NavigateStage extends StatelessWidget {
  final _SavedParkingLocation? savedLocation;
  final Position? currentPosition;
  final double? distanceMeters;
  final VoidCallback onBack;
  final VoidCallback onStop;
  final VoidCallback onArrived;

  const _NavigateStage({
    super.key,
    required this.savedLocation,
    required this.currentPosition,
    required this.distanceMeters,
    required this.onBack,
    required this.onStop,
    required this.onArrived,
  });

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Navigate to Car',
      onBack: onBack,
      child: Column(
        children: [
          Stack(
            children: [
              _ParkingMap(
                currentPosition: currentPosition,
                savedLocation: savedLocation,
                height: 424,
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: _DarkCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.navigation,
                        color: Colors.white,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Google Maps opened\n${_distanceText(distanceMeters)} to car',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _walkTimeText(distanceMeters),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  _distanceText(distanceMeters),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  _shortCoordinateText(savedLocation),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  text: 'Stop Navigation',
                  onPressed: onStop,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryButton(
                  text: 'I Arrived',
                  onPressed: onArrived,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrivedStage extends StatelessWidget {
  final VoidCallback onFound;
  final VoidCallback onShare;

  const _ArrivedStage({
    super.key,
    required this.onFound,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Arrived',
      child: Column(
        children: [
          const SizedBox(height: 60),
          SizedBox(
            height: 230,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: const [
                Positioned.fill(child: CustomPaint(painter: _CityPainter())),
                Positioned(top: 20, child: _ParkingPin(size: 88)),
                Positioned(bottom: 24, child: _CarIcon(width: 170, height: 86)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            'You have arrived\nat your parking location.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, height: 1.4),
          ),
          const SizedBox(height: 36),
          _PrimaryButton(text: 'I Found My Car', onPressed: onFound),
          const SizedBox(height: 12),
          _SecondaryButton(text: 'Share Location', onPressed: onShare),
        ],
      ),
    );
  }
}

String _coordinateText(_SavedParkingLocation? location) {
  if (location == null) return 'No parking location saved yet.';
  return 'Latitude: ${location.latitude.toStringAsFixed(6)}\n'
      'Longitude: ${location.longitude.toStringAsFixed(6)}';
}

String _shortCoordinateText(_SavedParkingLocation? location) {
  if (location == null) return 'No pin';
  return '${location.latitude.toStringAsFixed(4)}, '
      '${location.longitude.toStringAsFixed(4)}';
}

String _distanceText(double? meters) {
  if (meters == null) return 'Waiting for GPS';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

String _walkTimeText(double? meters) {
  if (meters == null) return 'Open Google Maps for directions';
  final minutes = (meters / 80).ceil().clamp(1, 999);
  return '$minutes min walk';
}

String _savedAtText(DateTime? savedAt) {
  if (savedAt == null) return 'Saved location';
  final local = savedAt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Saved at $hour:$minute';
}

class _DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DarkCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
  final String text;
  final VoidCallback? onPressed;

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
  final VoidCallback? onPressed;

  const _SecondaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _card,
          foregroundColor: Colors.white,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ParkingBottomNavigationBar extends StatelessWidget {
  final ValueChanged<int> onTap;

  const _ParkingBottomNavigationBar({required this.onTap});

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

// A real OpenStreetMap (free, keyless) showing the user's location and/or the
// saved car pin. Fits both on screen when both are known.
class _ParkingMap extends StatefulWidget {
  final Position? currentPosition;
  final _SavedParkingLocation? savedLocation;
  final double height;
  final bool isLocating;
  final VoidCallback? onRetry;

  const _ParkingMap({
    required this.currentPosition,
    required this.savedLocation,
    required this.height,
    this.isLocating = false,
    this.onRetry,
  });

  @override
  State<_ParkingMap> createState() => _ParkingMapState();
}

class _ParkingMapState extends State<_ParkingMap> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ParkingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While no car is saved (the save stage), follow the live GPS position so
    // "Use Current GPS" actually recenters the already-built map.
    if (widget.savedLocation == null && widget.currentPosition != null) {
      final prev = oldWidget.currentPosition;
      final now = widget.currentPosition!;
      if (prev == null ||
          prev.latitude != now.latitude ||
          prev.longitude != now.longitude) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _mapController.move(
              LatLng(now.latitude, now.longitude),
              _mapController.camera.zoom,
            );
          } catch (_) {}
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carPoint = widget.savedLocation == null
        ? null
        : LatLng(
            widget.savedLocation!.latitude,
            widget.savedLocation!.longitude,
          );
    final userPoint = widget.currentPosition == null
        ? null
        : LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          );
    final center = carPoint ?? userPoint;

    if (center == null) {
      return SizedBox(
        height: widget.height,
        child: _MapUnavailable(
          isLocating: widget.isLocating,
          onRetry: widget.onRetry,
        ),
      );
    }

    CameraFit? fit;
    if (carPoint != null && userPoint != null) {
      final meters = Geolocator.distanceBetween(
        carPoint.latitude,
        carPoint.longitude,
        userPoint.latitude,
        userPoint.longitude,
      );
      // Only fit both points when they're meaningfully apart. If they're the
      // same spot (~0 m), the zero-size bounds makes flutter_map compute an
      // Infinity/NaN zoom and crash — so we just centre on the car instead.
      if (meters > 30) {
        fit = CameraFit.bounds(
          bounds: LatLngBounds(carPoint, userPoint),
          padding: const EdgeInsets.all(48),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            initialCameraFit: fit,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _osmTileTemplate,
              userAgentPackageName: 'com.example.amn_app',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                if (userPoint != null)
                  Marker(
                    point: userPoint,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.my_location,
                      color: _blue,
                      size: 26,
                    ),
                  ),
                if (carPoint != null)
                  Marker(
                    point: carPoint,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.local_parking,
                      color: _red,
                      size: 38,
                    ),
                  ),
              ],
            ),
            const _OsmAttribution(),
          ],
        ),
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  final bool isLocating;
  final VoidCallback? onRetry;

  const _MapUnavailable({this.isLocating = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11161A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      alignment: Alignment.center,
      child: isLocating
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: _muted,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Finding your location…',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  color: _muted,
                  size: 40,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Location unavailable — check that GPS is on.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, color: _blue, size: 17),
                    label: const Text(
                      'Try again',
                      style: TextStyle(color: _blue, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// OpenStreetMap's usage policy requires visible attribution.
class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: const Text(
          '© OpenStreetMap',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
  }
}

// A small row that displays the user's parking note, with an ✕ to delete it.
class _NoteLine extends StatelessWidget {
  final String note;
  final VoidCallback onDelete;

  const _NoteLine({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.sticky_note_2_outlined, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            note,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onDelete,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.close, color: _muted, size: 13),
          ),
        ),
      ],
    );
  }
}

class _ParkingPin extends StatelessWidget {
  final double size;

  const _ParkingPin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, color: _red, size: size);
  }
}

class _CarIcon extends StatelessWidget {
  final double width;
  final double height;

  const _CarIcon({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: const _CarIconPainter()),
    );
  }
}

class _CarIconPainter extends CustomPainter {
  const _CarIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = const Color(0xFFDEDEE0);
    final dark = Paint()..color = const Color(0xFF080B0D);
    final glass = Paint()..color = const Color(0xFF15202A);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.72,
        size.width * 0.84,
        size.height * 0.2,
      ),
      shadow,
    );
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.25,
        size.width * 0.38,
        size.height * 0.26,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.04,
        size.width * 0.68,
        size.height * 0.25,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.28,
        size.width * 0.94,
        size.height * 0.62,
      )
      ..lineTo(size.width * 0.9, size.height * 0.78)
      ..lineTo(size.width * 0.12, size.height * 0.78)
      ..close();
    canvas.drawPath(path, body);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.38,
        size.height * 0.28,
        size.width * 0.24,
        size.height * 0.18,
      ),
      glass,
    );
    canvas.drawCircle(
      Offset(size.width * 0.27, size.height * 0.78),
      size.height * 0.13,
      dark,
    );
    canvas.drawCircle(
      Offset(size.width * 0.73, size.height * 0.78),
      size.height * 0.13,
      dark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CityPainter extends CustomPainter {
  const _CityPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF121820);
    final widths = [22.0, 34.0, 28.0, 44.0, 30.0, 38.0, 24.0];
    var x = size.width * 0.12;
    for (var i = 0; i < widths.length; i++) {
      final h = 62 + (i % 3) * 20.0;
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, widths[i], h), paint);
      x += widths[i] + 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
