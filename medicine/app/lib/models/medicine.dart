/// Medicine object with reference images and embeddings for ML verification
class Medicine {
  final String id; // UUID
  final String name;
  final List<String> imageUrls; // Firebase Storage URLs of 3-5 reference photos
  final List<List<double>> embeddings; // TensorFlow embeddings from reference images
  final DateTime createdAt;

  Medicine({
    required this.id,
    required this.name,
    required this.imageUrls,
    required this.embeddings,
    required this.createdAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'imageUrls': imageUrls,
      'embeddings': embeddings,
      'createdAt': createdAt,
    };
  }

  /// Create from Firestore map
  factory Medicine.fromFirestore(Map<String, dynamic> data) {
    return Medicine(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      embeddings: (data['embeddings'] as List<dynamic>?)
              ?.map((e) => List<double>.from(e))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
