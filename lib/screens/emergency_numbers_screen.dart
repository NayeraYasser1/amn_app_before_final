import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_history_service.dart';

class EmergencyNumbersScreen extends StatelessWidget {
  const EmergencyNumbersScreen({super.key});

  static final List<_EmergencyNumber> _numbers = [
    _EmergencyNumber(
      name: 'Police',
      number: '122',
      icon: Icons.local_police,
      color: Colors.blueAccent,
    ),
    _EmergencyNumber(
      name: 'Ambulance',
      number: '123',
      icon: Icons.local_hospital,
      color: Colors.redAccent,
    ),
    _EmergencyNumber(
      name: 'Firefighters',
      number: '180',
      icon: Icons.local_fire_department,
      color: Colors.orangeAccent,
    ),
    _EmergencyNumber(
      name: 'Traffic Police',
      number: '128',
      icon: Icons.traffic,
      color: Colors.amber,
    ),
    _EmergencyNumber(
      name: 'Emergency Gas',
      number: '129',
      icon: Icons.local_gas_station,
      color: Colors.greenAccent,
    ),
    _EmergencyNumber(
      name: 'Tourist Police',
      number: '126',
      icon: Icons.public,
      color: Colors.tealAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          'Emergency Numbers - Egypt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView.separated(
          itemCount: _numbers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _numbers[index];
            return _EmergencyNumberCard(item: item);
          },
        ),
      ),
    );
  }
}

class _EmergencyNumber {
  final String name;
  final String number;
  final IconData icon;
  final Color color;

  const _EmergencyNumber({
    required this.name,
    required this.number,
    required this.icon,
    required this.color,
  });
}

class _EmergencyNumberCard extends StatelessWidget {
  final _EmergencyNumber item;

  const _EmergencyNumberCard({required this.item});

  Future<void> _openDialer(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: item.number);

    try {
      await EmergencyHistoryService.logEvent(
        type: 'emergency_call',
        title: '${item.name} Dialer Opened',
        description: item.number,
        status: 'In Progress',
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the phone dialer.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: item.color.withValues(alpha: 0.2),
            child: Icon(item.icon, color: item.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _openDialer(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      item.number,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openDialer(context),
              child: const Text(
                'Call',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
