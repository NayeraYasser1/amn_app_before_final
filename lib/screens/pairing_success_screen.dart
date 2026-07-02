import 'package:flutter/material.dart';
import '../services/usage_logger.dart';

class PairingSuccessScreen extends StatelessWidget {
  const PairingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    UsageLogger.logScreenView('PairingSuccessScreen');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Successfully Paired',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enjoy your day!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text(
              'Back to Home Page',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


