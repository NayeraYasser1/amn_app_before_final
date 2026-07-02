import 'package:flutter/material.dart';
import 'package:amn_app/widgets/my_buttons.dart';

class PasswordChangedScreen extends StatelessWidget {
  const PasswordChangedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Success Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Title
              const Center(
                child: Text(
                  "Password changed",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Message
              const Center(
                child: Text(
                  "Your password has been changed successfully",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              
              // Back to login Button
              MyButton(
                color: const Color(0xFF1F1D1D),
                title: "Back to login",
                onPressed: () {
                  // Navigate back to login screen, clearing the stack
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    'login',
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

