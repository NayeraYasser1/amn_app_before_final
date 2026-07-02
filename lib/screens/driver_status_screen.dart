import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/car_driver_status_service.dart';

class DriverStatusScreen extends StatefulWidget {
  const DriverStatusScreen({super.key});

  @override
  State<DriverStatusScreen>  createState()  => _DriverStatusScreenState();
}

class _DriverStatusScreenState extends State<DriverStatusScreen> {
  @override
  void initState() {
    super.initState();
    _recordDriverStatus();
  }

  Future<void> _recordDriverStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await CarDriverStatusService.saveDriverStatus(
      userId: user.uid,
      driverAttentivenessPercent: 92,
      distractedMoments: 3,
      drivingBehaviorScore: 84,
      fatigueLevelPercent: 35,
      safetyScore: 72,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Driver Status',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ScoreCard(title: 'Car Health Score', score: 80),
          SizedBox(height: 14),
          _IconRow(),
          SizedBox(height: 18),
          _ScoreCard(title: 'Driver Behaviour Score', score: 65),
          SizedBox(height: 14),
          _IconRow(),
          SizedBox(height: 18),
          _ScoreCard(
            title: 'Safety Score',
            score: 72,
            subtitle: 'SAFETY SCORE + ACCIDENT PREDICTION',
          ),
          SizedBox(height: 14),
          _PredictionCard(),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int score;

  const _ScoreCard({required this.title, required this.score, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _Ring(score: score),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final int score;
  const _Ring({required this.score});

  @override
  Widget build(BuildContext context) {
    final value = (score / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 7,
            backgroundColor: Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9B9B9B)),
          ),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow();

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.speed,
      Icons.work_outline,
      Icons.local_gas_station,
      Icons.circle_outlined,
      Icons.more_horiz,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: icons
            .map(
              (i) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(i, color: Colors.black54),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.black54),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Accident prediction is based on your driving behaviour trends.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
