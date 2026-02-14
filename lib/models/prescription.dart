import 'package:cloud_firestore/cloud_firestore.dart';

class Prescription {
  final String id;
  final String userId;
  final String title;
  final String? doctorName;
  final String? hospitalName;
  final String? diagnosis;
  final String? notes;
  final String? imageUrl;       // Firebase Storage URL
  final String? localImagePath; // Local path before upload
  final List<String> medicines; // Medicine names in prescription
  final DateTime dateIssued;
  final DateTime createdAt;

  Prescription({
    required this.id,
    required this.userId,
    required this.title,
    this.doctorName,
    this.hospitalName,
    this.diagnosis,
    this.notes,
    this.imageUrl,
    this.localImagePath,
    this.medicines = const [],
    required this.dateIssued,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'doctorName': doctorName,
    'hospitalName': hospitalName,
    'diagnosis': diagnosis,
    'notes': notes,
    'imageUrl': imageUrl,
    'medicines': medicines,
    'dateIssued': Timestamp.fromDate(dateIssued),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Prescription',
      doctorName: json['doctorName']?.toString(),
      hospitalName: json['hospitalName']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      notes: json['notes']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      medicines: List<String>.from(json['medicines'] ?? []),
      dateIssued: _parseDateTime(json['dateIssued']),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
