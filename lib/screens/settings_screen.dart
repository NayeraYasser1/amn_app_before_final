import 'package:flutter/material.dart';
import 'language_country_screen.dart';
import 'edit_profile_screen.dart';
import 'car_information_screen.dart';
import 'maintenance_reminders_screen.dart';
import 'driver_license_screen.dart';
import 'android_call_bridge_status_screen.dart';
import 'emergency_history_screen.dart';
import 'home_page.dart';
import 'voice_assistant_screen.dart';
import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import '../utils/locale_helper.dart';

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
                        onTap: () async {
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
                              _selectedLanguage =
                                  result['language'] ?? _selectedLanguage;
                              _selectedCountry =
                                  result['country'] ?? _selectedCountry;
                            });
                            if (widget.onLocaleChanged != null) {
                              final locale = localeFromLanguage(
                                _selectedLanguage,
                              );
                              widget.onLocaleChanged!(locale);
                            }
                          }
                        },
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

  void _onSettingsItemTap(String label) {
    if (label == 'Edit Profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
      );
    } else if (label == 'Driver License') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverLicenseScreen()),
      );
    } else if (label == 'Vehicle Model & Info') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CarInformationScreen()),
      );
    } else if (label == 'Maintenance Reminders') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MaintenanceRemindersScreen()),
      );
    } else if (label == 'Android Call Bridge') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AndroidCallBridgeStatusScreen(),
        ),
      );
    } else {
      // Unimplemented settings row — give the user feedback instead of a
      // dead tap. These get wired up as the features land.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$label" is coming soon.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
