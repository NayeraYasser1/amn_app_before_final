import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class CarInformationScreen extends StatefulWidget {
  const CarInformationScreen({super.key});

  @override
  State<CarInformationScreen>  createState()  => _CarInformationScreenState();
}

class _CarInformationScreenState extends State<CarInformationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _carModelController = TextEditingController();
  final _carNameController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carLicenseController = TextEditingController();

  String? _licenseImagePath;

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCarData();
  }

  Future<void> _loadCarData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final car = (data['carInfo'] as Map<String, dynamic>?) ?? {};
          _carModelController.text = car['model'] ?? '';
          _carNameController.text = car['name'] ?? '';
          _carNumberController.text = car['number'] ?? '';
          _carColorController.text = car['color'] ?? '';
          _carLicenseController.text = car['license'] ?? '';
          _licenseImagePath = car['licenseImagePath'] as String?;
          if (_licenseImagePath != null && _licenseImagePath!.isNotEmpty) {
            // License image loaded
          }
        } else {
          _setDefaultValues();
        }
      } else {
        _setDefaultValues();
      }
    } catch (_) {
      _setDefaultValues();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setDefaultValues() {
    _carModelController.text = '';
    _carNameController.text = '';
    _carNumberController.text = '';
    _carColorController.text = '';
    _carLicenseController.text = '';
    _licenseImagePath = null;
  }

  Future<void> _saveCarInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'carInfo': {
            'model': _carModelController.text.trim(),
            'name': _carNameController.text.trim(),
            'number': _carNumberController.text.trim(),
            'color': _carColorController.text.trim(),
            'license': _carLicenseController.text.trim(),
            'licenseImagePath': _licenseImagePath ?? '',
          },
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Car information saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving car information: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _carModelController.dispose();
    _carNameController.dispose();
    _carNumberController.dispose();
    _carColorController.dispose();
    _carLicenseController.dispose();
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
          'Car information',
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
            onPressed: _isSaving ? null : _saveCarInfo,
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
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                      ),
                      child: Icon(
                        Icons.directions_car,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildTextField(
                      label: 'Car model',
                      controller: _carModelController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Car name',
                      controller: _carNameController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Car number',
                      controller: _carNumberController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Car color',
                      controller: _carColorController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Car license',
                      controller: _carLicenseController,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _showLicenseImagePicker,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_licenseImagePath != null &&
                        _licenseImagePath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_licenseImagePath!),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          // The cache path may be gone (OS cleanup / reinstall /
                          // another device); show a placeholder, don't crash.
                          errorBuilder: (context, error, stack) => Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'License photo unavailable — please add it again',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    Widget? suffixIcon,
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
          style: const TextStyle(color: Colors.white),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label'.toLowerCase();
            }
            return null;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[800],
            suffixIcon: suffixIcon,
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

  Future<void> _showLicenseImagePicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.white),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickLicenseImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text(
                  'Upload from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickLicenseImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickLicenseImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked != null) {
      setState(() {
        _licenseImagePath = picked.path;
      });
    }
  }
}
