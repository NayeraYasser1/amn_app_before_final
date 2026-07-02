import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amn_app/widgets/my_buttons.dart';
import 'verify_code_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState  createState()  => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    // Keep a leading '+' if present; remove other non-digits.
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }

  Future<void> _sendSmsCode() async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone.isEmpty) return;
    if (!phone.startsWith('+') || phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter phone in international format, e.g. +201234567890',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint(
            'ForgotPasswordScreen._sendSmsCode verificationFailed: ${e.code} ${e.message}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to send verification SMS. Please try again later.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        codeSent: (verificationId, forceResendingToken) {
          Navigator.pushNamed(
            context,
            'verify-code',
            arguments: VerifyCodeArgs.forgotPassword(
              phone: phone,
              verificationId: verificationId,
              resendToken: forceResendingToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

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
              const SizedBox(height: 20),
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Forgot password?",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Instructions
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Don't worry! It happens. Please enter the phone number associated with your account.",
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
              const SizedBox(height: 40),

              // Phone number Field
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Phone number",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "e.g. +201234567890",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Send code Button
              _isSending
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : MyButton(
                      color: const Color(0xFF1F1D1D),
                      title: "Send code",
                      onPressed: _sendSmsCode,
                    ),
              const SizedBox(height: 40),

              // Remember password text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Remember password? ",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Log in",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
