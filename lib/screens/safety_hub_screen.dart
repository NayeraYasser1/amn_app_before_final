import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/first_aid_content.dart';
import '../services/emergency_contacts_repository.dart';
import '../services/emergency_history_service.dart';
import '../services/usage_logger.dart';
import '../theme/app_colors.dart';
import '../utils/emergency_numbers.dart';
import '../utils/phone.dart';
import 'emergency_history_screen.dart';
import 'map_picker_screen.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

const Color _background = AppColors.background;
const Color _card = AppColors.card;
const Color _cardRaised = AppColors.cardRaised;
const Color _field = AppColors.field;
const Color _border = AppColors.border;
const Color _red = AppColors.red;
const Color _green = AppColors.green;
const Color _muted = AppColors.muted;

enum _SafetyHubStage {
  home,
  numbers,
  contacts,
  addContact,
  hospitals,
  addHospital,
  firstAid,
  firstAidDetails,
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  /// The default contact is the one the SOS button sends the emergency SMS
  /// to. Exactly one contact is default at any time.
  final bool isDefault;

  const _EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
    this.isDefault = false,
  });

  _EmergencyContact copyWith({bool? isDefault}) => _EmergencyContact(
    name: name,
    phone: phone,
    relationship: relationship,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'relationship': relationship,
    'default': isDefault,
  };

  factory _EmergencyContact.fromMap(Map<String, dynamic> map) {
    return _EmergencyContact(
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      relationship: (map['relationship'] ?? '').toString(),
      isDefault: map['default'] == true,
    );
  }
}

class _Hospital {
  final String name;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;

  /// The default hospital is the one the SOS button sends the emergency SMS
  /// to. Exactly one hospital is default at any time.
  final bool isDefault;

  const _Hospital({
    required this.name,
    required this.phone,
    required this.address,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  _Hospital copyWith({bool? isDefault}) => _Hospital(
    name: name,
    phone: phone,
    address: address,
    latitude: latitude,
    longitude: longitude,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'default': isDefault,
  };

  factory _Hospital.fromMap(Map<String, dynamic> map) {
    return _Hospital(
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isDefault: map['default'] == true,
    );
  }
}

class SafetyHubScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  /// Optional deep link: 'numbers', 'contacts', 'hospitals' or 'firstAid'.
  final String? initialSection;

  /// Optional first-aid topic to open directly (fuzzy-matched by title).
  final String? initialFirstAidTopic;

  const SafetyHubScreen({
    super.key,
    this.onLocaleChanged,
    this.initialSection,
    this.initialFirstAidTopic,
  });

  @override
  State<SafetyHubScreen> createState() => _SafetyHubScreenState();
}

class _SafetyHubScreenState extends State<SafetyHubScreen> {
  // The prefs keys live on the shared repository so the SOS/voice read paths
  // and this write path can never drift apart.
  static const _contactsKey = EmergencyContactsRepository.contactsKey;
  static const _hospitalsKey = EmergencyContactsRepository.hospitalsKey;

  _SafetyHubStage _stage = _SafetyHubStage.home;
  String _selectedTip = 'Before Treating Any Injury';

  List<_EmergencyContact> _contacts = [];
  List<_Hospital> _hospitals = [];
  String _contactSearch = '';

  // Contact form state (used for both add and edit).
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactRelationCtrl = TextEditingController();
  int? _editingContactIndex;

  // Hospital form state (used for both add and edit).
  final _hospitalNameCtrl = TextEditingController();
  final _hospitalPhoneCtrl = TextEditingController();
  final _hospitalAddressCtrl = TextEditingController();
  double? _pickedLat;
  double? _pickedLng;
  int? _editingHospitalIndex;

  // "Default for SOS" switches in the add/edit forms.
  bool _contactFormDefault = false;
  bool _hospitalFormDefault = false;

  // Guards against a double-tap on Save (during the stage transition) adding
  // the same contact/hospital twice.
  bool _committingForm = false;

  @override
  void initState() {
    super.initState();
    UsageLogger.logScreenView('SafetyHubScreen');
    _loadData();
    _applyDeepLink();
  }

  // Jumps straight to a section (and optionally a first-aid topic) when the
  // screen is opened from a deep link such as a voice command.
  void _applyDeepLink() {
    final section = widget.initialSection;
    if (section == null) return;

    _stage = switch (section) {
      'numbers' => _SafetyHubStage.numbers,
      'contacts' => _SafetyHubStage.contacts,
      'hospitals' => _SafetyHubStage.hospitals,
      'firstAid' => _SafetyHubStage.firstAid,
      _ => _SafetyHubStage.home,
    };

    final topicQuery = widget.initialFirstAidTopic?.trim().toLowerCase();
    if (section == 'firstAid' && topicQuery != null && topicQuery.isNotEmpty) {
      for (final topic in firstAidTopics) {
        if (_topicMatchesQuery(topic, topicQuery)) {
          _selectedTip = topic.title;
          _stage = _SafetyHubStage.firstAidDetails;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactRelationCtrl.dispose();
    _hospitalNameCtrl.dispose();
    _hospitalPhoneCtrl.dispose();
    _hospitalAddressCtrl.dispose();
    super.dispose();
  }

  // Fuzzy match: full containment either way, or any meaningful word of the
  // query appearing in the topic title ("a broken bone" -> "Broken bone...").
  bool _topicMatchesQuery(FirstAidTopic topic, String query) {
    final title = topic.title.toLowerCase();
    final subtitle = topic.subtitle.toLowerCase();
    if (title.contains(query) ||
        subtitle.contains(query) ||
        query.contains(title)) {
      return true;
    }
    for (final token in query.split(' ')) {
      if (token.length > 3 && title.contains(token)) return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    List<_EmergencyContact> contacts;
    final rawContacts = prefs.getString(_contactsKey);
    if (rawContacts == null || rawContacts.isEmpty) {
      // Start empty. We must NOT seed placeholder people here: those seeds get
      // persisted as real contacts and the SOS flow would then silently text a
      // made-up number that may belong to a real stranger. The user adds their
      // own contacts. (Growable list so add/edit/delete work.)
      contacts = <_EmergencyContact>[];
    } else {
      contacts = _decodeList(rawContacts)
          .map(_EmergencyContact.fromMap)
          .toList();
    }

    List<_Hospital> hospitals;
    final rawHospitals = prefs.getString(_hospitalsKey);
    if (rawHospitals == null || rawHospitals.isEmpty) {
      // NOTE: must be a growable list (not const) so add/edit/delete work.
      hospitals = [
        const _Hospital(
          name: 'El Salam Hospital',
          phone: '19885',
          address: 'Corniche El Nile, Maadi, Cairo',
          latitude: 29.9603,
          longitude: 31.2632,
        ),
        const _Hospital(
          name: 'Cleopatra Hospital',
          phone: '16805',
          address: '39 Cleopatra St., Heliopolis, Cairo',
          latitude: 30.0872,
          longitude: 31.3243,
        ),
        const _Hospital(
          name: 'Dar Al Fouad Hospital',
          phone: '16780',
          address: 'Yousef Abbas St., Nasr City, Cairo',
          latitude: 30.0563,
          longitude: 31.3345,
        ),
      ];
    } else {
      hospitals = _decodeList(rawHospitals).map(_Hospital.fromMap).toList();
    }

    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _hospitals = hospitals;
      _ensureSingleDefaultContact();
      _ensureSingleDefaultHospital();
    });
    // Persist so the SOS button reads the same defaults from storage.
    await _saveContacts();
    await _saveHospitals();
  }

  /// Keeps the invariant of exactly one default contact (the SOS target):
  /// the first flagged one wins; if none is flagged, the first contact is.
  void _ensureSingleDefaultContact() {
    if (_contacts.isEmpty) return;
    var idx = _contacts.indexWhere((c) => c.isDefault);
    if (idx < 0) idx = 0;
    for (var i = 0; i < _contacts.length; i++) {
      if (_contacts[i].isDefault != (i == idx)) {
        _contacts[i] = _contacts[i].copyWith(isDefault: i == idx);
      }
    }
  }

  void _ensureSingleDefaultHospital() {
    if (_hospitals.isEmpty) return;
    var idx = _hospitals.indexWhere((h) => h.isDefault);
    if (idx < 0) idx = 0;
    for (var i = 0; i < _hospitals.length; i++) {
      if (_hospitals[i].isDefault != (i == idx)) {
        _hospitals[i] = _hospitals[i].copyWith(isDefault: i == idx);
      }
    }
  }

  List<Map<String, dynamic>> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contactsKey,
      jsonEncode(_contacts.map((c) => c.toMap()).toList()),
    );
  }

  Future<void> _saveHospitals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _hospitalsKey,
      jsonEncode(_hospitals.map((h) => h.toMap()).toList()),
    );
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  void _goTo(_SafetyHubStage stage) {
    UsageLogger.logAction('safety_hub_${stage.name}');
    setState(() => _stage = stage);
  }

  void _handleBack() {
    if (_stage == _SafetyHubStage.home) {
      Navigator.pop(context);
      return;
    }

    final nextStage = switch (_stage) {
      _SafetyHubStage.addContact => _SafetyHubStage.contacts,
      _SafetyHubStage.addHospital => _SafetyHubStage.hospitals,
      _SafetyHubStage.firstAidDetails => _SafetyHubStage.firstAid,
      _ => _SafetyHubStage.home,
    };

    setState(() => _stage = nextStage);
  }

  void _openBottomTab(int index) {
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

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

  // -------------------------------------------------------------------------
  // Calls & directions
  // -------------------------------------------------------------------------

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Opens the phone dialer with the number ready to call.
  Future<void> _launchCall({
    required String label,
    required String number,
    required String historyType,
  }) async {
    UsageLogger.logAction(
      'safety_hub_call',
      data: {'label': label, 'number': number},
    );
    await EmergencyHistoryService.logEvent(
      type: historyType,
      title: '$label Call',
      description: 'Called $number',
      status: 'Completed',
    );

    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: sanitizePhoneNumber(number)),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('Unable to open the phone dialer.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to open the phone dialer.');
    }
  }

  // Opens real Google Maps driving directions to the hospital.
  Future<void> _openHospitalDirections(_Hospital hospital) async {
    UsageLogger.logAction(
      'safety_hub_hospital_directions',
      data: {'name': hospital.name},
    );

    final destination = (hospital.latitude != null &&
            hospital.longitude != null)
        ? '${hospital.latitude},${hospital.longitude}'
        : '${hospital.name} ${hospital.address}'.trim();

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('Unable to open Google Maps.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to open Google Maps.');
    }
  }

  // -------------------------------------------------------------------------
  // Contacts: add / edit / delete
  // -------------------------------------------------------------------------

  void _openContactForm({int? editIndex}) {
    _committingForm = false;
    _editingContactIndex = editIndex;
    if (editIndex != null) {
      final contact = _contacts[editIndex];
      _contactNameCtrl.text = contact.name;
      _contactPhoneCtrl.text = contact.phone;
      _contactRelationCtrl.text = contact.relationship;
      _contactFormDefault = contact.isDefault;
    } else {
      _contactNameCtrl.clear();
      _contactPhoneCtrl.clear();
      _contactRelationCtrl.clear();
      // The very first contact automatically becomes the SOS default.
      _contactFormDefault = _contacts.isEmpty;
    }
    _goTo(_SafetyHubStage.addContact);
  }

  Future<void> _saveContactForm() async {
    if (_committingForm) return;
    final name = _contactNameCtrl.text.trim();
    final phone = _contactPhoneCtrl.text.trim();
    final relationship = _contactRelationCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showMessage('Please enter both a name and a phone number.');
      return;
    }
    _committingForm = true;

    final contact = _EmergencyContact(
      name: name,
      phone: phone,
      relationship: relationship.isEmpty ? 'Contact' : relationship,
      isDefault: _contactFormDefault,
    );

    setState(() {
      int idx;
      if (_editingContactIndex != null) {
        idx = _editingContactIndex!;
        _contacts[idx] = contact;
      } else {
        _contacts.add(contact);
        idx = _contacts.length - 1;
      }
      // Only one contact can be the SOS default.
      if (contact.isDefault) {
        for (var i = 0; i < _contacts.length; i++) {
          if (i != idx && _contacts[i].isDefault) {
            _contacts[i] = _contacts[i].copyWith(isDefault: false);
          }
        }
      }
      _ensureSingleDefaultContact();
      _stage = _SafetyHubStage.contacts;
    });
    await _saveContacts();
    _committingForm = false;
    if (!mounted) return;
    _showMessage(
      _editingContactIndex != null ? 'Contact updated.' : 'Contact added.',
    );
    _editingContactIndex = null;
  }

  Future<void> _setDefaultContact(int index) async {
    if (index < 0 || index >= _contacts.length) return;
    setState(() {
      for (var i = 0; i < _contacts.length; i++) {
        _contacts[i] = _contacts[i].copyWith(isDefault: i == index);
      }
    });
    await _saveContacts();
    if (!mounted) return;
    _showMessage('${_contacts[index].name} is now the SOS default contact.');
  }

  Future<void> _deleteContact(int index) async {
    final contact = _contacts[index];
    final confirmed = await _confirmDelete(
      'Delete ${contact.name}?',
      message: contact.isDefault
          ? 'This is your DEFAULT emergency contact for the SOS button — '
                'the SOS emergency SMS is sent to them. Are you sure you '
                'want to delete them? The next contact in the list will '
                'become the default.'
          : null,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _contacts.removeAt(index);
      _ensureSingleDefaultContact();
    });
    await _saveContacts();
    if (!mounted) return;
    _showMessage('Contact deleted.');
  }

  // -------------------------------------------------------------------------
  // Hospitals: add / edit / delete
  // -------------------------------------------------------------------------

  void _openHospitalForm({int? editIndex}) {
    _committingForm = false;
    _editingHospitalIndex = editIndex;
    if (editIndex != null) {
      final hospital = _hospitals[editIndex];
      _hospitalNameCtrl.text = hospital.name;
      _hospitalPhoneCtrl.text = hospital.phone;
      _hospitalAddressCtrl.text = hospital.address;
      _pickedLat = hospital.latitude;
      _pickedLng = hospital.longitude;
      _hospitalFormDefault = hospital.isDefault;
    } else {
      _hospitalNameCtrl.clear();
      _hospitalPhoneCtrl.clear();
      _hospitalAddressCtrl.clear();
      _pickedLat = null;
      _pickedLng = null;
      // The very first hospital automatically becomes the SOS default.
      _hospitalFormDefault = _hospitals.isEmpty;
    }
    _goTo(_SafetyHubStage.addHospital);
  }

  Future<void> _pickHospitalLocation() async {
    var lat = _pickedLat ?? 30.0444;
    var lng = _pickedLng ?? 31.2357;
    if (_pickedLat == null) {
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (_) {}
    }
    if (!mounted) return;

    final result = await Navigator.push<PickedDestination>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLat: lat, initialLng: lng),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _pickedLat = result.latitude;
      _pickedLng = result.longitude;
      if (_hospitalAddressCtrl.text.trim().isEmpty) {
        _hospitalAddressCtrl.text = result.label;
      }
    });
  }

  Future<void> _saveHospitalForm() async {
    if (_committingForm) return;
    final name = _hospitalNameCtrl.text.trim();
    final phone = _hospitalPhoneCtrl.text.trim();
    final address = _hospitalAddressCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showMessage('Please enter both a hospital name and a phone number.');
      return;
    }
    _committingForm = true;

    final hospital = _Hospital(
      name: name,
      phone: phone,
      address: address,
      latitude: _pickedLat,
      longitude: _pickedLng,
      isDefault: _hospitalFormDefault,
    );

    setState(() {
      int idx;
      if (_editingHospitalIndex != null) {
        idx = _editingHospitalIndex!;
        _hospitals[idx] = hospital;
      } else {
        _hospitals.add(hospital);
        idx = _hospitals.length - 1;
      }
      // Only one hospital can be the SOS default.
      if (hospital.isDefault) {
        for (var i = 0; i < _hospitals.length; i++) {
          if (i != idx && _hospitals[i].isDefault) {
            _hospitals[i] = _hospitals[i].copyWith(isDefault: false);
          }
        }
      }
      _ensureSingleDefaultHospital();
      _stage = _SafetyHubStage.hospitals;
    });
    await _saveHospitals();
    _committingForm = false;
    if (!mounted) return;
    _showMessage(
      _editingHospitalIndex != null ? 'Hospital updated.' : 'Hospital added.',
    );
    _editingHospitalIndex = null;
  }

  Future<void> _setDefaultHospital(int index) async {
    if (index < 0 || index >= _hospitals.length) return;
    setState(() {
      for (var i = 0; i < _hospitals.length; i++) {
        _hospitals[i] = _hospitals[i].copyWith(isDefault: i == index);
      }
    });
    await _saveHospitals();
    if (!mounted) return;
    _showMessage(
      '${_hospitals[index].name} is now the SOS default hospital.',
    );
  }

  Future<void> _deleteHospital(int index) async {
    final hospital = _hospitals[index];
    final confirmed = await _confirmDelete(
      'Delete ${hospital.name}?',
      message: hospital.isDefault
          ? 'This is your DEFAULT hospital for the SOS button — the SOS '
                'emergency SMS is sent to it. Are you sure you want to '
                'delete it? The next hospital in the list will become the '
                'default.'
          : null,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _hospitals.removeAt(index);
      _ensureSingleDefaultHospital();
    });
    await _saveHospitals();
    if (!mounted) return;
    _showMessage('Hospital deleted.');
  }

  Future<bool?> _confirmDelete(String title, {String? message}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Text(
            message ?? 'It will be removed from your list. '
                'You can add it again anytime.',
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // First aid
  // -------------------------------------------------------------------------

  void _openTip(String title) {
    setState(() {
      _selectedTip = title;
      _stage = _SafetyHubStage.firstAidDetails;
    });
  }

  FirstAidTopic get _selectedTopic {
    return firstAidTopics.firstWhere(
      (topic) => topic.title == _selectedTip,
      orElse: () => firstAidTopics.first,
    );
  }

  // Opens a YouTube search with tutorial videos for the topic.
  Future<void> _openTopicVideo(FirstAidTopic topic) async {
    UsageLogger.logAction('first_aid_video', data: {'topic': topic.title});
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': 'first aid ${topic.videoQuery}',
    });
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('Unable to open the video.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to open the video.');
    }
  }

  int get _selectedTopicIndex => firstAidTopics.indexOf(_selectedTopic);

  void _openNextTip() {
    final nextIndex = (_selectedTopicIndex + 1) % firstAidTopics.length;
    _openTip(firstAidTopics[nextIndex].title);
  }

  void _openPreviousTip() {
    final previousIndex =
        (_selectedTopicIndex - 1 + firstAidTopics.length) %
        firstAidTopics.length;
    _openTip(firstAidTopics[previousIndex].title);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept the system back button so it walks back through the hub
      // stages instead of leaving the Safety Hub entirely.
      canPop: _stage == _SafetyHubStage.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: ValueKey(_stage), child: _buildStage()),
            ),
          ),
          bottomNavigationBar:
              _stage == _SafetyHubStage.firstAid ||
                  _stage == _SafetyHubStage.firstAidDetails
              ? null
              : _SafetyBottomNavigationBar(
                  currentIndex: 0,
                  onTap: _openBottomTab,
                ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    return switch (_stage) {
      _SafetyHubStage.home => _buildHome(),
      _SafetyHubStage.numbers => _buildNumbers(),
      _SafetyHubStage.contacts => _buildContacts(),
      _SafetyHubStage.addContact => _buildAddContact(),
      _SafetyHubStage.hospitals => _buildHospitals(),
      _SafetyHubStage.addHospital => _buildAddHospital(),
      _SafetyHubStage.firstAid => _buildFirstAid(),
      _SafetyHubStage.firstAidDetails => _buildFirstAidDetails(),
    };
  }

  Widget _screen({
    required String title,
    required List<Widget> children,
    Widget? trailing,
    EdgeInsets padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  }) {
    return ListView(
      padding: padding,
      children: [
        _TopBar(title: title, onBack: _handleBack, trailing: trailing),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }

  Widget _buildHome() {
    return _screen(
      title: 'SAFETY HUB',
      children: [
        _HubTile(
          icon: Icons.call_outlined,
          title: 'Emergency Numbers',
          subtitle: 'Police, Ambulance, Fire, Traffic Police',
          onTap: () => _goTo(_SafetyHubStage.numbers),
        ),
        const SizedBox(height: 12),
        _HubTile(
          icon: Icons.contacts_outlined,
          title: 'Emergency Contacts',
          subtitle: 'Your saved emergency contacts',
          onTap: () => _goTo(_SafetyHubStage.contacts),
        ),
        const SizedBox(height: 12),
        _HubTile(
          icon: Icons.local_hospital_outlined,
          title: 'Hospitals & Insurance',
          subtitle: 'Nearby hospitals and insurance information',
          onTap: () => _goTo(_SafetyHubStage.hospitals),
        ),
        const SizedBox(height: 12),
        _HubTile(
          icon: Icons.medical_services_outlined,
          title: 'First Aid Tips',
          subtitle: 'Learn first aid for common emergencies',
          onTap: () => _goTo(_SafetyHubStage.firstAid),
        ),
      ],
    );
  }

  Widget _buildNumbers() {
    return _screen(
      title: 'Emergency Numbers',
      children: [
        _EmergencyNumberCard(
          icon: Icons.shield_outlined,
          label: 'Police',
          number: EmergencyNumbers.police,
          onTap: () => _launchCall(
            label: 'Police',
            number: EmergencyNumbers.police,
            historyType: 'emergency_call',
          ),
        ),
        const SizedBox(height: 12),
        _EmergencyNumberCard(
          icon: Icons.local_hospital_outlined,
          label: 'Ambulance',
          number: EmergencyNumbers.ambulance,
          onTap: () => _launchCall(
            label: 'Ambulance',
            number: EmergencyNumbers.ambulance,
            historyType: 'emergency_call',
          ),
        ),
        const SizedBox(height: 12),
        _EmergencyNumberCard(
          icon: Icons.local_fire_department,
          label: 'Fire',
          number: EmergencyNumbers.fire,
          onTap: () => _launchCall(
            label: 'Fire',
            number: EmergencyNumbers.fire,
            historyType: 'emergency_call',
          ),
        ),
        const SizedBox(height: 12),
        _EmergencyNumberCard(
          icon: Icons.traffic,
          label: 'Traffic Police',
          number: EmergencyNumbers.traffic,
          onTap: () => _launchCall(
            label: 'Traffic Police',
            number: EmergencyNumbers.traffic,
            historyType: 'emergency_call',
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.touch_app_outlined, color: _muted, size: 17),
            SizedBox(width: 8),
            Text(
              'Tap a number to call',
              style: TextStyle(color: _muted, fontSize: 12, letterSpacing: 0),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContacts() {
    final query = _contactSearch.trim().toLowerCase();
    final visible = query.isEmpty
        ? _contacts
        : _contacts
              .where(
                (c) =>
                    c.name.toLowerCase().contains(query) ||
                    c.phone.contains(query) ||
                    c.relationship.toLowerCase().contains(query),
              )
              .toList();

    return _screen(
      title: 'Emergency Contacts',
      trailing: _HeaderIconButton(
        icon: Icons.add,
        onTap: () => _openContactForm(),
      ),
      children: [
        _SearchField(
          hint: 'Search contacts',
          onChanged: (value) => setState(() => _contactSearch = value),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No contacts yet. Tap + to add one.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            _ContactCard(
              contact: visible[i],
              onTap: () => _launchCall(
                label: visible[i].name,
                number: visible[i].phone,
                historyType: 'contact_call',
              ),
              onEdit: () =>
                  _openContactForm(editIndex: _contacts.indexOf(visible[i])),
              onDelete: () => _deleteContact(_contacts.indexOf(visible[i])),
              onSetDefault: () =>
                  _setDefaultContact(_contacts.indexOf(visible[i])),
            ),
            if (i != visible.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildAddContact() {
    final isEditing = _editingContactIndex != null;

    return _screen(
      title: isEditing ? 'Edit Contact' : 'Add Contact',
      children: [
        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: _background, size: 46),
          ),
        ),
        const SizedBox(height: 20),
        const _FieldLabel('Full Name'),
        const SizedBox(height: 7),
        _HubTextField(hint: 'Enter full name', controller: _contactNameCtrl),
        const SizedBox(height: 13),
        const _FieldLabel('Phone Number'),
        const SizedBox(height: 7),
        _HubTextField(
          hint: 'Enter phone number',
          controller: _contactPhoneCtrl,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 13),
        const _FieldLabel('Relationship'),
        const SizedBox(height: 7),
        _HubTextField(
          hint: 'e.g. Mom, Dad, Husband…',
          controller: _contactRelationCtrl,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in const [
              'Mom',
              'Dad',
              'Husband',
              'Best friend',
              'Neighbour',
            ])
              _RelationChip(
                label: label,
                onTap: () =>
                    setState(() => _contactRelationCtrl.text = label),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _DefaultSosSwitch(
          text: 'Default for SOS button',
          subtitle:
              'The SOS emergency SMS is sent to this contact. Only one '
              'contact can be the default.',
          value: _contactFormDefault,
          onChanged: (value) => setState(() => _contactFormDefault = value),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: isEditing ? 'Save Changes' : 'Save Contact',
          onTap: _saveContactForm,
        ),
      ],
    );
  }

  Widget _buildHospitals() {
    return _screen(
      title: 'Hospitals & Insurance',
      trailing: _HeaderIconButton(
        icon: Icons.add,
        onTap: () => _openHospitalForm(),
      ),
      children: [
        if (_hospitals.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No hospitals yet. Tap + to add one.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          )
        else
          for (var i = 0; i < _hospitals.length; i++) ...[
            _HospitalCard(
              hospital: _hospitals[i],
              onCall: () => _launchCall(
                label: _hospitals[i].name,
                number: _hospitals[i].phone,
                historyType: 'hospital_call',
              ),
              onDirections: () => _openHospitalDirections(_hospitals[i]),
              onEdit: () => _openHospitalForm(editIndex: i),
              onDelete: () => _deleteHospital(i),
              onSetDefault: () => _setDefaultHospital(i),
            ),
            if (i != _hospitals.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildAddHospital() {
    final isEditing = _editingHospitalIndex != null;
    final hasLocation = _pickedLat != null && _pickedLng != null;

    return _screen(
      title: isEditing ? 'Edit Hospital' : 'Add Hospital',
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(
              Icons.local_hospital_outlined,
              color: Colors.white,
              size: 47,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _FieldLabel('Hospital Name'),
        const SizedBox(height: 7),
        _HubTextField(
          hint: 'Enter hospital name',
          controller: _hospitalNameCtrl,
        ),
        const SizedBox(height: 13),
        const _FieldLabel('Phone Number'),
        const SizedBox(height: 7),
        _HubTextField(
          hint: 'Enter phone number',
          controller: _hospitalPhoneCtrl,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 13),
        const _FieldLabel('Address'),
        const SizedBox(height: 7),
        _HubTextField(
          hint: 'Enter address (optional)',
          controller: _hospitalAddressCtrl,
        ),
        const SizedBox(height: 13),
        const _FieldLabel('Location'),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hasLocation ? _green : _border),
            ),
            child: InkWell(
              onTap: _pickHospitalLocation,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(
                      hasLocation ? Icons.check_circle : Icons.map_outlined,
                      color: hasLocation ? _green : _muted,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        hasLocation
                            ? 'Location set '
                                  '(${_pickedLat!.toStringAsFixed(5)}, '
                                  '${_pickedLng!.toStringAsFixed(5)})'
                            : 'Select the hospital location on the map',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasLocation ? Colors.white : _muted,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _muted, size: 19),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DefaultSosSwitch(
          text: 'Default for SOS button',
          subtitle:
              'The SOS emergency SMS is sent to this hospital. Only one '
              'hospital can be the default.',
          value: _hospitalFormDefault,
          onChanged: (value) => setState(() => _hospitalFormDefault = value),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: isEditing ? 'Save Changes' : 'Save Hospital',
          onTap: _saveHospitalForm,
        ),
      ],
    );
  }

  Widget _buildFirstAid() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
      children: [
        _FirstAidTopControls(
          title: 'First Aid Tips',
          onBack: _handleBack,
          onNext: () => _openTip(firstAidTopics.first.title),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < firstAidTopics.length; i++) ...[
          _FirstAidTile(
            topic: firstAidTopics[i],
            onTap: () => _openTip(firstAidTopics[i].title),
          ),
          if (i != firstAidTopics.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildFirstAidDetails() {
    final topic = _selectedTopic;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
      children: [
        _FirstAidTopControls(
          title: topic.title,
          onBack: _selectedTopicIndex == 0 ? _handleBack : _openPreviousTip,
          onNext: _openNextTip,
        ),
        const SizedBox(height: 24),
        _FirstAidHeroCard(topic: topic),
        const SizedBox(height: 14),
        for (var i = 0; i < topic.steps.length; i++) ...[
          _FirstAidStepCard(
            step: i + 1,
            color: topic.color,
            text: topic.steps[i],
          ),
          if (i != topic.steps.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        _WatchVideoButton(
          color: topic.color,
          onTap: () => _openTopicVideo(topic),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  const _TopBar({required this.title, required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          _HeaderIconButton(icon: Icons.chevron_left, onTap: onBack),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
          trailing ?? const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableCard(
      onTap: onTap,
      child: Row(
        children: [
          _OutlinedIcon(icon: icon, color: _red),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.22,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white, size: 22),
        ],
      ),
    );
  }
}

class _EmergencyNumberCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;
  final VoidCallback onTap;

  const _EmergencyNumberCard({
    required this.icon,
    required this.label,
    required this.number,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableCard(
      onTap: onTap,
      minHeight: 64,
      child: Row(
        children: [
          _OutlinedIcon(icon: icon, color: Colors.white),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            number,
            style: const TextStyle(
              color: _red,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.call, color: _green, size: 18),
        ],
      ),
    );
  }
}

// Switch row used in the add/edit forms to mark the SOS default target.
class _DefaultSosSwitch extends StatelessWidget {
  final String text;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DefaultSosSwitch({
    required this.text,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value ? _red : _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.sos, color: _red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, activeColor: _red, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Small pill shown on the card of the default SOS contact / hospital.
class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _red),
      ),
      child: const Text(
        'DEFAULT · SOS',
        style: TextStyle(
          color: _red,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final _EmergencyContact contact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _ContactCard({
    required this.contact,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _cardRaised,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (contact.isDefault) ...[
                            const SizedBox(width: 6),
                            const _DefaultBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  contact.relationship,
                  style: const TextStyle(
                    color: _red,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: 19,
                  ),
                  color: _cardRaised,
                  onSelected: (value) {
                    if (value == 'default') onSetDefault();
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    if (!contact.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.sos, color: _red, size: 17),
                            SizedBox(width: 9),
                            Text('Set as default',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              color: Colors.white, size: 17),
                          SizedBox(width: 9),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: _red, size: 17),
                          SizedBox(width: 9),
                          Text('Delete', style: TextStyle(color: _red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final _Hospital hospital;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _HospitalCard({
    required this.hospital,
    required this.onCall,
    required this.onDirections,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OutlinedIcon(
            icon: Icons.local_hospital_outlined,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              hospital.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (hospital.isDefault) ...[
                            const SizedBox(width: 6),
                            const _DefaultBadge(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Open 24/7',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        letterSpacing: 0,
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 19,
                      ),
                      color: _cardRaised,
                      onSelected: (value) {
                        if (value == 'default') onSetDefault();
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        if (!hospital.isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Row(
                              children: [
                                Icon(Icons.sos, color: _red, size: 17),
                                SizedBox(width: 9),
                                Text('Set as default',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  color: Colors.white, size: 17),
                              SizedBox(width: 9),
                              Text('Edit',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: _red, size: 17),
                              SizedBox(width: 9),
                              Text('Delete', style: TextStyle(color: _red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (hospital.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    hospital.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  hospital.phone,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SmallActionButton(
                          icon: Icons.call,
                          label: 'Call',
                          color: _field,
                          onTap: onCall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SmallActionButton(
                          icon: Icons.navigation,
                          label: 'Directions',
                          color: _field,
                          onTap: onDirections,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RelationChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: _field,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// First aid widgets
// ---------------------------------------------------------------------------

class _FirstAidTopControls extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _FirstAidTopControls({
    required this.title,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FirstAidArrowButton(icon: Icons.chevron_left, onTap: onBack),
            _FirstAidArrowButton(icon: Icons.chevron_right, onTap: onNext),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FirstAidArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FirstAidArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 39,
      height: 39,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 1.2),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _FirstAidTile extends StatelessWidget {
  final FirstAidTopic topic;
  final VoidCallback onTap;

  const _FirstAidTile({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: topic.color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: topic.color.withValues(alpha: 0.8),
                      width: 1.3,
                    ),
                  ),
                  child: Icon(topic.icon, color: topic.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topic.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: _muted, size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A colored call-to-action that opens tutorial videos for the topic.
class _WatchVideoButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _WatchVideoButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.85)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Watch Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
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

// A big illustrated header for a first-aid topic.
class _FirstAidHeroCard extends StatelessWidget {
  final FirstAidTopic topic;

  const _FirstAidHeroCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            topic.color.withValues(alpha: 0.34),
            topic.color.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: topic.color.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: topic.color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: topic.color, width: 2),
            ),
            child: Icon(topic.icon, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 12),
          const Text(
            'What to do in this situation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Follow the numbered steps below',
            style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}

// One numbered rescue step, styled like the design mock-up.
class _FirstAidStepCard extends StatelessWidget {
  final int step;
  final Color color;
  final String text;

  const _FirstAidStepCard({
    required this.step,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.35,
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

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

class _PressableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double minHeight;

  const _PressableCard({
    required this.child,
    required this.onTap,
    this.minHeight = 68,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _OutlinedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _OutlinedIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        cursorColor: _red,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: _muted,
            fontSize: 12,
            letterSpacing: 0,
          ),
          prefixIcon: const Icon(Icons.search, color: _muted, size: 18),
          filled: true,
          fillColor: _field,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _red),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _HubTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  const _HubTextField({
    required this.hint,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: _red,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: _muted,
            fontSize: 12,
            letterSpacing: 0,
          ),
          filled: true,
          fillColor: _field,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _red),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF51A21), Color(0xFFD9080E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color == _red ? _red : _border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

class _SafetyBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SafetyBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _background,
        border: Border(
          top: BorderSide(color: _border.withValues(alpha: 0.48), width: 1),
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
