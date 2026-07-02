import 'package:flutter/material.dart';

import '../services/usage_logger.dart';
import 'emergency_services_screen.dart';
import 'emergency_contacts_screen.dart';
import 'hospital_insurance_screen.dart';
import 'first_aid_screen.dart';
import 'emergency_numbers_screen.dart';
import 'emergency_history_screen.dart';
import 'engine_status_screen.dart';
import 'driver_status_screen.dart';
import 'parking_map_screen.dart';
import 'car_control_screen.dart';
import 'voice_assistant_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    UsageLogger.logScreenView('MenuScreen');

    final items = <_MenuItem>[
      _MenuItem(
        icon: Icons.sos,
        label: 'Emergency SOS & Services',
        subtitle: 'SOS, contacts, hospitals, first aid',
        builder: (context) => const EmergencyServicesScreen(),
      ),
      _MenuItem(
        icon: Icons.contacts_outlined,
        label: 'Emergency Contacts',
        subtitle: 'People to notify in emergencies',
        builder: (context) => const EmergencyContactsScreen(),
      ),
      _MenuItem(
        icon: Icons.local_hospital_outlined,
        label: 'Hospital & Insurance',
        subtitle: 'Nearest hospitals, call & directions',
        builder: (context) => const HospitalInsuranceScreen(),
      ),
      _MenuItem(
        icon: Icons.medical_services_outlined,
        label: 'First Aid Tips',
        subtitle: 'CPR, bleeding, choking and more',
        builder: (context) => const FirstAidScreen(),
      ),
      _MenuItem(
        icon: Icons.call_outlined,
        label: 'Emergency Numbers (Egypt)',
        subtitle: 'Police, ambulance, firefighters, etc.',
        builder: (context) => const EmergencyNumbersScreen(),
      ),
      _MenuItem(
        icon: Icons.history,
        label: 'Emergency History',
        subtitle: 'Previous SOS and emergency events',
        builder: (context) => const EmergencyHistoryScreen(),
      ),
      _MenuItem(
        icon: Icons.directions_car_filled_outlined,
        label: 'Engine Status',
        subtitle: 'Normal, caution, and fault monitoring',
        builder: (context) => const EngineStatusScreen(),
      ),
      _MenuItem(
        icon: Icons.person_outline,
        label: 'Driver Status',
        subtitle: 'Attentiveness, fatigue & safety scores',
        builder: (context) => const DriverStatusScreen(),
      ),
      _MenuItem(
        icon: Icons.local_parking,
        label: 'Parking Map',
        subtitle: 'Find and track your parking spot',
        builder: (context) => const ParkingMapScreen(),
      ),
      _MenuItem(
        icon: Icons.settings_remote,
        label: 'Car Controls',
        subtitle: 'Speed, drive mode, charging',
        builder: (context) => const CarControlScreen(),
      ),
      _MenuItem(
        icon: Icons.mic,
        label: 'Voice Assistant',
        subtitle: 'Control the app with your voice',
        builder: (context) => const VoiceAssistantScreen(),
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
          'Menu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _MenuTile(item: item);
        },
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final WidgetBuilder builder;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.builder,
  });
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          UsageLogger.logAction('menu_open_${item.label}');
          Navigator.push(context, MaterialPageRoute(builder: item.builder));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
