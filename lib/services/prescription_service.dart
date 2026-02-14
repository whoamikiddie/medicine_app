import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/prescription.dart';
import 'cloudinary_service.dart';

class PrescriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();
  final _uuid = const Uuid();

  /// Get prescriptions stream for a user
  Stream<List<Prescription>> getPrescriptions(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('prescriptions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Prescription.fromJson(doc.data()))
            .toList());
  }

  /// Add a new prescription
  Future<Prescription> addPrescription({
    required String userId,
    required String title,
    String? doctorName,
    String? hospitalName,
    String? diagnosis,
    String? notes,
    File? imageFile,
    List<String> medicines = const [],
    required DateTime dateIssued,
  }) async {
    try {
      final id = _uuid.v4();
      String? imageUrl;

      // Upload image to Cloudinary if provided (optional, won't block save)
      if (imageFile != null) {
        try {
          imageUrl = await _cloudinary.uploadImage(
            imageFile,
            folder: 'medicine_app/prescriptions',
          );
        } catch (e) {
          debugPrint('Image upload failed (non-blocking): $e');
          // Continue saving without image — Cloudinary may not be configured
        }
      }

      final prescription = Prescription(
        id: id,
        userId: userId,
        title: title,
        doctorName: doctorName,
        hospitalName: hospitalName,
        diagnosis: diagnosis,
        notes: notes,
        imageUrl: imageUrl,
        medicines: medicines,
        dateIssued: dateIssued,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(id)
          .set(prescription.toJson());

      debugPrint('Prescription added: $id');
      return prescription;
    } catch (e) {
      debugPrint('Error adding prescription: $e');
      rethrow;
    }
  }

  /// Delete a prescription
  Future<void> deletePrescription(String userId, String prescriptionId, String? imageUrl) async {
    try {
      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescriptionId)
          .delete();

      // Note: Cloudinary image deletion would require signed API calls
      // Images will be managed via Cloudinary dashboard if needed
      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint('Image at $imageUrl should be deleted from Cloudinary dashboard');
      }

      debugPrint('Prescription deleted: $prescriptionId');
    } catch (e) {
      debugPrint('Error deleting prescription: $e');
      rethrow;
    }
  }

  /// Get a single prescription
  Future<Prescription?> getPrescription(String userId, String prescriptionId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescriptionId)
          .get();

      if (doc.exists) {
        return Prescription.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting prescription: $e');
      return null;
    }
  }
}
