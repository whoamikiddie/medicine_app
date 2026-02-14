import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'patient' or 'doctor'
  final String? assignedDoctorId;
  final String? phone;
  final String? emergencyContact;
  final String? profileImageUrl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.assignedDoctorId,
    this.phone,
    this.emergencyContact,
    this.profileImageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isDoctor => role == 'doctor';
  bool get isPatient => role == 'patient';

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role,
    'assignedDoctorId': assignedDoctorId,
    'phone': phone,
    'emergencyContact': emergencyContact,
    'profileImageUrl': profileImageUrl,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle createdAt - could be Firestore Timestamp, String, or null
    DateTime parsedCreatedAt;
    final createdAtValue = json['createdAt'];
    if (createdAtValue is Timestamp) {
      parsedCreatedAt = createdAtValue.toDate();
    } else if (createdAtValue is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return UserModel(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'patient',
      assignedDoctorId: json['assignedDoctorId']?.toString(),
      phone: json['phone']?.toString(),
      emergencyContact: json['emergencyContact']?.toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
      createdAt: parsedCreatedAt,
    );
  }
}
