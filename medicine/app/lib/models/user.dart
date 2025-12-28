import 'medicine_slot.dart';

/// User model representing a medicine tracker app user
class User {
  final String id;
  final String name;
  final String parentPhone; // Phone number for WhatsApp alerts
  final Map<String, MedicineSlot> slots; // Morning, Afternoon, Night
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.parentPhone,
    required this.slots,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'parentPhone': parentPhone,
      'slots': slots.map((key, slot) => MapEntry(key, slot.toFirestore())),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from Firestore map
  factory User.fromFirestore(Map<String, dynamic> data) {
    return User(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      parentPhone: data['parentPhone'] ?? '',
      slots: (data['slots'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, MedicineSlot.fromFirestore(value)),
          ) ??
          {},
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
