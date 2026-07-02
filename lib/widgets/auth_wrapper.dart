import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:amn_app/screens/home_page.dart';
import 'package:amn_app/screens/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  final void Function(Locale)? onLocaleChanged;

  const AuthWrapper({super.key, this.onLocaleChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return HomePage(onLocaleChanged: onLocaleChanged ?? (_) {});
      },
    );
  }
}
