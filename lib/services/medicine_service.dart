import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/medicine.dart';

class MedicineService {
  static final MedicineService _instance = MedicineService._internal();
  factory MedicineService() => _instance;
  MedicineService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reference to a user's medicines sub-collection
  CollectionReference<Map<String, dynamic>> _medicinesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('medicines');

  // Reference to a user's adherence sub-collection
  CollectionReference<Map<String, dynamic>> _adherenceRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('adherence');

  // ─── CRUD ─────────────────────────────────────────────────────────

  /// Stream of all medicines for a user (real-time)
  Stream<List<Medicine>> medicinesStream(String userId) {
    return _medicinesRef(userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medicine.fromJson(doc.data()))
            .toList());
  }

  /// Fetch all medicines once
  Future<List<Medicine>> getMedicines(String userId) async {
    try {
      final snapshot = await _medicinesRef(userId).get();
      return snapshot.docs
          .map((doc) => Medicine.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
      return [];
    }
  }

  /// Add a new medicine
  Future<void> addMedicine(Medicine medicine) async {
    try {
      await _medicinesRef(medicine.userId)
          .doc(medicine.id)
          .set(medicine.toJson());
      debugPrint('Medicine added: ${medicine.name}');
    } catch (e) {
      debugPrint('Error adding medicine: $e');
      rethrow;
    }
  }

  /// Update an existing medicine
  Future<void> updateMedicine(Medicine medicine) async {
    try {
      await _medicinesRef(medicine.userId)
          .doc(medicine.id)
          .update(medicine.toJson());
    } catch (e) {
      debugPrint('Error updating medicine: $e');
      rethrow;
    }
  }

  /// Delete a medicine
  Future<void> deleteMedicine(String userId, String medicineId) async {
    try {
      await _medicinesRef(userId).doc(medicineId).delete();
      debugPrint('Medicine deleted: $medicineId');
    } catch (e) {
      debugPrint('Error deleting medicine: $e');
      rethrow;
    }
  }

  /// Toggle active status
  Future<void> toggleActive(String userId, String medicineId, bool isActive) async {
    try {
      await _medicinesRef(userId).doc(medicineId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error toggling medicine: $e');
      rethrow;
    }
  }

  // ─── ADHERENCE TRACKING ───────────────────────────────────────────

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get today's taken status map
  Future<Map<String, bool>> getTodayAdherence(String userId) async {
    try {
      final doc = await _adherenceRef(userId).doc(_todayKey()).get();
      if (!doc.exists || doc.data() == null) return {};
      final data = doc.data()!;
      final Map<String, bool> result = {};
      data.forEach((key, value) {
        if (key != 'date') {
          result[key] = value == true;
        }
      });
      return result;
    } catch (e) {
      debugPrint('Error fetching adherence: $e');
      return {};
    }
  }

  /// Toggle taken status for a medicine+time combo
  Future<void> toggleTaken(String userId, String medicineId, String time, bool taken) async {
    try {
      final key = '${medicineId}_$time';
      await _adherenceRef(userId).doc(_todayKey()).set(
        {key: taken, 'date': _todayKey()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error toggling taken: $e');
    }
  }

  /// Get adherence history for reports (last N days)
  Future<List<Map<String, dynamic>>> getAdherenceHistory(String userId, int days) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      final startKey = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

      final snapshot = await _adherenceRef(userId)
          .where('date', isGreaterThanOrEqualTo: startKey)
          .orderBy('date')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error fetching adherence history: $e');
      return [];
    }
  }
}
