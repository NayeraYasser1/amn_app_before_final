import 'package:cloud_firestore/cloud_firestore.dart';

class CarDriverStatusService {
  CarDriverStatusService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('user_status');

  static Future<void> saveCarStatus({
    required String userId,
    required double carHealthPercent,
    required double fuelLevelPercent,
    required int fuelRangeKm,
    required double engineTempC,
    required Map<String, double> tirePressurePsi,
  }) async {
    await _collection.doc(userId).set(
      {
        'carHealthPercent': carHealthPercent,
        'fuelLevelPercent': fuelLevelPercent,
        'fuelRangeKm': fuelRangeKm,
        'engineTempC': engineTempC,
        'tirePressurePsi': tirePressurePsi,
        'carStatusUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> saveDriverStatus({
    required String userId,
    required double driverAttentivenessPercent,
    required int distractedMoments,
    required int drivingBehaviorScore,
    required double fatigueLevelPercent,
    required int safetyScore,
  }) async {
    await _collection.doc(userId).set(
      {
        'driverAttentivenessPercent': driverAttentivenessPercent,
        'distractedMoments': distractedMoments,
        'drivingBehaviorScore': drivingBehaviorScore,
        'fatigueLevelPercent': fatigueLevelPercent,
        'safetyScore': safetyScore,
        'driverStatusUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

