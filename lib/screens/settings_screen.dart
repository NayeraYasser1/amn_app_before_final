import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'language_country_screen.dart';
import 'edit_profile_screen.dart';
import 'car_information_screen.dart';
import 'maintenance_reminders_screen.dart';
import 'driver_license_screen.dart';
import 'android_call_bridge_status_screen.dart';
import 'emergency_history_screen.dart';
import 'home_page.dart';
import 'info_page_screen.dart';
import 'notification_settings_screen.dart';
import 'pairing_unpaired_screen.dart';
import 'security_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'voice_assistant_screen.dart';
import 'voice_preferences_screen.dart';
import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import '../utils/locale_helper.dart';
import '../utils/snackbar.dart';

// Match the app-wide bottom navigation style used on Home/Assistant/History.
const Color _navBg = AppColors.background;
const Color _navBorder = AppColors.border;

class SettingsScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  const SettingsScreen({super.key, this.onLocaleChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'English';
  String _selectedCountry = 'Egypt';

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = PreferencesService();
    final locale = await prefs.getLocale();
    if (!mounted) return;
    if (locale != null) {
      setState(() {
        _selectedLanguage = languageFromLocale(locale);
        // country isn't stored/read reliably from locale, keep existing or default
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Language / Country bar (moved from Home)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _openLanguageCountry,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[800]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.language,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$_selectedLanguage • $_selectedCountry',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Account Section
              _buildSectionTitle('Account'),
              const SizedBox(height: 8),
              _buildSettingsContainer([
                'Edit Profile',
                'Driver License',
                'Privacy',
              ]),
              const SizedBox(height: 24),
              // Car Settings Section
              _buildSectionTitle('Car Settings'),
              const SizedBox(height: 8),
              _buildSettingsContainer([
                'Vehicle Model & Info',
                'Maintenance Reminders',
                'Link/Unlink Vehicle',
                'Security Options',
              ]),
              const SizedBox(height: 24),
              // Voice Assistant Preference Section
              _buildSectionTitle('Voice Assistant Preference'),
              const SizedBox(height: 8),
              _buildSettingsContainer([
                'Language Selection',
                'Voice Type',
                'Voice Command Sensitivity',
              ]),
              const SizedBox(height: 24),
              // App Settings Section
              _buildSectionTitle('App Settings'),
              const SizedBox(height: 8),
              _buildSettingsContainer([
                'Theme',
                'Notifications',
                'Language',
                'Clear App Cache',
                'Android Call Bridge',
              ]),
              const SizedBox(height: 24),
              // Help & Support Section
              _buildSectionTitle('Help & Support'),
              const SizedBox(height: 8),
              _buildSettingsContainer([
                'FAQs',
                'Report a Problem',
                'User Guide',
                'Contact Us',
              ]),
              const SizedBox(height: 24),
              // About & Legal Section
              _buildSectionTitle('About & Legal'),
              const SizedBox(height: 8),
              _buildSettingsContainer([
                'Terms & Privacy Policy',
                'Version Info',
              ]),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _navBg,
          border: Border(
            top: BorderSide(
              color: _navBorder.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 78,
            child: Row(
              children: [
                _buildNavItem(Icons.home_outlined, 'Home', 0),
                _buildNavItem(Icons.mic_none, 'Assistant', 1),
                _buildNavItem(Icons.history, 'History', 2),
                _buildNavItem(Icons.settings_outlined, 'Settings', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              HomePage(onLocaleChanged: widget.onLocaleChanged),
        ),
        (route) => false,
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoiceAssistantScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              EmergencyHistoryScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    }
    // index == 3 is Settings — already here.
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final selected = index == 3;
    // Grey highlight: selected tab is bright grey/white, the rest dimmer grey.
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.45);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavTap(index),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[400],
        fontWeight: FontWeight.normal,
      ),
    );
  }

  Widget _buildSettingsContainer(List<String> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final isLast = index == items.length - 1;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onSettingsItemTap(items[index]),
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(12) : Radius.zero,
                    bottom: isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            items[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey[800],
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openLanguageCountry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageCountryScreen(
          initialLanguage: _selectedLanguage,
          initialCountry: _selectedCountry,
        ),
      ),
    );
    if (!mounted) return;
    if (result is Map) {
      setState(() {
        _selectedLanguage = result['language'] ?? _selectedLanguage;
        _selectedCountry = result['country'] ?? _selectedCountry;
      });
      if (widget.onLocaleChanged != null) {
        widget.onLocaleChanged!(localeFromLanguage(_selectedLanguage));
      }
    }
  }

  Future<void> _sendEmail(String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@amnapp.example',
      queryParameters: {'subject': subject},
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showAppSnack(context, 'No email app found. Reach us at support@amnapp.example');
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'No email app found. Reach us at support@amnapp.example');
      }
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Clear app cache?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This frees cached images and temporary data. Your account, '
          'contacts and saved data are not affected.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (!mounted) return;
    showAppSnack(context, 'App cache cleared.');
  }

  void _onSettingsItemTap(String label) {
    switch (label) {
      // Existing feature screens.
      case 'Edit Profile':
        _push(const EditProfileScreen());
        break;
      case 'Driver License':
        _push(const DriverLicenseScreen());
        break;
      case 'Vehicle Model & Info':
        _push(const CarInformationScreen());
        break;
      case 'Maintenance Reminders':
        _push(const MaintenanceRemindersScreen());
        break;
      case 'Android Call Bridge':
        _push(const AndroidCallBridgeStatusScreen());
        break;
      // Reused existing screens.
      case 'Link/Unlink Vehicle':
        _push(const PairingUnpairedScreen());
        break;
      case 'Language':
      case 'Language Selection':
        _openLanguageCountry();
        break;
      // New preference screens.
      case 'Security Options':
        _push(const SecuritySettingsScreen());
        break;
      case 'Notifications':
        _push(const NotificationSettingsScreen());
        break;
      case 'Theme':
        _push(const ThemeSettingsScreen());
        break;
      case 'Voice Type':
      case 'Voice Command Sensitivity':
        _push(const VoicePreferencesScreen());
        break;
      case 'Clear App Cache':
        _clearCache();
        break;
      // Information screens.
      case 'FAQs':
        _push(_faqPage());
        break;
      case 'User Guide':
        _push(_userGuidePage());
        break;
      case 'Contact Us':
        _push(_contactPage());
        break;
      case 'Report a Problem':
        _push(_reportPage());
        break;
      case 'Privacy':
      case 'Terms & Privacy Policy':
        _push(_legalPage());
        break;
      case 'Version Info':
        _push(_aboutPage());
        break;
    }
  }

  Widget _faqPage() => const InfoPageScreen(
    title: 'FAQs',
    sections: [
      InfoSection(
        'Hold the SOS button for 3 seconds. AMN opens the dialer with the '
        'ambulance number (123) and sends an SOS SMS with your location to '
        'your default emergency contact.',
        heading: 'How does the SOS button work?',
      ),
      InfoSection(
        'Open Safety Hub then Emergency Contacts, add a contact, and set one '
        'as the default from the 3-dots menu. The default contact receives '
        'the SOS SMS.',
        heading: 'How do I set my emergency contact?',
      ),
      InfoSection(
        'Tap Parking then Save to remember where you parked, then Find my car '
        'for walking directions back to it.',
        heading: 'How does Find my car work?',
      ),
      InfoSection(
        'No. AMN uses free, keyless maps (OpenStreetMap), so no paid maps key '
        'is needed. An internet connection is required for maps, weather and '
        'search.',
        heading: 'Do I need to pay for maps?',
      ),
      InfoSection(
        'Tap the microphone and speak, or tap a suggested command button. If '
        'speaking does not work, your device text-to-speech may need to be '
        'set up in the system settings.',
        heading: 'The voice assistant will not talk?',
      ),
    ],
  );

  Widget _userGuidePage() => const InfoPageScreen(
    title: 'User Guide',
    sections: [
      InfoSection(
        'AMN is your driving-safety companion: one tap for help, your '
        'emergency info in one place, and a hands-free voice assistant.',
        heading: 'Welcome',
      ),
      InfoSection(
        'The big red SOS button calls the ambulance and alerts your default '
        'contact. Below it are quick actions, live navigation and weather.',
        heading: 'Home and SOS',
      ),
      InfoSection(
        'Safety Hub holds the Egypt emergency numbers, your contacts, '
        'hospitals and a 23-topic first-aid guide for road injuries.',
        heading: 'Safety Hub',
      ),
      InfoSection(
        'Save your parking spot with one tap and get walking directions back '
        'to your car later.',
        heading: 'Parking',
      ),
      InfoSection(
        'Tap the microphone and speak a command such as "call police" or '
        '"where am I", or tap a suggestion chip.',
        heading: 'Voice Assistant',
      ),
    ],
  );

  Widget _legalPage() => const InfoPageScreen(
    title: 'Terms & Privacy',
    sections: [
      InfoSection(
        'AMN is provided as an assistance tool for drivers. It is not a '
        'replacement for contacting the official emergency services directly.',
        heading: 'Terms of Use',
      ),
      InfoSection(
        'AMN stores your profile, emergency contacts and history to provide '
        'its features. Your location is used only to power SOS, parking and '
        'navigation, and is shared only when you send an SOS or choose to '
        'share your location.',
        heading: 'Privacy',
      ),
      InfoSection(
        'AMN is a graduation project. Always confirm a real emergency by '
        'calling the official services yourself.',
        heading: 'Disclaimer',
      ),
    ],
  );

  Widget _aboutPage() => const InfoPageScreen(
    title: 'About',
    sections: [
      InfoSection('AMN', heading: 'App'),
      InfoSection('Version 1.0.0 (build 1)'),
      InfoSection(
        'A keyless driving-safety assistant: SOS, emergency contacts, '
        'hospitals, first aid, parking, navigation, weather and a voice '
        'assistant.',
        heading: 'About',
      ),
    ],
  );

  Widget _contactPage() => InfoPageScreen(
    title: 'Contact Us',
    sections: const [
      InfoSection(
        'We would love to hear from you. Email the AMN team and we will get '
        'back to you.',
        heading: 'Get in touch',
      ),
      InfoSection('support@amnapp.example'),
    ],
    actions: [
      InfoAction(
        label: 'Send us an email',
        icon: Icons.email_outlined,
        onTap: () {
          _sendEmail('AMN app - question');
        },
      ),
    ],
  );

  Widget _reportPage() => InfoPageScreen(
    title: 'Report a Problem',
    sections: const [
      InfoSection(
        'Found a bug or something not working? Tell us what happened and we '
        'will look into it.',
        heading: 'Report a Problem',
      ),
      InfoSection(
        'Please include what you were doing when the problem happened.',
      ),
    ],
    actions: [
      InfoAction(
        label: 'Email a report',
        icon: Icons.bug_report_outlined,
        onTap: () {
          _sendEmail('AMN app - problem report');
        },
      ),
    ],
  );
}
