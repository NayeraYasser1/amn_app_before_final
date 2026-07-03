import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // AnimationController لمدة ثانيتين
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Tween للتحريك من اليمين (خارج الشاشة) إلى الوسط
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // الانتقال التلقائي بعد 3 ثواني للصفحة الرئيسية
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                SlideTransition(
                  position: _slideAnimation,
                  child: SizedBox(
                    height: 180,
                    child: Image.asset("images/logo3.png"),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "AMN",
                  style: TextStyle(
                    fontFamily: 'Bungee',
                    fontSize: 40,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
