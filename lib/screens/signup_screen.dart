import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:amn_app/services/password_validator.dart';
import 'package:amn_app/widgets/my_buttons.dart';
import 'verify_code_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  final bool _uploadingImage = false;
  String _selectedCountryCode = '+20';

  static const int _phoneMinDigits = 8;
  static const int _phoneMaxDigits = 12;
  static const int _plateMinLength = 3;
  static const int _plateMaxLength = 4;
  static const int _maxLicenseSizeBytes = 8 * 1024 * 1024;
  static const List<String> _allowedLicenseExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static final RegExp _plateAllowedPattern = RegExp(r'^[A-Z0-9-]+$');
  static final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

  // License file variables
  XFile? _driverLicenseFile;
  XFile? _carLicenseFile;

  // Profile picture variable
  File? _profilePicture;

  // Car details variables
  String? _selectedCarModel;
  String? _selectedCarColor;

  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _countryCodes = const [
    '+20',
    '+1',
    '+44',
    '+971',
    '+966',
    '+49',
    '+33',
  ];

  // Car model options
  static const List<String> carModels = [
    'Select Car Model',
    'Toyota',
    'Honda',
    'BMW',
    'Mercedes-Benz',
    'Ford',
    'Chevrolet',
    'Volkswagen',
    'Audi',
    'Mazda',
    'Nissan',
    'Hyundai',
    'Kia',
    'Renault',
    'Peugeot',
    'Other',
  ];

  // Car color options
  static const List<String> carColors = [
    'Select Car Color',
    'Black',
    'White',
    'Silver',
    'Gray',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Orange',
    'Brown',
    'Gold',
    'Purple',
    'Pink',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCarModel = carModels[0];
    _selectedCarColor = carColors[0];
  }

  String _normalizedPlateNumber() {
    return _plateNumberController.text.trim().toUpperCase();
  }

  String _normalizedPhoneDigits() {
    return _phoneController.text.replaceAll(RegExp(r'\D'), '');
  }

  String _fullPhoneNumber() {
    return '$_selectedCountryCode${_normalizedPhoneDigits()}';
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (image) => completer.complete(image));
      return await completer.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _validateLicenseFile(XFile file) async {
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';

    if (!_allowedLicenseExtensions.contains(extension)) {
      return 'Unsupported file type. Please upload JPG, PNG, or WEBP.';
    }

    final fileSize = await file.length();
    if (fileSize <= 0 || fileSize > _maxLicenseSizeBytes) {
      return 'License image must be smaller than 8MB.';
    }

    final bytes = await file.readAsBytes();
    final image = await _decodeImage(bytes);
    if (image == null) {
      return 'Could not read image. Please upload a clear license photo.';
    }

    if (image.width < 500 || image.height < 300) {
      return 'Image resolution is too low. Please upload a clearer photo.';
    }

    final aspectRatio = image.width / image.height;
    if (aspectRatio < 1.2 || aspectRatio > 2.3) {
      return 'Image does not look like an ID/license card. Please retake it.';
    }

    return null;
  }

  Future<void> _pickLicenseImage({
    required ImageSource source,
    required bool isDriverLicense,
  }) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (image == null) return;

    final validationError = await _validateLicenseFile(image);
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      if (isDriverLicense) {
        _driverLicenseFile = image;
      } else {
        _carLicenseFile = image;
      }
    });
  }

  // Method to pick driver license image
  Future<void> _pickDriverLicense() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.grey[900],
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Take from Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _pickLicenseImage(
                  source: ImageSource.camera,
                  isDriverLicense: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _pickLicenseImage(
                  source: ImageSource.gallery,
                  isDriverLicense: true,
                );
              },
            ),
            if (_driverLicenseFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _driverLicenseFile = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // Method to pick car license image
  Future<void> _pickCarLicense() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.grey[900],
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Take from Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _pickLicenseImage(
                  source: ImageSource.camera,
                  isDriverLicense: false,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _pickLicenseImage(
                  source: ImageSource.gallery,
                  isDriverLicense: false,
                );
              },
            ),
            if (_carLicenseFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _carLicenseFile = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // Method to pick profile picture
  Future<void> _pickProfilePicture() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.grey[900],
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Take from Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _profilePicture = File(image.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _profilePicture = File(image.path);
                  });
                }
              },
            ),
            if (_profilePicture != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profilePicture = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all fields correctly. Check for validation errors.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate license documents
    if (_driverLicenseFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your driver license'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_carLicenseFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your car license'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passwords do not match. Please make sure both password fields are identical.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final passwordValidation = PasswordValidator.validate(
      _passwordController.text,
    );
    if (!passwordValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passwordValidation.message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate profile fields
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your first name'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your last name'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedCarModel == carModels[0]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a car model'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_plateNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your plate number'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedCarColor == carColors[0]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a car color'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final plateNumber = _normalizedPlateNumber();
    if (plateNumber.length < _plateMinLength ||
        plateNumber.length > _plateMaxLength ||
        !_plateAllowedPattern.hasMatch(plateNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Plate number must be 3-10 chars using letters, numbers, or "-".',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final phoneDigits = _normalizedPhoneDigits();
    if (phoneDigits.length < _phoneMinDigits ||
        phoneDigits.length > _phoneMaxDigits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be between 8 and 12 digits.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final phone = _fullPhoneNumber();
    if (!_e164Pattern.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid phone number with the selected country code.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint(
            'SignUpScreen._signUp verificationFailed: ${e.code} ${e.message}',
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
          // The SMS dispatch can arrive seconds later; if the user left the
          // screen, the context is deactivated and pushNamed would throw.
          if (!mounted) return;
          Navigator.pushNamed(
            context,
            'verify-code',
            arguments: VerifyCodeArgs.signup(
              phone: phone,
              verificationId: verificationId,
              resendToken: forceResendingToken,
              email: _emailController.text.trim(),
              password: _passwordController.text,
              driverLicenseFile: _driverLicenseFile!,
              carLicenseFile: _carLicenseFile!,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              profilePicture: _profilePicture,
              selectedCarModel: _selectedCarModel!,
              plateNumber: plateNumber,
              selectedCarColor: _selectedCarColor!,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Title
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Sign up",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Email Field
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Email",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.black),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "example@gmail.com",
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    errorStyle: const TextStyle(color: Colors.red),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Phone number field
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Add phone number",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          isExpanded: true,
                          items: _countryCodes
                              .map(
                                (code) => DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(code),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedCountryCode = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.black),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_phoneMaxDigits),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < _phoneMinDigits ||
                              digits.length > _phoneMaxDigits) {
                            return 'Phone must be 8-12 digits';
                          }
                          final fullPhone = '$_selectedCountryCode$digits';
                          if (!_e164Pattern.hasMatch(fullPhone)) {
                            return 'Invalid phone number format';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: "Phone number",
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          errorStyle: const TextStyle(color: Colors.red),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Create Password Field
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Create a password",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.black),
                  validator: (value) {
                    final result = PasswordValidator.validate(value);
                    return result.isValid ? null : result.message;
                  },
                  decoration: InputDecoration(
                    hintText: "8-64 chars, Aa1@",
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    errorStyle: const TextStyle(color: Colors.red),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Confirm Password Field
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Confirm password",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(color: Colors.black),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "repeat password",
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    errorStyle: const TextStyle(color: Colors.red),
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

                // Profile Section Header
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Profile Information",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Profile Picture Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Profile Picture (Optional)",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _uploadingImage ? null : _pickProfilePicture,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _profilePicture != null
                            ? Colors.green
                            : Colors.grey[700]!,
                        width: 2,
                      ),
                    ),
                    child: _uploadingImage
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : _profilePicture != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _profilePicture!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 35,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to select profile picture',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // First Name Field
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "First Name *",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _firstNameController,
                  style: const TextStyle(color: Colors.black),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your first name';
                    }
                    if (value.length < 2) {
                      return 'First name must be at least 2 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "Enter your first name",
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
                const SizedBox(height: 16),

                // Last Name Field
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Last Name *",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _lastNameController,
                  style: const TextStyle(color: Colors.black),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    if (value.length < 2) {
                      return 'Last name must be at least 2 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "Enter your last name",
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
                const SizedBox(height: 24),

                // Car Details Section Header
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Car Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Car Model Dropdown
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Car Model *",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCarModel,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: carModels.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            value,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != carModels[0]) {
                        setState(() {
                          _selectedCarModel = newValue;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Plate Number Field
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Plate Number *",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _plateNumberController,
                  style: const TextStyle(color: Colors.black),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                    LengthLimitingTextInputFormatter(_plateMaxLength),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your plate number';
                    }
                    final plate = value.trim().toUpperCase();
                    if (plate.length < _plateMinLength ||
                        plate.length > _plateMaxLength) {
                      return 'Plate number must be 3-10 characters';
                    }
                    if (!_plateAllowedPattern.hasMatch(plate)) {
                      return 'Only letters, numbers, and "-" are allowed';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "Enter your plate number",
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
                const SizedBox(height: 16),

                // Car Color Dropdown
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Car Color *",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCarColor,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: carColors.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            value,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != carColors[0]) {
                        setState(() {
                          _selectedCarColor = newValue;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // Driver License Upload Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Upload Driver License",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDriverLicense,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _driverLicenseFile != null
                          ? Colors.green[900]
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _driverLicenseFile != null
                            ? Colors.green
                            : Colors.grey[700]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverLicenseFile != null
                                  ? 'Driver License Selected'
                                  : 'Select Driver License',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_driverLicenseFile != null)
                              Text(
                                _driverLicenseFile!.name,
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        Icon(
                          _driverLicenseFile != null
                              ? Icons.check_circle
                              : Icons.cloud_upload,
                          color: _driverLicenseFile != null
                              ? Colors.green
                              : Colors.grey[400],
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Car License Upload Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Upload Car License",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickCarLicense,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _carLicenseFile != null
                          ? Colors.green[900]
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _carLicenseFile != null
                            ? Colors.green
                            : Colors.grey[700]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _carLicenseFile != null
                                  ? 'Car License Selected'
                                  : 'Select Car License',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_carLicenseFile != null)
                              Text(
                                _carLicenseFile!.name,
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        Icon(
                          _carLicenseFile != null
                              ? Icons.check_circle
                              : Icons.cloud_upload,
                          color: _carLicenseFile != null
                              ? Colors.green
                              : Colors.grey[400],
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Sign up Button
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : MyButton(
                        color: const Color(0xFF1F1D1D),
                        title: "Sign up",
                        onPressed: _signUp,
                      ),
                const SizedBox(height: 40),

                // Already have account text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, 'login');
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
      ),
    );
  }
}
