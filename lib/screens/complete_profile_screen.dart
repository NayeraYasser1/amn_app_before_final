import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:amn_app/services/user_service.dart';
import 'package:amn_app/models/user_profile.dart';
import 'package:amn_app/widgets/my_buttons.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String email;
  final String userId;

  const CompleteProfileScreen({
    super.key,
    required this.email,
    required this.userId,
  });

  @override
  State<CompleteProfileScreen>   createState()  => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _profilePicture;
  String? _selectedCarModel;
  String? _selectedCarColor;
  bool _isLoading = false;
  bool _uploadingImage = false;

  final ImagePicker _imagePicker = ImagePicker();
  final UserService _userService = UserService();

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

  /// Pick profile picture from gallery or camera
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

  /// Validate form and save profile to Firebase
  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
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

    setState(() => _isLoading = true);

    try {
      // Step 1: Upload profile picture if selected
      String? profilePictureUrl;
      if (_profilePicture != null) {
        setState(() => _uploadingImage = true);
        profilePictureUrl = await _userService.uploadProfilePicture(
          _profilePicture!,
        );
        setState(() => _uploadingImage = false);
      }

      // Step 2: Create car details
      final carDetails = CarDetails(
        model: _selectedCarModel,
        plateNumber: _plateNumberController.text.trim(),
        color: _selectedCarColor,
      );

      // Step 3: Create user profile in Firestore
      final userProfile = UserProfile(
        userId: widget.userId,
        email: widget.email,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        profilePictureUrl: profilePictureUrl,
        carDetails: carDetails,
      );

      await _userService.updateUserProfile(userProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to home or next screen
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, 'home');
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint(
        'CompleteProfileScreen._completeProfile auth error: ${e.code}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('CompleteProfileScreen._completeProfile error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadingImage = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    height: 150,
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
                                size: 40,
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
                const SizedBox(height: 24),

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
                  inputFormatters: [],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your plate number';
                    }
                    if (value.length < 3) {
                      return 'Plate number must be at least 3 characters';
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
                const SizedBox(height: 32),

                // Complete Profile Button
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : MyButton(
                        color: const Color(0xFF1F1D1D),
                        title: "Complete Profile",
                        onPressed: _completeProfile,
                      ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
