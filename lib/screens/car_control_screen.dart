import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/usage_logger.dart';

class CarControlScreen extends StatelessWidget {
  const CarControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF050415),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Car Controls',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          bottom: const TabBar(
            indicatorColor: Colors.purpleAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Controls'),
              Tab(text: 'Charging'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ControlsTab(), _ChargingTab()]),
      ),
    );
  }
}

class _ControlsTab extends StatefulWidget {
  const _ControlsTab();

  @override
  State<_ControlsTab> createState() => _ControlsTabState();
}

class _ControlsTabState extends State<_ControlsTab> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF050415), Color(0xFF140B33)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            // Top row: large speed gauge centered with side controls
            Expanded(
              child: Row(
                children: [
                  // Left side icons
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _SideControlIcon(icon: Icons.info, label: ''),
                      SizedBox(height: 12),
                      _SideControlIcon(icon: Icons.ev_station, label: ''),
                      SizedBox(height: 12),
                      _SideControlIcon(icon: Icons.settings, label: ''),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Speed gauge
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _ArcBackground(),
                              const _SpeedLabel(speed: 60),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'mph',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  // Right side vertical controls
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _SideControlIcon(icon: Icons.wifi, label: ''),
                      SizedBox(height: 12),
                      _SideControlIcon(icon: Icons.brightness_6, label: ''),
                      SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            // Drive mode and power button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF6366F1)],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'D',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sport mode',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),
            // Power button
            InkWell(
              onTap: () async {
                await UsageLogger.logAction('power_button_tap');
                HapticFeedback.lightImpact();
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.power_settings_new,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ChargingTab extends StatefulWidget {
  const _ChargingTab();

  @override
  State<_ChargingTab> createState() => _ChargingTabState();
}

class _ChargingTabState extends State<_ChargingTab> {
  final double _percent = 0.75;
  bool _isCharging = true;

  Future<void> _stopCharging() async {
    if (!_isCharging) return;
    setState(() => _isCharging = false);
    await UsageLogger.logAction(
      'charging_stopped',
      data: {'percent': (_percent * 100).round(), 'station': '#4'},
    );
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Charging stopped')));
  }

  Future<void> _startCharging() async {
    if (_isCharging) return;
    setState(() => _isCharging = true);
    await UsageLogger.logAction('charging_started', data: {'station': '#4'});
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Charging started')));
  }

  @override
  Widget build(BuildContext context) {
    final cost = (_percent * 16).toStringAsFixed(2); // simple cost calc
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF050415), Color(0xFF071725)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          // Charging card with arc and info
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: _ChargingArc(percent: _percent),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(_percent * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isCharging ? 'Fast Charging' : 'Paused',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(
                      child: _ChargingInfoTile(label: 'Station', value: '#4'),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _ChargingInfoTile(label: 'Power', value: '50 kW'),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _ChargingInfoTile(
                        label: 'Remaining',
                        value: '50 min',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Start Time',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'End Time',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('9:32 AM', style: TextStyle(color: Colors.white)),
                    Text('9:45 AM', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () async {
                    await UsageLogger.logAction(
                      'need_assistance_tap',
                      data: {'station': '#4'},
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Assistance requested')),
                    );
                  },
                  child: const Text('Need Assistance'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '\$$cost',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCharging
                      ? Colors.pinkAccent
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: _isCharging ? _stopCharging : _startCharging,
                child: Text(
                  _isCharging ? 'Stop Charging' : 'Start Charging',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ArcPainter(), child: Container());
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 10,
    );

    final background = Paint()
      ..color = Colors.white10
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;

    final foreground = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.blueAccent, Colors.purpleAccent, Colors.pinkAccent],
      ).createShader(rect)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 3.14 * 0.8, 3.14 * 1.4, false, background);

    canvas.drawArc(rect, 3.14 * 0.8, 3.14 * 0.8, false, foreground);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeedLabel extends StatelessWidget {
  final int speed;
  const _SpeedLabel({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$speed',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Speed',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

class _SideControlIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SideControlIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _ChargingArc extends StatelessWidget {
  final double percent;
  const _ChargingArc({required this.percent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChargingArcPainter(percent: percent),
      child: Container(),
    );
  }
}

class _ChargingArcPainter extends CustomPainter {
  final double percent;
  const _ChargingArcPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 12,
    );

    final background = Paint()
      ..color = Colors.white10
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;

    final foreground = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.greenAccent, Colors.yellowAccent],
      ).createShader(rect)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 3.14 * 0.8, 3.14 * 1.4, false, background);
    canvas.drawArc(rect, 3.14 * 0.8, 3.14 * 1.4 * percent, false, foreground);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChargingInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _ChargingInfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
