import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:amn_app/screens/login_screen.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard._({required this.child});

  static Widget protect({required Widget child}) {
    return AuthGuard._(child: child);
  }

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

        // User is authenticated and phone verified - allow access
        return child;
      },
    );
  }
}
