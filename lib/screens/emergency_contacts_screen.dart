import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';
import '../services/emergency_history_service.dart';
import 'add_emergency_contact_screen.dart';
import 'calling_contact_screen.dart';

const String _contactsStorageKey = 'emergency_contacts';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<EmergencyContact> _defaultContacts = [
    EmergencyContact(
      name: 'Amir amour',
      phoneNumber: '01134658497',
      relationship: 'Friend',
    ),
    EmergencyContact(
      name: 'samir shafor',
      phoneNumber: '02345698741',
      relationship: 'Brother',
    ),
    EmergencyContact(
      name: 'hussin sandour',
      phoneNumber: '0234591873',
      relationship: 'Cousin',
    ),
    EmergencyContact(
      name: 'shady morour',
      phoneNumber: '01934658497',
      relationship: 'Friend',
    ),
    EmergencyContact(
      name: 'Nayera nemo',
      phoneNumber: '01124658464',
      relationship: 'Sister',
    ),
  ];

  final List<EmergencyContact> _contacts = [];
  String _searchQuery = '';
  bool _loadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedContacts = prefs.getStringList(_contactsStorageKey);

    final contacts = encodedContacts == null
        ? List<EmergencyContact>.from(_defaultContacts)
        : encodedContacts
              .map(_decodeContact)
              .whereType<EmergencyContact>()
              .toList();

    if (!mounted) return;
    setState(() {
      _contacts
        ..clear()
        ..addAll(contacts);
      _loadingContacts = false;
    });
  }

  EmergencyContact? _decodeContact(String encodedContact) {
    try {
      final json = jsonDecode(encodedContact);
      if (json is! Map<String, dynamic>) return null;
      final contact = EmergencyContact.fromJson(json);
      if (contact.name.trim().isEmpty || contact.phoneNumber.trim().isEmpty) {
        return null;
      }
      return contact;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _contactsStorageKey,
      _contacts.map((contact) => jsonEncode(contact.toJson())).toList(),
    );
  }

  Future<void> _addContact() async {
    final newContact = await Navigator.push<EmergencyContact>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEmergencyContactScreen(),
      ),
    );
    if (newContact == null) return;

    setState(() {
      _contacts.add(newContact);
    });
    await _saveContacts();
    await EmergencyHistoryService.logEvent(
      type: 'contact_added',
      title: 'Emergency Contact Added',
      description: newContact.name,
      location: newContact.phoneNumber,
      status: 'Completed',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newContact.name} added to emergency contacts.'),
      ),
    );
  }

  Future<void> _openDialer(EmergencyContact contact) async {
    final uri = Uri(scheme: 'tel', path: contact.phoneNumber);

    try {
      await EmergencyHistoryService.logEvent(
        type: 'contact_call',
        title: 'Emergency Contact Dialer Opened',
        description: contact.name,
        location: contact.phoneNumber,
        status: 'In Progress',
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the phone dialer.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = _contacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final lower = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(lower) ||
          c.phoneNumber.contains(lower);
    }).toList();

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
          'Emergency Contacts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: _addContact,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loadingContacts
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    )
                  : ListView.separated(
                      itemCount: filteredContacts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        return _buildContactTile(contact);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(EmergencyContact contact) {
    final initials = contact.name.isNotEmpty
        ? contact.name
              .trim()
              .split(' ')
              .where((part) => part.isNotEmpty)
              .map((part) => part[0].toUpperCase())
              .take(2)
              .join()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallingContactScreen(contact: contact),
            ),
          );
        },
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[700],
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _openDialer(contact),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          contact.phoneNumber,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                onPressed: () {
                  // Future: show edit/delete options
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
