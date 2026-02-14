import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String frequency; // 'daily', 'twice', 'thrice', 'weekly'
  final List<String> times; // ['08:00', '14:00', '20:00']
  final String foodInstruction; // 'before', 'after', 'with'
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final String? foodAdvice; // AI-generated
  final bool isActive;

  Medicine({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.foodInstruction,
    required this.startDate,
    this.endDate,
    this.notes,
    this.foodAdvice,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
    'times': times,
    'foodInstruction': foodInstruction,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'notes': notes,
    'foodAdvice': foodAdvice,
    'isActive': isActive,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? 'daily',
      times: List<String>.from(json['times'] ?? []),
      foodInstruction: json['foodInstruction']?.toString() ?? 'after',
      startDate: _parseDateTime(json['startDate']),
      endDate: json['endDate'] != null ? _parseDateTime(json['endDate']) : null,
      notes: json['notes']?.toString(),
      foodAdvice: json['foodAdvice']?.toString(),
      isActive: json['isActive'] ?? true,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Medicine copyWith({
    String? name,
    String? dosage,
    String? frequency,
    List<String>? times,
    String? foodInstruction,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? foodAdvice,
    bool? isActive,
  }) => Medicine(
    id: id,
    userId: userId,
    name: name ?? this.name,
    dosage: dosage ?? this.dosage,
    frequency: frequency ?? this.frequency,
    times: times ?? this.times,
    foodInstruction: foodInstruction ?? this.foodInstruction,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    notes: notes ?? this.notes,
    foodAdvice: foodAdvice ?? this.foodAdvice,
    isActive: isActive ?? this.isActive,
  );
}
