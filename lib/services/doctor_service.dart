import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/medicine.dart';
import '../models/appointment.dart';

class DoctorService {
  static final DoctorService _instance = DoctorService._internal();
  factory DoctorService() => _instance;
  DoctorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of patients assigned to this doctor
  Stream<List<UserModel>> getPatientsStream(String doctorId) {
    return _firestore
        .collection('users')
        .where('assignedDoctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromJson(doc.data()))
            .where((user) => user.role == 'patient')
            .toList());
  }

  /// Assign a patient to this doctor by email
  Future<String> assignPatientByEmail(String doctorId, String patientEmail) async {
    try {
      // Query by email only (avoids needing composite index)
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: patientEmail.toLowerCase().trim())
          .limit(5)
          .get();

      if (query.docs.isEmpty) {
        // Try case-insensitive match
        final allQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: patientEmail.trim())
            .limit(5)
            .get();
        
        if (allQuery.docs.isEmpty) {
          throw 'No user found with email: $patientEmail';
        }
        
        // Find patient in results
        final patientDoc = allQuery.docs.firstWhere(
          (doc) => doc.data()['role'] == 'patient',
          orElse: () => throw 'No patient account found with this email. The user may be registered as a doctor.',
        );
        
        return await _assignPatient(doctorId, patientDoc);
      }

      // Find patient in results
      QueryDocumentSnapshot<Map<String, dynamic>>? patientDoc;
      for (final doc in query.docs) {
        if (doc.data()['role'] == 'patient') {
          patientDoc = doc;
          break;
        }
      }

      if (patientDoc == null) {
        throw 'No patient account found with this email. The user may be registered as a doctor.';
      }

      return await _assignPatient(doctorId, patientDoc);
    } catch (e) {
      debugPrint('Error assigning patient: $e');
      rethrow;
    }
  }

  Future<String> _assignPatient(String doctorId, QueryDocumentSnapshot<Map<String, dynamic>> patientDoc) async {
    final existingDoctor = patientDoc.data()['assignedDoctorId'];
    
    if (existingDoctor != null && existingDoctor.toString().isNotEmpty) {
      if (existingDoctor == doctorId) {
        throw 'This patient is already assigned to you';
      }
      throw 'This patient is already assigned to another doctor';
    }

    await _firestore.collection('users').doc(patientDoc.id).update({
      'assignedDoctorId': doctorId,
    });

    return patientDoc.data()['name']?.toString() ?? 'Patient';
  }

  /// Remove a patient from this doctor
  Future<void> unassignPatient(String patientId) async {
    try {
      await _firestore.collection('users').doc(patientId).update({
        'assignedDoctorId': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error unassigning patient: $e');
      rethrow;
    }
  }

  /// Get a patient's medicines
  Stream<List<Medicine>> getPatientMedicines(String patientId) {
    return _firestore
        .collection('users')
        .doc(patientId)
        .collection('medicines')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medicine.fromJson(doc.data()))
            .toList());
  }

  /// Get a patient's adherence for today
  Future<Map<String, dynamic>?> getPatientAdherence(String patientId) async {
    try {
      final today = DateTime.now();
      final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await _firestore
          .collection('users')
          .doc(patientId)
          .collection('adherence')
          .doc(key)
          .get();

      return doc.data();
    } catch (e) {
      debugPrint('Error fetching adherence: $e');
      return null;
    }
  }

  /// Create a new appointment
  Future<void> createAppointment(Appointment appointment) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointment.id)
          .set(appointment.toMap());
    } catch (e) {
      debugPrint('Error creating appointment: $e');
      rethrow;
    }
  }

  /// Get appointments for a doctor
  Stream<List<Appointment>> getDoctorAppointments(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromMap(doc.data()))
            .toList());
  }

  /// Update medicine status (Active/Inactive)
  Future<void> updateMedicineStatus(String userId, String medicineId, bool isActive) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(medicineId)
          .update({'isActive': isActive});
    } catch (e) {
      debugPrint('Error updating medicine status: $e');
      rethrow;
    }
  }

  /// Update medicine details
  Future<void> updateMedicine(String userId, Medicine medicine) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(medicine.id)
          .update(medicine.toJson());
    } catch (e) {
      debugPrint('Error updating medicine: $e');
      rethrow;
    }
  }
}
