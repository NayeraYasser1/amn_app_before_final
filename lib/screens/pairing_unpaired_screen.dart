import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/usage_logger.dart';

const Color _bg = Color(0xFF020607);
const Color _card = Color(0xFF121417);
const Color _border = Color(0xFF2D3238);
const Color _red = Color(0xFFE81218);
const Color _blue = Color(0xFF087BFF);
const Color _green = Color(0xFF39D74A);
const Color _muted = Color(0xFFB7BABF);

enum _PairingStage {
  start,
  scanning,
  selectCar,
  verifyCode,
  pairing,
  success,
  failed,
}

class PairingUnpairedScreen extends StatefulWidget {
  const PairingUnpairedScreen({super.key});

  @override
  State<PairingUnpairedScreen> createState() => _PairingUnpairedScreenState();
}

class _PairingUnpairedScreenState extends State<PairingUnpairedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  Timer? _autoTimer;
  _PairingStage _stage = _PairingStage.start;
  double _pairingProgress = 0.75;

  @override
  void initState() {
    super.initState();
    UsageLogger.logScreenView('PairingUnpairedScreen');
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  void _setStage(_PairingStage stage) {
    _autoTimer?.cancel();
    setState(() => _stage = stage);
  }

  void _startScanning() {
    UsageLogger.logAction('pairing_start_tap');
    _setStage(_PairingStage.scanning);
    _autoTimer = Timer(
      const Duration(seconds: 2),
      () => mounted ? _setStage(_PairingStage.selectCar) : null,
    );
  }

  void _selectCar() {
    UsageLogger.logAction('pairing_car_selected');
    _setStage(_PairingStage.verifyCode);
  }

  void _verifyCode() {
    UsageLogger.logAction('pairing_code_verified');
    setState(() {
      _stage = _PairingStage.pairing;
      _pairingProgress = 0.75;
    });
    _autoTimer = Timer(
      const Duration(seconds: 2),
      () => mounted ? _setStage(_PairingStage.success) : null,
    );
  }

  void _finish() {
    UsageLogger.logAction('pairing_done_tap');
    Navigator.popUntil(context, (route) => route.isFirst);
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _buildStage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _PairingStage.start:
        return _StartStage(
          key: const ValueKey('start'),
          onStart: _startScanning,
        );
      case _PairingStage.scanning:
        return _ScanningStage(
          key: const ValueKey('scanning'),
          animation: _radarController,
          onCancel: () => _setStage(_PairingStage.start),
        );
      case _PairingStage.selectCar:
        return _SelectCarStage(
          key: const ValueKey('selectCar'),
          onSelect: _selectCar,
          onHelp: () => _setStage(_PairingStage.failed),
        );
      case _PairingStage.verifyCode:
        return _VerifyCodeStage(
          key: const ValueKey('verifyCode'),
          onCancel: () => _setStage(_PairingStage.start),
          onVerified: _verifyCode,
        );
      case _PairingStage.pairing:
        return _PairingStageView(
          key: const ValueKey('pairing'),
          progress: _pairingProgress,
        );
      case _PairingStage.success:
        return _SuccessStage(key: const ValueKey('success'), onDone: _finish);
      case _PairingStage.failed:
        return _FailedStage(
          key: const ValueKey('failed'),
          onTryAgain: _startScanning,
          onHelp: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Make sure Bluetooth is on.')),
          ),
        );
    }
  }
}

class _StageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? bottom;

  const _StageShell({required this.title, required this.child, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        Expanded(child: child),
        if (bottom != null) bottom!,
      ],
    );
  }
}

class _StartStage extends StatelessWidget {
  final VoidCallback onStart;

  const _StartStage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      title: 'Pair Your Car',
      bottom: Column(
        children: [
          _PrimaryButton(text: 'Start Pairing', onPressed: onStart),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Need help?',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 106,
            height: 106,
            decoration: const BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth, color: Colors.white, size: 64),
          ),
          const SizedBox(height: 48),
          const Text(
            'Turn on Bluetooth and\nmake sure you are\nnear your car',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ScanningStage extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onCancel;

  const _ScanningStage({
    super.key,
    required this.animation,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      title: 'Scanning for cars',
      bottom: _SecondaryButton(text: 'Cancel', onPressed: onCancel),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 230,
            height: 230,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RadarPainter(sweep: animation.value),
                );
              },
            ),
          ),
          const SizedBox(height: 34),
          const Text(
            'Searching for\nnearby vehicles...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SelectCarStage extends StatelessWidget {
  final VoidCallback onSelect;
  final VoidCallback onHelp;

  const _SelectCarStage({
    super.key,
    required this.onSelect,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      title: 'Select Your Car',
      bottom: Column(
        children: [
          _SecondaryButton(text: 'Select', onPressed: onSelect),
          const SizedBox(height: 22),
          TextButton(
            onPressed: onHelp,
            child: const Text(
              "Can't find your car?",
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 8),
          Center(
            child: Text(
              '1 car found (demo)',
              style: TextStyle(color: _muted, fontSize: 15),
            ),
          ),
          SizedBox(height: 24),
          Center(child: _CarIllustration()),
          SizedBox(height: 28),
          Text(
            'BMW IX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'VIN:   WB5234XXXX0000X',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _VerifyCodeStage extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onVerified;

  const _VerifyCodeStage({
    super.key,
    required this.onCancel,
    required this.onVerified,
  });

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      title: 'Verifying',
      bottom: _SecondaryButton(text: 'Cancel', onPressed: onCancel),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Please confirm the code\nshown on your car screen',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17, height: 1.35),
          ),
          const SizedBox(height: 34),
          GestureDetector(
            onTap: onVerified,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _CodeDigit('2'),
                SizedBox(width: 12),
                _CodeDigit('4'),
                SizedBox(width: 12),
                _CodeDigit('7'),
                SizedBox(width: 12),
                _CodeDigit('1'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap code to confirm',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PairingStageView extends StatelessWidget {
  final double progress;

  const _PairingStageView({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      title: 'Pairing...',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 122,
            height: 122,
            decoration: const BoxDecoration(
              color: Color(0xFF242930),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.link, color: Colors.white, size: 58),
          ),
          const SizedBox(height: 42),
          const Text(
            'Please wait while\nwe connect to\nyour car',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17, height: 1.45),
          ),
          const SizedBox(height: 42),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: const Color(0xFF1A2026),
                    color: _blue,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
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

class _SuccessStage extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessStage({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      title: 'Successfully Paired!',
      bottom: _SecondaryButton(text: 'Done', onPressed: onDone),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusCircle(
            color: _green,
            icon: Icons.check,
            backgroundAlpha: 0.28,
          ),
          const SizedBox(height: 26),
          const Text(
            'BMW IX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'is now connected',
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),
        ],
      ),
    );
  }
}

class _FailedStage extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onHelp;

  const _FailedStage({
    super.key,
    required this.onTryAgain,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      title: 'Pairing Failed',
      bottom: Column(
        children: [
          _PrimaryButton(text: 'Try Again', onPressed: onTryAgain),
          const SizedBox(height: 18),
          _SecondaryButton(text: 'View Help', onPressed: onHelp),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _StatusCircle(color: _red, icon: Icons.close, backgroundAlpha: 0.25),
          SizedBox(height: 30),
          Text(
            'Unable to connect\nto your car',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _CodeDigit extends StatelessWidget {
  final String value;

  const _CodeDigit(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 31,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double backgroundAlpha;

  const _StatusCircle({
    required this.color,
    required this.icon,
    required this.backgroundAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: backgroundAlpha),
      ),
      child: Center(
        child: Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 26,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 76),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _card,
          foregroundColor: Colors.white,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweep;

  const _RadarPainter({required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2 - 6;
    final ringPaint = Paint()
      ..color = const Color(0xFF0D6F5E).withValues(alpha: 0.38)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00D5B5).withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, ringPaint);
    }

    final startAngle = sweep * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      startAngle,
      math.pi / 3,
      true,
      fillPaint,
    );
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = _bg
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweep != sweep;
  }
}

class _CarIllustration extends StatelessWidget {
  const _CarIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      height: 116,
      child: CustomPaint(painter: _CarPainter()),
    );
  }
}

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = const Color(0xFF20272D);
    final dark = Paint()..color = const Color(0xFF070A0C);
    final glass = Paint()..color = const Color(0xFF141A20);
    final highlight = Paint()..color = const Color(0xFF6D7880);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawOval(
      Rect.fromLTWH(18, size.height - 28, size.width - 36, 18),
      shadow,
    );

    final bodyPath = Path()
      ..moveTo(22, 72)
      ..quadraticBezierTo(38, 44, 76, 42)
      ..lineTo(103, 22)
      ..quadraticBezierTo(145, 12, 180, 35)
      ..quadraticBezierTo(211, 41, 222, 70)
      ..lineTo(222, 84)
      ..lineTo(22, 84)
      ..close();
    canvas.drawPath(bodyPath, body);

    final windowPath = Path()
      ..moveTo(89, 42)
      ..lineTo(110, 26)
      ..lineTo(150, 26)
      ..lineTo(168, 43)
      ..close();
    canvas.drawPath(windowPath, glass);
    canvas.drawLine(
      const Offset(127, 27),
      const Offset(123, 43),
      Paint()
        ..color = const Color(0xFF2F3940)
        ..strokeWidth = 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(32, 66, 42, 11),
        const Radius.circular(4),
      ),
      highlight,
    );
    canvas.drawRect(Rect.fromLTWH(189, 68, 24, 7), Paint()..color = _red);
    canvas.drawCircle(const Offset(66, 84), 20, dark);
    canvas.drawCircle(const Offset(176, 84), 20, dark);
    canvas.drawCircle(
      const Offset(66, 84),
      10,
      Paint()..color = const Color(0xFF98A2A8),
    );
    canvas.drawCircle(
      const Offset(176, 84),
      10,
      Paint()..color = const Color(0xFF98A2A8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
