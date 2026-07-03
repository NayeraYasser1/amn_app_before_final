import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:amn_app/services/auth_service.dart';
import 'package:amn_app/utils/car_options.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen>  createState()  => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _countryController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _hospitalInsuranceController = TextEditingController();

  final _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _profileImageUrl;
  bool _isUploadingImage = false;
  bool _isUploadingDriverLicense = false;
  bool _isUploadingCarLicense = false;

  String? _selectedCarModel;
  String? _selectedCarColor;
  String? _driverLicenseUrl;
  String? _carLicenseUrl;

  static const int _plateMinLength = 3;
  static const int _plateMaxLength = 10;
  static final RegExp _plateAllowedPattern = RegExp(r'^[A-Z0-9-]+$');
  static final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

  static const List<String> _carModels = kCarModels;
  static const List<String> _carColors = kCarColors;

  // Dropdown options
  final List<String> _bloodTypes = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];
  final List<String> _countries = [
    'Spain',
    'United States',
    'United Kingdom',
    'France',
    'Germany',
    'Italy',
    'Canada',
    'Australia',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCarModel = _carModels[0];
    _selectedCarColor = _carColors[0];
    _loadUserData();
  }

  List<String> _carModelChoices() {
    final m = _selectedCarModel ?? _carModels[0];
    final list = List<String>.from(_carModels);
    if (m.isNotEmpty && m != _carModels[0] && !list.contains(m)) {
      list.add(m);
    }
    return list;
  }

  List<String> _carColorChoices() {
    final c = _selectedCarColor ?? _carColors[0];
    final list = List<String>.from(_carColors);
    if (c.isNotEmpty && c != _carColors[0] && !list.contains(c)) {
      list.add(c);
    }
    return list;
  }

  String _resolveCarModel(String? value) {
    if (value == null || value.isEmpty) return _carModels[0];
    if (_carModels.contains(value)) return value;
    return value;
  }

  String _resolveCarColor(String? value) {
    if (value == null || value.isEmpty) return _carColors[0];
    if (_carColors.contains(value)) return value;
    return value;
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // Bail if the user left Edit Profile while the read was in flight —
        // writing to disposed TextEditingControllers throws.
        if (!mounted) return;

        if (doc.exists) {
          final data = doc.data()!;
          final carMap = data['carDetails'];
          Map<String, dynamic>? car;
          if (carMap is Map<String, dynamic>) {
            car = carMap;
          } else if (carMap is Map) {
            car = Map<String, dynamic>.from(carMap);
          }

          String? first = data['firstName'] as String?;
          String? last = data['lastName'] as String?;
          if ((first == null || first.isEmpty) &&
              (last == null || last.isEmpty)) {
            final legacyName = data['name'] as String?;
            if (legacyName != null && legacyName.trim().isNotEmpty) {
              final parts = legacyName.trim().split(RegExp(r'\s+'));
              first = parts.first;
              last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            } else if (user.displayName != null &&
                user.displayName!.trim().isNotEmpty) {
              final parts = user.displayName!.trim().split(RegExp(r'\s+'));
              first = parts.first;
              last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            }
          }

          _firstNameController.text = first ?? '';
          _lastNameController.text = last ?? '';
          _emailController.text =
              (data['email'] as String?) ?? user.email ?? '';
          _phoneController.text = (data['phone'] as String?) ?? '';
          _plateNumberController.text = (car?['plateNumber'] as String?) ?? '';

          _selectedCarModel = _resolveCarModel(car?['model'] as String?);
          _selectedCarColor = _resolveCarColor(car?['color'] as String?);

          _driverLicenseUrl = data['driver_license_url'] as String?;
          _carLicenseUrl = data['car_license_url'] as String?;

          _bloodTypeController.text = data['bloodType'] ?? '';
          _dateOfBirthController.text = data['dateOfBirth'] ?? '';
          _countryController.text = data['country'] ?? '';
          _allergiesController.text = data['allergies'] ?? '';
          _hospitalInsuranceController.text =
              data['hospitalInsurance'] ?? '';

          _profileImageUrl =
              (data['profilePictureUrl'] as String?) ??
              (data['profileImageUrl'] as String?) ??
              user.photoURL;
        } else {
          _firstNameController.text = '';
          _lastNameController.text = '';
          _emailController.text = user.email ?? '';
          _phoneController.text = '';
          _plateNumberController.text = '';
          _selectedCarModel = _carModels[0];
          _selectedCarColor = _carColors[0];
          _bloodTypeController.text = '';
          _dateOfBirthController.text = '';
          _countryController.text = '';
          _allergiesController.text = '';
          _hospitalInsuranceController.text = '';
          _profileImageUrl = user.photoURL;
        }
      }
    } catch (e) {
      debugPrint('EditProfileScreen._loadUserData failed: $e');
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      // On a load failure, leave fields EMPTY. Never seed placeholder medical
      // data (blood type / allergies): the user could save it over their real
      // profile, and responders would then act on fabricated information.
      _firstNameController.text = '';
      _lastNameController.text = '';
      _emailController.text = user?.email ?? '';
      _phoneController.text = '';
      _plateNumberController.text = '';
      _selectedCarModel = _carModels[0];
      _selectedCarColor = _carColors[0];
      _bloodTypeController.text = '';
      _dateOfBirthController.text = '';
      _countryController.text = '';
      _allergiesController.text = '';
      _hospitalInsuranceController.text = '';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load your profile. Check your connection and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCarModel == _carModels[0]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a car model'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCarColor == _carColors[0]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a car color'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final plate = _plateNumberController.text.trim().toUpperCase();
    if (plate.length < _plateMinLength ||
        plate.length > _plateMaxLength ||
        !_plateAllowedPattern.hasMatch(plate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Plate number must be 3-10 characters (letters, numbers, or "-").',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !_e164Pattern.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone must be in international format (e.g. +201234567890).',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final first = _firstNameController.text.trim();
        final last = _lastNameController.text.trim();
        final email = _emailController.text.trim();
        final displayName = '$first $last'.trim();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'firstName': first,
          'lastName': last,
          'name': displayName.isEmpty ? FieldValue.delete() : displayName,
          'email': email,
          'phone': phone,
          'carDetails': {
            'model': _selectedCarModel,
            'plateNumber': plate,
            'color': _selectedCarColor,
          },
          'driver_license_url': _driverLicenseUrl ?? '',
          'car_license_url': _carLicenseUrl ?? '',
          'bloodType': _bloodTypeController.text.trim(),
          'dateOfBirth': _dateOfBirthController.text.trim(),
          'country': _countryController.text.trim(),
          'allergies': _allergiesController.text.trim(),
          'hospitalInsurance': _hospitalInsuranceController.text.trim(),
          'profilePictureUrl': _profileImageUrl,
          'profileImageUrl': _profileImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }

        if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
          await user.updatePhotoURL(_profileImageUrl!);
        }

        var successMessage = 'Profile saved successfully!';
        if (email.isNotEmpty && email != (user.email ?? '')) {
          try {
            await user.verifyBeforeUpdateEmail(email);
            successMessage =
                'Profile saved. Check your inbox to verify your new email.';
          } on FirebaseAuthException catch (e) {
            debugPrint(
              'EditProfileScreen email update: ${e.code} ${e.message}',
            );
            successMessage =
                'Profile saved. Email updated in app only: ${e.message ?? e.code}';
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Writes image URLs to Firestore right after Storage upload so data is not
  /// lost if the user leaves without tapping Save.
  Future<void> _persistMediaToFirestore({
    String? profilePictureUrl,
    String? driverLicenseUrl,
    String? carLicenseUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = <String, dynamic>{
      'userId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
      data['profilePictureUrl'] = profilePictureUrl;
      data['profileImageUrl'] = profilePictureUrl;
    }
    if (driverLicenseUrl != null && driverLicenseUrl.isNotEmpty) {
      data['driver_license_url'] = driverLicenseUrl;
    }
    if (carLicenseUrl != null && carLicenseUrl.isNotEmpty) {
      data['car_license_url'] = carLicenseUrl;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  Future<String?> _uploadLicenseFile(File file, String licenseType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final ext = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';
    final fileName =
        '$licenseType/${user.uid}/${licenseType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    await ref.putFile(file, SettableMetadata(contentType: mime));
    return ref.getDownloadURL();
  }

  Future<void> _replaceLicense({required bool driver}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() {
      if (driver) {
        _isUploadingDriverLicense = true;
      } else {
        _isUploadingCarLicense = true;
      }
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      final url = await _uploadLicenseFile(
        File(picked.path),
        driver ? 'driver_license' : 'car_license',
      );
      if (url == null || url.isEmpty) return;

      await _persistMediaToFirestore(
        driverLicenseUrl: driver ? url : null,
        carLicenseUrl: driver ? null : url,
      );

      if (!mounted) return;
      setState(() {
        if (driver) {
          _driverLicenseUrl = url;
        } else {
          _carLicenseUrl = url;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              driver
                  ? 'Driver license uploaded and saved to Firebase.'
                  : 'Car license uploaded and saved to Firebase.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDriverLicense = false;
          _isUploadingCarLicense = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 5, 5),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploadingImage = true);
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final file = File(pickedFile.path);

      final path =
          'profile_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);

      await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': user.uid},
        ),
      );
      final downloadUrl = await ref.getDownloadURL();

      await _persistMediaToFirestore(profilePictureUrl: downloadUrl);
      await user.updatePhotoURL(downloadUrl);

      if (!mounted) return;
      setState(() => _profileImageUrl = downloadUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo uploaded and saved to Firebase Storage & Firestore.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _plateNumberController.dispose();
    _bloodTypeController.dispose();
    _dateOfBirthController.dispose();
    _countryController.dispose();
    _allergiesController.dispose();
    _hospitalInsuranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_outlined, color: Colors.white),
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    // Profile Picture
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                          ),
                          child: _isUploadingImage
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : _profileImageUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    _profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey[400],
                                        ),
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingImage
                                ? null
                                : _pickAndUploadImage,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[700],
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _buildSectionTitle('Account'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'First name',
                      controller: _firstNameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your first name';
                        }
                        if (value.trim().length < 2) {
                          return 'At least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Last name',
                      controller: _lastNameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your last name';
                        }
                        if (value.trim().length < 2) {
                          return 'At least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(
                          r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Phone (international)',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      hintText: '+201234567890',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!_e164Pattern.hasMatch(value.trim())) {
                          return 'Use international format starting with +';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Vehicle'),
                    const SizedBox(height: 12),
                    _buildCarModelDropdown(),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Plate number',
                      controller: _plateNumberController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9-]'),
                        ),
                        LengthLimitingTextInputFormatter(_plateMaxLength),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter plate number';
                        }
                        final p = value.trim().toUpperCase();
                        if (p.length < _plateMinLength ||
                            p.length > _plateMaxLength ||
                            !_plateAllowedPattern.hasMatch(p)) {
                          return '3-10 chars: letters, numbers, or "-"';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildCarColorDropdown(),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Licenses'),
                    const SizedBox(height: 12),
                    _buildLicenseCard(
                      title: 'Driver license',
                      url: _driverLicenseUrl,
                      busy: _isUploadingDriverLicense,
                      onReplace: () => _replaceLicense(driver: true),
                    ),
                    const SizedBox(height: 12),
                    _buildLicenseCard(
                      title: 'Car license',
                      url: _carLicenseUrl,
                      busy: _isUploadingCarLicense,
                      onReplace: () => _replaceLicense(driver: false),
                    ),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Medical & insurance'),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Blood Type',
                      controller: _bloodTypeController,
                      items: _bloodTypes,
                    ),
                    const SizedBox(height: 20),
                    // Date of Birth Field
                    _buildDateField(
                      label: 'Date of Birth',
                      controller: _dateOfBirthController,
                    ),
                    const SizedBox(height: 20),
                    // Country/Region Field
                    _buildDropdownField(
                      label: 'Country/Region',
                      controller: _countryController,
                      items: _countries,
                    ),
                    const SizedBox(height: 20),
                    // Allergies Field
                    _buildDropdownField(
                      label: 'Allergies',
                      controller: _allergiesController,
                      items: ['Penicillin', 'None', 'Peanuts', 'Dust', 'Other'],
                    ),
                    const SizedBox(height: 20),
                    // Hospital Insurance Field
                    _buildTextField(
                      label: 'Hospital Insurance',
                      controller: _hospitalInsuranceController,
                    ),
                    const SizedBox(height: 40),
                    // Logout Button
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('login', (route) => false);
        }
      } catch (e) {
        debugPrint('EditProfileScreen._logout failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to log out. Please try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Log Out',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCarModelDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Car model',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCarModel,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: _carModelChoices()
                  .map(
                    (v) => DropdownMenuItem<String>(
                      value: v,
                      child: Text(
                        v,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedCarModel = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarColorDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Car color',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCarColor,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: _carColorChoices()
                  .map(
                    (v) => DropdownMenuItem<String>(
                      value: v,
                      child: Text(
                        v,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedCarColor = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseCard({
    required String title,
    required String? url,
    required bool busy,
    required VoidCallback onReplace,
  }) {
    final hasUrl = url != null && url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasUrl ? 'Stored in Firebase (preview below)' : 'No photo yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          if (hasUrl) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[800],
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReplace,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(hasUrl ? 'Replace photo' : 'Add photo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    TextDecoration? textDecoration,
    TextInputType? keyboardType,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey[400],
            decoration: textDecoration,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.grey[900],
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                      return ListTile(
                        title: Text(
                          item,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          setState(() {
                            controller.text = item;
                          });
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  controller.text.isEmpty ? 'Select $label' : controller.text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  controller.text.isEmpty ? 'Select date' : controller.text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
