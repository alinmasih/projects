/// Aggregation of medicine-related data for display
class MedicineVerification {
  final bool isMatch; // Did captured image match reference images?
  final double confidence; // Cosine similarity score (0-1)
  final String matchedMedicineId;
  final String matchedMedicineName;

  MedicineVerification({
    required this.isMatch,
    required this.confidence,
    required this.matchedMedicineId,
    required this.matchedMedicineName,
  });
}
