import 'package:flutter/material.dart';
import 'package:amn_app/services/auth_service.dart';
import 'package:amn_app/services/password_validator.dart';
import 'package:amn_app/widgets/my_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordArgs {
  final bool isForgotPassword;

  const ResetPasswordArgs.forgotPassword() : isForgotPassword = true;
  const ResetPasswordArgs.signup() : isForgotPassword = false;
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _authService = AuthService();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPasswordInFirebase() async {
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPassword.isEmpty || confirm.isEmpty || newPassword != confirm) {
      if (newPassword != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final passwordValidation = PasswordValidator.validate(newPassword);
    if (!passwordValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passwordValidation.message),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'Not signed in.',
        );
      }
      await user.updatePassword(newPassword);
      await _authService.signOut();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        'password-changed',
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'ResetPasswordScreen._resetPasswordInFirebase failed: ${e.code} ${e.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to reset password. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint(
        'ResetPasswordScreen._resetPasswordInFirebase unexpected error: $e',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to reset password. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final resetArgs = args is ResetPasswordArgs
        ? args
        : const ResetPasswordArgs.signup();

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
                  "Reset password",
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
                  "Please type something you'll remember",
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
              const SizedBox(height: 40),

              // New Password Field
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "New password",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "8-64 chars, Aa1@",
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm New Password Field
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Confirm new password",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "repeat password",
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Reset password Button
              _isSaving
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : MyButton(
                      color: const Color(0xFF1F1D1D),
                      title: resetArgs.isForgotPassword
                          ? "Reset password"
                          : "Continue",
                      onPressed: resetArgs.isForgotPassword
                          ? _resetPasswordInFirebase
                          : () => Navigator.pushNamed(
                              context,
                              'password-changed',
                            ),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
