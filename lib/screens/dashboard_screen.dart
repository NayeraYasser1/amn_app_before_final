import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/usage_logger.dart';
import 'emergency_history_screen.dart';
import 'home_page.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool carHealthExpanded = false;
  bool driverBehaviorExpanded = false;
  bool safetyScoreExpanded = false;
  String activeTab = 'Weekly';

  @override
  void initState() {
    super.initState();
    UsageLogger.logScreenView('DashboardScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Nayera Yasser',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Last checked: 2 mins ago',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExpandableSectionCard(
            title: 'Car Health Section',
            subtitle: 'Weekly vs Monthly',
            isExpanded: carHealthExpanded,
            onTap: () {
              setState(() {
                carHealthExpanded = !carHealthExpanded;
              });
            },
            menuItems: const [
              'Engine Health',
              'Fuel System',
              'Tire Health',
              'Oil Condition',
              'Temp. System',
              'Battery Voltage',
              'Mileage Tracker',
            ],
            onMenuItemTap: (item) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Selected: $item')));
            },
          ),
          const SizedBox(height: 12),
          _ExpandableSectionCard(
            title: 'Driver Behavior Section',
            subtitle: 'Summary',
            isExpanded: driverBehaviorExpanded,
            onTap: () {
              setState(() {
                driverBehaviorExpanded = !driverBehaviorExpanded;
              });
            },
            menuItems: const [
              'Attention Score',
              'Fatigue Level',
              'Speed Behavior',
              'Acceleration Pattern',
              'Consistency Score',
            ],
            onMenuItemTap: (item) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Selected: $item')));
            },
          ),
          const SizedBox(height: 12),
          _ExpandableSectionCard(
            title: 'Safety Score',
            subtitle: 'Weekly vs Monthly',
            isExpanded: safetyScoreExpanded,
            onTap: () {
              setState(() {
                safetyScoreExpanded = !safetyScoreExpanded;
              });
            },
            menuItems: const [
              'Safety Score',
              'Driver Risk Behaviour',
              'Accident Probability',
              'High Risk Factor',
              'Over Speed',
              'Hard Breaks',
              'Predictive Maintenance Alerts',
            ],
            onMenuItemTap: (item) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Selected: $item')));
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false,
              );
              return;
            }
            if (index == 1) {
              UsageLogger.logAction('voice_assistant_open');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VoiceAssistantScreen(),
                ),
              );
              return;
            }
            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyHistoryScreen(),
                ),
              );
              return;
            }
            if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.grey[900],
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic_none),
              label: 'Assistant',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<String> menuItems;
  final Function(String) onMenuItemTap;

  const _ExpandableSectionCard({
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onTap,
    required this.menuItems,
    required this.onMenuItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(color: Colors.grey[800], height: 1),
            // Chart area
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // Simple chart representation with gradient
                    Positioned.fill(
                      child: CustomPaint(painter: _SimpleChartPainter()),
                    ),
                    // Chart label
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '52km',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: Colors.grey[800], height: 1),
            // Menu items
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: List.generate(
                  menuItems.length,
                  (index) => GestureDetector(
                    onTap: () => onMenuItemTap(menuItems[index]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            menuItems[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimpleChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF1E90FF).withValues(alpha: 0.3),
          const Color(0xFF1E90FF).withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw gradient area
    final path = Path();
    path.moveTo(0, size.height);

    // Create wave-like pattern
    for (int i = 0; i <= size.width.toInt(); i += 10) {
      final x = i.toDouble();
      final y =
          size.height * (0.4 + 0.2 * math.sin(x / size.width * 6.28).abs());
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw line
    final linePaint = Paint()
      ..color = const Color(0xFF1E90FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    linePath.moveTo(0, size.height * 0.5);

    for (int i = 0; i <= size.width.toInt(); i += 10) {
      final x = i.toDouble();
      final y =
          size.height * (0.4 + 0.2 * math.sin(x / size.width * 6.28).abs());
      linePath.lineTo(x, y);
    }

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_SimpleChartPainter oldDelegate) => false;
}
