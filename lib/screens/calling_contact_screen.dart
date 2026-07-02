import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_history_service.dart';

class CallingContactScreen extends StatelessWidget {
  final EmergencyContact contact;

  const CallingContactScreen({super.key, required this.contact});

  Future<void> _startCall(BuildContext context) async {
    await EmergencyHistoryService.logEvent(
      type: 'contact_call',
      title: 'Calling ${contact.name}',
      description: 'Emergency contact call',
      status: 'In Progress',
    );

    final uri = Uri(scheme: 'tel', path: contact.phoneNumber);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Calling ${contact.name}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                contact.phoneNumber,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => _startCall(context),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: const Icon(
                    Icons.call,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

