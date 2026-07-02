import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_history_service.dart';

const String _hospitalStorageKey = 'hospital_insurance_hospitals';
const String _insuranceStorageKey = 'hospital_insurance_providers';

enum _ServiceCategory { hospital, insurance }

class HospitalInsuranceScreen extends StatefulWidget {
  const HospitalInsuranceScreen({super.key});

  @override
  State<HospitalInsuranceScreen> createState() =>
      _HospitalInsuranceScreenState();
}

class _HospitalInsuranceScreenState extends State<HospitalInsuranceScreen> {
  static const List<_ServiceInfo> _defaultHospitals = [
    _ServiceInfo(
      category: _ServiceCategory.hospital,
      name: 'El Salam Hospital',
      phone: '+201111111111',
      address: 'Cairo, Egypt',
      status: 'Open 24/7',
    ),
    _ServiceInfo(
      category: _ServiceCategory.hospital,
      name: 'Cleopatra Hospital',
      phone: '+201122233344',
      address: 'Cairo, Egypt',
      status: 'Open',
    ),
  ];

  static const List<_ServiceInfo> _defaultInsuranceProviders = [
    _ServiceInfo(
      category: _ServiceCategory.insurance,
      name: 'Misr Insurance',
      phone: '19800',
      address: 'Cairo, Egypt',
      status: 'Claims support',
    ),
    _ServiceInfo(
      category: _ServiceCategory.insurance,
      name: 'Allianz Egypt',
      phone: '19909',
      address: 'Cairo, Egypt',
      status: 'Road assistance',
    ),
  ];

  final List<_ServiceInfo> _hospitals = [];
  final List<_ServiceInfo> _insuranceProviders = [];

  _ServiceCategory _selectedCategory = _ServiceCategory.hospital;
  Position? _currentPosition;
  bool _loading = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _refreshLocation(showErrors: false);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHospitals = prefs.getStringList(_hospitalStorageKey);
    final savedInsurance = prefs.getStringList(_insuranceStorageKey);

    if (!mounted) return;
    setState(() {
      _hospitals
        ..clear()
        ..addAll(_decodeList(savedHospitals, _defaultHospitals));
      _insuranceProviders
        ..clear()
        ..addAll(_decodeList(savedInsurance, _defaultInsuranceProviders));
      _loading = false;
    });
  }

  List<_ServiceInfo> _decodeList(
    List<String>? encodedItems,
    List<_ServiceInfo> defaults,
  ) {
    if (encodedItems == null) return List<_ServiceInfo>.from(defaults);

    return encodedItems
        .map((item) {
          try {
            final json = jsonDecode(item);
            if (json is! Map<String, dynamic>) return null;
            final service = _ServiceInfo.fromJson(json);
            if (service.name.isEmpty || service.phone.isEmpty) return null;
            return service;
          } catch (_) {
            return null;
          }
        })
        .whereType<_ServiceInfo>()
        .toList();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _hospitalStorageKey,
      _hospitals.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await prefs.setStringList(
      _insuranceStorageKey,
      _insuranceProviders.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<Position?> _getCurrentPosition({bool showErrors = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (showErrors) _showMessage('Location services are disabled.');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (showErrors) {
        _showMessage('Location permission is required to find nearby places.');
      }
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _refreshLocation({bool showErrors = true}) async {
    if (_locating) return;

    setState(() => _locating = true);
    final position = await _getCurrentPosition(showErrors: showErrors);
    if (!mounted) return;

    setState(() {
      _currentPosition = position ?? _currentPosition;
      _locating = false;
    });
  }

  Future<void> _openNearbyMap() async {
    var position = _currentPosition;
    if (position == null) {
      position = await _getCurrentPosition();
      if (!mounted) return;
      if (position != null) setState(() => _currentPosition = position);
    }
    if (position == null) return;

    final query = _selectedCategory == _ServiceCategory.hospital
        ? 'hospitals near ${position.latitude},${position.longitude}'
        : 'insurance services near ${position.latitude},${position.longitude}';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    await _launchExternal(uri);
  }

  Future<void> _addItem() async {
    final result = await showDialog<_ServiceInfo>(
      context: context,
      builder: (context) => _AddServiceDialog(category: _selectedCategory),
    );
    if (result == null) return;

    setState(() {
      if (result.category == _ServiceCategory.hospital) {
        _hospitals.add(result);
      } else {
        _insuranceProviders.add(result);
      }
    });
    await _saveData();
    await EmergencyHistoryService.logEvent(
      type: result.category == _ServiceCategory.hospital
          ? 'hospital_added'
          : 'insurance_added',
      title: result.category == _ServiceCategory.hospital
          ? 'Hospital Added'
          : 'Insurance Provider Added',
      description: result.name,
      location: result.address,
      status: 'Completed',
    );

    if (!mounted) return;
    _showMessage('${result.name} added.');
  }

  Future<void> _callService(_ServiceInfo info) async {
    await EmergencyHistoryService.logEvent(
      type: info.category == _ServiceCategory.hospital
          ? 'hospital_call'
          : 'insurance_call',
      title: 'Calling ${info.name}',
      description: info.category == _ServiceCategory.hospital
          ? 'Hospital emergency call'
          : 'Insurance provider call',
      location: info.address,
      status: 'In Progress',
    );

    await _launchExternal(Uri(scheme: 'tel', path: info.phone));
  }

  Future<void> _openDirections(_ServiceInfo info) async {
    var position = _currentPosition;
    if (position == null) {
      position = await _getCurrentPosition(showErrors: false);
      if (!mounted) return;
      if (position != null) setState(() => _currentPosition = position);
    }

    final destination = info.address.isEmpty ? info.name : info.address;
    final queryParameters = <String, String>{
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    };

    if (position != null) {
      queryParameters['origin'] = '${position.latitude},${position.longitude}';
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', queryParameters);
    await EmergencyHistoryService.logEvent(
      type: info.category == _ServiceCategory.hospital
          ? 'hospital_directions'
          : 'insurance_directions',
      title: 'Directions Opened',
      description: info.name,
      location: destination,
      status: 'Completed',
    );
    await _launchExternal(uri);
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('Unable to open this action on your device.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to open this action on your device.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _selectedCategory == _ServiceCategory.hospital
        ? _hospitals
        : _insuranceProviders;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Hospital & Insurance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: _addItem,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _CategorySwitch(
                    selectedCategory: _selectedCategory,
                    onChanged: (category) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                  const SizedBox(height: 14),
                  _LiveMapPanel(
                    category: _selectedCategory,
                    position: _currentPosition,
                    locating: _locating,
                    onRefreshLocation: _refreshLocation,
                    onOpenMap: _openNearbyMap,
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < items.length; i++) ...[
                    _ServiceCard(
                      info: items[i],
                      onCall: () => _callService(items[i]),
                      onDirections: () => _openDirections(items[i]),
                    ),
                    if (i != items.length - 1) const SizedBox(height: 12),
                  ],
                  if (items.isEmpty) const _EmptyState(),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

class _ServiceInfo {
  final _ServiceCategory category;
  final String name;
  final String phone;
  final String address;
  final String status;

  const _ServiceInfo({
    required this.category,
    required this.name,
    required this.phone,
    required this.address,
    required this.status,
  });

  factory _ServiceInfo.fromJson(Map<String, dynamic> json) {
    return _ServiceInfo(
      category: json['category'] == 'insurance'
          ? _ServiceCategory.insurance
          : _ServiceCategory.hospital,
      name: (json['name'] ?? '').toString().trim(),
      phone: (json['phone'] ?? '').toString().trim(),
      address: (json['address'] ?? '').toString().trim(),
      status: (json['status'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category == _ServiceCategory.insurance
          ? 'insurance'
          : 'hospital',
      'name': name,
      'phone': phone,
      'address': address,
      'status': status,
    };
  }
}

class _CategorySwitch extends StatelessWidget {
  final _ServiceCategory selectedCategory;
  final ValueChanged<_ServiceCategory> onChanged;

  const _CategorySwitch({
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Hospitals',
            selected: selectedCategory == _ServiceCategory.hospital,
            onTap: () => onChanged(_ServiceCategory.hospital),
          ),
          _SegmentButton(
            label: 'Insurance',
            selected: selectedCategory == _ServiceCategory.insurance,
            onTap: () => onChanged(_ServiceCategory.insurance),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? Colors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveMapPanel extends StatelessWidget {
  final _ServiceCategory category;
  final Position? position;
  final bool locating;
  final VoidCallback onRefreshLocation;
  final VoidCallback onOpenMap;

  const _LiveMapPanel({
    required this.category,
    required this.position,
    required this.locating,
    required this.onRefreshLocation,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final title = category == _ServiceCategory.hospital
        ? 'Nearby Hospitals'
        : 'Nearby Insurance Services';
    final subtitle = position == null
        ? 'Use your location to open live nearby results.'
        : 'Current location: ${position!.latitude.toStringAsFixed(4)}, '
              '${position!.longitude.toStringAsFixed(4)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: locating ? null : onRefreshLocation,
                  icon: locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(locating ? 'Locating' : 'Use Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final _ServiceInfo info;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _ServiceCard({
    required this.info,
    required this.onCall,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final icon = info.category == _ServiceCategory.hospital
        ? Icons.local_hospital_outlined
        : Icons.shield_outlined;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  info.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info.status.isEmpty ? 'Saved location' : info.status,
            style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            info.address.isEmpty ? 'Address not specified' : info.address,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onCall,
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onDirections,
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Directions'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No saved entries yet. Tap + to add one.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _AddServiceDialog extends StatefulWidget {
  final _ServiceCategory category;

  const _AddServiceDialog({required this.category});

  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.category == _ServiceCategory.hospital
        ? 'Hospital'
        : 'Insurance';

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add $label', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(controller: _nameController, label: '$label Name'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _addressController,
              label: 'Address or Branch',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _statusController,
              label: widget.category == _ServiceCategory.hospital
                  ? 'Status (e.g. Open 24/7)'
                  : 'Details (e.g. Policy / Claims)',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
          onPressed: () {
            if (_nameController.text.trim().isEmpty ||
                _phoneController.text.trim().isEmpty) {
              return;
            }

            Navigator.pop(
              context,
              _ServiceInfo(
                category: widget.category,
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                status: _statusController.text.trim(),
              ),
            );
          },
          child: const Text('Add', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}
