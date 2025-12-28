/// Log entry for medicine intake verification
class MedicineLog {
  final String id; // UUID
  final String userId;
  final String slot; // "morning", "afternoon", "night"
  final bool taken; // User took medicine and passed ML verification
  final DateTime? timestamp; // When medicine was actually taken
  final bool missed; // Automatically set to true if not taken by end of slot
  final bool whatsappSent; // Flag to prevent duplicate WhatsApp messages
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicineLog({
    required this.id,
    required this.userId,
    required this.slot,
    required this.taken,
    this.timestamp,
    required this.missed,
    required this.whatsappSent,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'slot': slot,
      'taken': taken,
      'timestamp': timestamp,
      'missed': missed,
      'whatsappSent': whatsappSent,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from Firestore map
  factory MedicineLog.fromFirestore(Map<String, dynamic> data) {
    return MedicineLog(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      slot: data['slot'] ?? '',
      taken: data['taken'] ?? false,
      timestamp: (data['timestamp'] as dynamic)?.toDate(),
      missed: data['missed'] ?? false,
      whatsappSent: data['whatsappSent'] ?? false,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
