import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _background = Color(0xFF020607);
const Color _card = Color(0xFF121417);
const Color _cardRaised = Color(0xFF17191D);
const Color _border = Color(0xFF2C3136);
const Color _red = Color(0xFFE81218);
const Color _green = Color(0xFF45D64A);
const Color _yellow = Color(0xFFFFC928);
const Color _muted = Color(0xFFB7BABF);

enum _EngineLevel { normal, caution, fault }

class _EngineSnapshot {
  final double temperatureC;
  final double oilPressurePsi;
  final double batteryVoltage;
  final int rpm;
  final bool engineFault;
  final bool checkEngine;
  final bool maintenanceDue;
  final String faultCode;
  final DateTime? updatedAt;

  const _EngineSnapshot({
    required this.temperatureC,
    required this.oilPressurePsi,
    required this.batteryVoltage,
    required this.rpm,
    required this.engineFault,
    required this.checkEngine,
    required this.maintenanceDue,
    required this.faultCode,
    required this.updatedAt,
  });

  factory _EngineSnapshot.normal() {
    return const _EngineSnapshot(
      temperatureC: 90,
      oilPressurePsi: 42,
      batteryVoltage: 13.8,
      rpm: 780,
      engineFault: false,
      checkEngine: false,
      maintenanceDue: false,
      faultCode: '',
      updatedAt: null,
    );
  }

  factory _EngineSnapshot.fromMap(Map<String, dynamic>? data) {
    if (data == null) return _EngineSnapshot.normal();

    final timestamp =
        data['engineStatusUpdatedAt'] ?? data['carStatusUpdatedAt'];
    DateTime? updatedAt;
    if (timestamp is Timestamp) {
      updatedAt = timestamp.toDate();
    } else {
      updatedAt = DateTime.tryParse(timestamp?.toString() ?? '');
    }

    return _EngineSnapshot(
      temperatureC: _readDouble(data['engineTempC'], 90),
      oilPressurePsi: _readDouble(data['oilPressurePsi'], 42),
      batteryVoltage: _readDouble(data['batteryVoltage'], 13.8),
      rpm: _readInt(data['rpm'], 780),
      engineFault: data['engineFault'] == true,
      checkEngine: data['checkEngine'] == true,
      maintenanceDue: data['maintenanceDue'] == true,
      faultCode: (data['faultCode'] ?? '').toString(),
      updatedAt: updatedAt,
    );
  }

  _EngineLevel get level {
    if (engineFault ||
        checkEngine ||
        faultCode.trim().isNotEmpty ||
        temperatureC >= 116 ||
        oilPressurePsi < 18 ||
        batteryVoltage < 11.5) {
      return _EngineLevel.fault;
    }

    if (maintenanceDue ||
        temperatureC >= 105 ||
        temperatureC < 70 ||
        oilPressurePsi < 25 ||
        batteryVoltage < 12.2) {
      return _EngineLevel.caution;
    }

    return _EngineLevel.normal;
  }

  String get statusTitle {
    return switch (level) {
      _EngineLevel.normal => 'Engine Operating Normally',
      _EngineLevel.caution => 'Engine Needs Attention',
      _EngineLevel.fault => 'Engine Fault Detected',
    };
  }

  String get statusSubtitle {
    return switch (level) {
      _EngineLevel.normal => 'All monitored engine readings are within range.',
      _EngineLevel.caution =>
        'A maintenance or caution condition should be checked soon.',
      _EngineLevel.fault =>
        'An abnormal condition is active. Inspect the engine immediately.',
    };
  }
}

class EngineStatusScreen extends StatelessWidget {
  const EngineStatusScreen({super.key});

  Stream<_EngineSnapshot> _engineStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream<_EngineSnapshot>.value(_EngineSnapshot.normal());
    }

    return FirebaseFirestore.instance
        .collection('user_status')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => _EngineSnapshot.fromMap(snapshot.data()));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
          child: StreamBuilder<_EngineSnapshot>(
            stream: _engineStream(),
            initialData: _EngineSnapshot.normal(),
            builder: (context, snapshot) {
              final engine = snapshot.data ?? _EngineSnapshot.normal();

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  _TopBar(onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 20),
                  _MainStatusCard(engine: engine),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.thermostat,
                          label: 'Temperature',
                          value: '${engine.temperatureC.toStringAsFixed(0)} C',
                          level: _temperatureLevel(engine.temperatureC),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.oil_barrel_outlined,
                          label: 'Oil Pressure',
                          value:
                              '${engine.oilPressurePsi.toStringAsFixed(0)} PSI',
                          level: _oilLevel(engine.oilPressurePsi),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.battery_charging_full,
                          label: 'Battery',
                          value:
                              '${engine.batteryVoltage.toStringAsFixed(1)} V',
                          level: _batteryLevel(engine.batteryVoltage),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.speed,
                          label: 'RPM',
                          value: engine.rpm.toString(),
                          level: _EngineLevel.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _WarningPanel(engine: engine),
                  const SizedBox(height: 16),
                  const _LegendPanel(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: _IconCircleButton(icon: Icons.chevron_left, onTap: onBack),
          ),
          const Text(
            'Engine Status',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _red.withValues(alpha: 0.45)),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: _red,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
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

class _MainStatusCard extends StatelessWidget {
  final _EngineSnapshot engine;

  const _MainStatusCard({required this.engine});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(engine.level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _EngineIndicator(level: engine.level),
          const SizedBox(height: 18),
          Text(
            engine.statusTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            engine.statusSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.3,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _updatedText(engine.updatedAt),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineIndicator extends StatelessWidget {
  final _EngineLevel level;

  const _EngineIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    final icon = switch (level) {
      _EngineLevel.normal => Icons.check,
      _EngineLevel.caution => Icons.warning_amber_rounded,
      _EngineLevel.fault => Icons.close,
    };

    return SizedBox(
      width: 142,
      height: 142,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.36),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 42),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _EngineLevel level;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);

    return Container(
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  final _EngineSnapshot engine;

  const _WarningPanel({required this.engine});

  @override
  Widget build(BuildContext context) {
    final warnings = _warningsFor(engine);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engine Warnings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          if (warnings.isEmpty)
            const _WarningRow(
              icon: Icons.check_circle_outline,
              color: _green,
              title: 'No active warnings',
              subtitle: 'The engine is currently operating normally.',
            )
          else
            for (var i = 0; i < warnings.length; i++) ...[
              warnings[i],
              if (i != warnings.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _WarningRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendPanel extends StatelessWidget {
  const _LegendPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Colors',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 12),
          _LegendRow(color: _green, text: 'Green: engine operating normally'),
          SizedBox(height: 9),
          _LegendRow(color: _yellow, text: 'Yellow: caution or maintenance'),
          SizedBox(height: 9),
          _LegendRow(color: _red, text: 'Red: fault or abnormal condition'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendRow({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconCircleButton({required this.icon, required this.onTap});

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
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

List<_WarningRow> _warningsFor(_EngineSnapshot engine) {
  final rows = <_WarningRow>[];

  if (engine.engineFault || engine.checkEngine) {
    rows.add(
      const _WarningRow(
        icon: Icons.error_outline,
        color: _red,
        title: 'Engine fault active',
        subtitle: 'The engine control system is reporting an abnormal state.',
      ),
    );
  }

  if (engine.faultCode.trim().isNotEmpty) {
    rows.add(
      _WarningRow(
        icon: Icons.code,
        color: _red,
        title: 'Fault code ${engine.faultCode}',
        subtitle: 'Read diagnostic details before continuing your trip.',
      ),
    );
  }

  if (engine.temperatureC >= 116) {
    rows.add(
      const _WarningRow(
        icon: Icons.thermostat,
        color: _red,
        title: 'Engine overheating',
        subtitle: 'Stop safely and allow the engine to cool.',
      ),
    );
  } else if (engine.temperatureC >= 105 || engine.temperatureC < 70) {
    rows.add(
      const _WarningRow(
        icon: Icons.thermostat,
        color: _yellow,
        title: 'Temperature caution',
        subtitle: 'Monitor the engine temperature during your trip.',
      ),
    );
  }

  if (engine.oilPressurePsi < 18) {
    rows.add(
      const _WarningRow(
        icon: Icons.oil_barrel_outlined,
        color: _red,
        title: 'Low oil pressure',
        subtitle: 'Avoid driving until the oil system is checked.',
      ),
    );
  } else if (engine.oilPressurePsi < 25) {
    rows.add(
      const _WarningRow(
        icon: Icons.oil_barrel_outlined,
        color: _yellow,
        title: 'Oil pressure caution',
        subtitle: 'Schedule maintenance if this reading continues.',
      ),
    );
  }

  if (engine.batteryVoltage < 11.5) {
    rows.add(
      const _WarningRow(
        icon: Icons.battery_alert_outlined,
        color: _red,
        title: 'Battery voltage abnormal',
        subtitle: 'The electrical system may not be charging correctly.',
      ),
    );
  } else if (engine.batteryVoltage < 12.2) {
    rows.add(
      const _WarningRow(
        icon: Icons.battery_alert_outlined,
        color: _yellow,
        title: 'Battery caution',
        subtitle: 'Battery voltage is lower than expected.',
      ),
    );
  }

  if (engine.maintenanceDue) {
    rows.add(
      const _WarningRow(
        icon: Icons.build_circle_outlined,
        color: _yellow,
        title: 'Maintenance due',
        subtitle: 'Book service soon to keep the engine healthy.',
      ),
    );
  }

  return rows;
}

_EngineLevel _temperatureLevel(double temp) {
  if (temp >= 116) return _EngineLevel.fault;
  if (temp >= 105 || temp < 70) return _EngineLevel.caution;
  return _EngineLevel.normal;
}

_EngineLevel _oilLevel(double pressure) {
  if (pressure < 18) return _EngineLevel.fault;
  if (pressure < 25) return _EngineLevel.caution;
  return _EngineLevel.normal;
}

_EngineLevel _batteryLevel(double voltage) {
  if (voltage < 11.5) return _EngineLevel.fault;
  if (voltage < 12.2) return _EngineLevel.caution;
  return _EngineLevel.normal;
}

Color _levelColor(_EngineLevel level) {
  return switch (level) {
    _EngineLevel.normal => _green,
    _EngineLevel.caution => _yellow,
    _EngineLevel.fault => _red,
  };
}

String _updatedText(DateTime? updatedAt) {
  if (updatedAt == null) return 'Waiting for live engine data';

  final local = updatedAt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Last updated $hour:$minute';
}

double _readDouble(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _readInt(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
