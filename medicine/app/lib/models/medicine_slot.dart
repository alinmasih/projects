import 'medicine.dart';

/// Medicine slot (Morning, Afternoon, Night) with time range
class MedicineSlot {
  final String name; // "morning", "afternoon", "night"
  final String startTime; // "08:00"
  final String endTime; // "10:00"
  final List<Medicine> medicines;

  MedicineSlot({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.medicines,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'medicines': medicines.map((m) => m.toFirestore()).toList(),
    };
  }

  /// Create from Firestore map
  factory MedicineSlot.fromFirestore(Map<String, dynamic> data) {
    return MedicineSlot(
      name: data['name'] ?? '',
      startTime: data['startTime'] ?? '00:00',
      endTime: data['endTime'] ?? '23:59',
      medicines: (data['medicines'] as List<dynamic>?)
              ?.map((m) => Medicine.fromFirestore(m))
              .toList() ??
          [],
    );
  }
}
