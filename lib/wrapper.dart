import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/login_screen.dart';

class Wrapper extends StatelessWidget {
  final void Function(Locale)? onLocaleChanged;

  const Wrapper({super.key, this.onLocaleChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // while waiting for the first value we show a spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // if we have a user object the user is signed in
        if (snapshot.hasData && snapshot.data != null) {
          // user is authenticated -> go to home page
          return HomePage(onLocaleChanged: onLocaleChanged ?? (_) {});
        }

        // otherwise show the login screen
        return const LoginScreen();
      },
    );
  }
}
