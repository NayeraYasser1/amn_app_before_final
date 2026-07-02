import 'package:flutter/material.dart';
import 'package:amn_app/widgets/my_buttons.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:amn_app/services/cloudinary_service.dart';
import 'dart:io';
import 'reset_password_screen.dart';

enum VerifyFlow { signup, forgotPassword }

class VerifyCodeArgs {
  final VerifyFlow flow;
  final String phone;
  final String verificationId;
  final int? resendToken;

  // Signup only
  final String? email;
  final String? password;
  final XFile? driverLicenseFile;
  final XFile? carLicenseFile;
  final String? firstName;
  final String? lastName;
  final File? profilePicture;
  final String? selectedCarModel;
  final String? plateNumber;
  final String? selectedCarColor;

  const VerifyCodeArgs._({
    required this.flow,
    required this.phone,
    required this.verificationId,
    required this.resendToken,
    this.email,
    this.password,
    this.driverLicenseFile,
    this.carLicenseFile,
    this.firstName,
    this.lastName,
    this.profilePicture,
    this.selectedCarModel,
    this.plateNumber,
    this.selectedCarColor,
  });

  const VerifyCodeArgs.signup({
    required String phone,
    required String verificationId,
    int? resendToken,
    required String email,
    required String password,
    required XFile driverLicenseFile,
    required XFile carLicenseFile,
    String? firstName,
    String? lastName,
    File? profilePicture,
    String? selectedCarModel,
    String? plateNumber,
    String? selectedCarColor,
  }) : this._(
         flow: VerifyFlow.signup,
         phone: phone,
         verificationId: verificationId,
         resendToken: resendToken,
         email: email,
         password: password,
         driverLicenseFile: driverLicenseFile,
         carLicenseFile: carLicenseFile,
         firstName: firstName,
         lastName: lastName,
         profilePicture: profilePicture,
         selectedCarModel: selectedCarModel,
         plateNumber: plateNumber,
         selectedCarColor: selectedCarColor,
       );

  const VerifyCodeArgs.forgotPassword({
    required String phone,
    String verificationId = '',
    int? resendToken,
  }) : this._(
         flow: VerifyFlow.forgotPassword,
         phone: phone,
         verificationId: verificationId,
         resendToken: resendToken,
       );
}

class VerifyCodeScreen extends StatefulWidget {
  final VerifyCodeArgs args;

  const VerifyCodeScreen({super.key, required this.args});

  @override
  _VerifyCodeScreenState createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  String _verificationId = '';
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.args.verificationId;
    _resendToken = widget.args.resendToken;
    _startTimer();
    // Auto-focus first field
    _focusNodes[0].requestFocus();
  }

  void _startTimer() {
    _canResend = false;
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < _controllers.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<String?> _uploadImageToCloudinary(XFile file, String imageType) async {
    try {
      final imageFile = File(file.path);
      final url = imageType == 'profile'
          ? await CloudinaryService.uploadProfileImage(imageFile)
          : await CloudinaryService.uploadLicenseImage(imageFile);
      return url;
    } catch (e) {
      debugPrint('Error uploading $imageType image: $e');
      rethrow;
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _canResend = false;
      _secondsRemaining = 60;
    });
    _startTimer();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.args.phone,
        forceResendingToken: _resendToken,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint(
            'VerifyCodeScreen._resendCode failed: ${e.code} ${e.message}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to resend the verification code. Please try again later.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        codeSent: (verificationId, forceResendingToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = forceResendingToken;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Code resent successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      debugPrint('VerifyCodeScreen._resendCode unexpected error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to resend the verification code. Please try again later.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verify() async {
    final smsCode = _getCode();
    if (smsCode.length != _controllers.length) return;
    if (_verificationId.isEmpty) return;

    setState(() => _isVerifying = true);
    try {
      final phoneCred = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        phoneCred,
      );
      final user = userCred.user;
      if (user == null) {
        throw Exception('No user after verification.');
      }

      if (widget.args.flow == VerifyFlow.signup) {
        final email = widget.args.email!;
        final password = widget.args.password!;

        try {
          final emailCred = EmailAuthProvider.credential(
            email: email.trim(),
            password: password,
          );
          await user.linkWithCredential(emailCred);
        } on FirebaseAuthException catch (e) {
          // Ignore provider already linked, otherwise rethrow.
          if (e.code != 'provider-already-linked') rethrow;
        }

        // Upload licenses to Cloudinary
        String? driverUrl;
        String? carUrl;

        try {
          driverUrl = await _uploadImageToCloudinary(
            widget.args.driverLicenseFile!,
            'license',
          );
        } catch (e) {
          debugPrint(
            'VerifyCodeScreen._verify: Driver license upload failed: $e',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Driver license upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        try {
          carUrl = await _uploadImageToCloudinary(
            widget.args.carLicenseFile!,
            'license',
          );
        } catch (e) {
          debugPrint('VerifyCodeScreen._verify: Car license upload failed: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Car license upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Upload profile picture to Cloudinary if provided (optional)
        String? profilePictureUrl;
        if (widget.args.profilePicture != null) {
          try {
            final imageFile = widget.args.profilePicture!;
            profilePictureUrl = await CloudinaryService.uploadProfileImage(
              File(imageFile.path),
            );
          } catch (e) {
            debugPrint(
              'VerifyCodeScreen._verify: Profile picture upload failed: $e',
            );
            // Continue even if profile picture fails
          }
        }

        // Create car details

        // Create user profile (toMap writes profilePictureUrl + profileImageUrl when set)

        // Update Firebase Authentication user profile
        final displayName =
            '${widget.args.firstName ?? ''} ${widget.args.lastName ?? ''}'
                .trim();
        if (displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
        if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
          await user.updatePhotoURL(profilePictureUrl);
        }

        // Save full profile + signup media URLs to Firestore
        // Store Cloudinary URLs with complete user data
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'firstName': widget.args.firstName,
          'lastName': widget.args.lastName,
          'email': email.trim(),
          'phone': widget.args.phone,
          'phone_verified': true,
          'profileImage': profilePictureUrl, // Cloudinary URL
          'licenseImage': driverUrl, // Cloudinary URL (driver license)
          'carLicenseImage': carUrl, // Cloudinary URL (car license)
          'carDetails': {
            'model': widget.args.selectedCarModel,
            'plateNumber': widget.args.plateNumber,
            'color': widget.args.selectedCarColor,
          },
          'profilePictureUrl': profilePictureUrl, // For compatibility
          // ignore: equal_keys_in_map
          'carDetails': {
            'model': widget.args.selectedCarModel,
            'plateNumber': widget.args.plateNumber,
            'color': widget.args.selectedCarColor,
          },
          'driver_license_url': driverUrl,
          'car_license_url': carUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified. Account created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, 'home', (route) => false);
        return;
      }

      // Forgot password (Firebase-only): after OTP, user is signed in -> allow updating password.
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        'reset-password',
        arguments: const ResetPasswordArgs.forgotPassword(),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'VerifyCodeScreen._verify FirebaseAuthException: ${e.code} ${e.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('VerifyCodeScreen._verify unexpected error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
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
                  "Verify your phone",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Instructions
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "We've sent a code to ${widget.args.phone}",
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
              const SizedBox(height: 40),

              // Code Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_controllers.length, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        _onCodeChanged(index, value);
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),

              // Verify Button
              _isVerifying
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : MyButton(
                      color: const Color(0xFF1F1D1D),
                      title: "Verify",
                      onPressed: _verify,
                    ),
              const SizedBox(height: 20),

              // Resend code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Send code again ",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  if (!_canResend)
                    Text(
                      "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        _resendCode();
                      },
                      child: const Text(
                        "Resend",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),

              // Numeric Keypad
              _buildNumericKeypad(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 60, height: 60),
            _buildKeypadButton('0'),
            _buildKeypadButton('*', isBackspace: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String text, {bool isBackspace = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isBackspace) {
            // Find the last filled field and clear it
            for (int i = _controllers.length - 1; i >= 0; i--) {
              if (_controllers[i].text.isNotEmpty) {
                _controllers[i].clear();
                if (i > 0) {
                  _focusNodes[i - 1].requestFocus();
                }
                break;
              }
            }
          } else {
            // Find the first empty field and fill it
            for (int i = 0; i < _controllers.length; i++) {
              if (_controllers[i].text.isEmpty) {
                _controllers[i].text = text;
                _onCodeChanged(i, text);
                break;
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: isBackspace
              ? const Icon(Icons.backspace, color: Colors.white, size: 24)
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
