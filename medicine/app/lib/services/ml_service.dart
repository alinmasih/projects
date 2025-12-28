import 'package:tflite_flutter/tflite_flutter.dart' as tflite;
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math';

/// Service for TensorFlow Lite ML model operations
/// - Load embeddings from medicine reference images
/// - Extract embeddings from captured images
/// - Compare embeddings using cosine similarity
/// - Verify if captured medicine matches reference medicines
class MLService {
  static final MLService _instance = MLService._internal();

  late tflite.Interpreter _interpreter;
  bool _isModelLoaded = false;

  // Model configuration
  static const int _INPUT_SIZE = 224; // Input image size for the model
  static const int _EMBEDDING_SIZE = 128; // Output embedding vector size
  static const double _SIMILARITY_THRESHOLD = 0.75; // Confidence threshold

  factory MLService() {
    return _instance;
  }

  MLService._internal();

  // ========== MODEL INITIALIZATION ==========

  /// Load TensorFlow Lite model from assets
  /// Model should be: assets/models/medicine_embedder.tflite
  Future<void> loadModel() async {
    try {
      if (_isModelLoaded) return;

      // Load the .tflite model from assets
      // Note: Replace 'medicine_embedder.tflite' with actual model name
      _interpreter = await tflite.Interpreter.fromAsset(
        'assets/models/medicine_embedder.tflite',
        options: tflite.InterpreterOptions(
          numThreads: 4,
          useNnapi: true, // Use NNAPI for hardware acceleration on Android
        ),
      );

      _isModelLoaded = true;
      debugPrint('ML Model loaded successfully');
    } catch (e) {
      debugPrint('Error loading ML model: $e');
      rethrow;
    }
  }

  /// Unload model to free memory
  Future<void> unloadModel() async {
    try {
      if (_isModelLoaded) {
        _interpreter.close();
        _isModelLoaded = false;
      }
    } catch (e) {
      debugPrint('Error unloading model: $e');
    }
  }

  // ========== EMBEDDING EXTRACTION ==========

  /// Extract embedding from an image file
  /// @param imageFile: File path to image
  /// @return: List of doubles representing the embedding vector
  Future<List<double>> extractEmbedding(File imageFile) async {
    try {
      if (!_isModelLoaded) {
        await loadModel();
      }

      // Read and decode image
      final imageData = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageData);

      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image to model input size
      final resizedImage = img.copyResize(
        decodedImage,
        width: _INPUT_SIZE,
        height: _INPUT_SIZE,
      );

      // Normalize to [0, 1] range
      final input = _normalizeImage(resizedImage);

      // Run inference
      final output = List<List<double>>.filled(1, List<double>.filled(_EMBEDDING_SIZE, 0));
      _interpreter.run(input, output);

      final embedding = output[0];

      // Normalize embedding vector (L2 normalization)
      final normalizedEmbedding = _normalizeVector(embedding);

      return normalizedEmbedding;
    } catch (e) {
      debugPrint('Error extracting embedding: $e');
      rethrow;
    }
  }

  /// Extract embeddings from multiple image files
  /// Useful for getting embeddings from reference medicine images
  Future<List<List<double>>> extractEmbeddingsFromImages(List<File> imageFiles) async {
    final embeddings = <List<double>>[];
    for (final file in imageFiles) {
      final embedding = await extractEmbedding(file);
      embeddings.add(embedding);
    }
    return embeddings;
  }

  // ========== EMBEDDING COMPARISON ==========

  /// Compare two embeddings using cosine similarity
  /// @param embedding1: First embedding vector
  /// @param embedding2: Second embedding vector
  /// @return: Similarity score (0 to 1, where 1 = identical)
  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Embeddings must have same length');
    }

    double dotProduct = 0;
    double norm1 = 0;
    double norm2 = 0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    norm1 = sqrt(norm1);
    norm2 = sqrt(norm2);

    if (norm1 == 0 || norm2 == 0) {
      return 0;
    }

    return dotProduct / (norm1 * norm2);
  }

  /// Compare captured embedding against multiple reference embeddings
  /// Returns the best match and its confidence score
  /// @param capturedEmbedding: Embedding from captured image
  /// @param referenceEmbeddings: List of embeddings from reference images
  /// @return: Map with 'isMatch', 'confidence', and 'bestMatchIndex'
  Map<String, dynamic> compareAgainstReferences(
    List<double> capturedEmbedding,
    List<List<double>> referenceEmbeddings,
  ) {
    double bestSimilarity = 0;
    int bestMatchIndex = -1;

    for (int i = 0; i < referenceEmbeddings.length; i++) {
      final similarity = cosineSimilarity(
        capturedEmbedding,
        referenceEmbeddings[i],
      );

      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatchIndex = i;
      }
    }

    final isMatch = bestSimilarity >= _SIMILARITY_THRESHOLD;

    return {
      'isMatch': isMatch,
      'confidence': bestSimilarity,
      'bestMatchIndex': bestMatchIndex,
    };
  }

  // ========== MEDICINE VERIFICATION ==========

  /// Full medicine verification pipeline
  /// 1. Extract embedding from captured image
  /// 2. Compare against reference embeddings for each medicine in the slot
  /// 3. Return which medicine matches (if any)
  /// @param capturedImageFile: File of captured image
  /// @param medicinesInSlot: List of Medicine objects in the current slot
  /// @return: Map with verification result
  Future<Map<String, dynamic>> verifyMedicine({
    required File capturedImageFile,
    required List<dynamic> medicinesInSlot,
  }) async {
    try {
      // Extract embedding from captured image
      final capturedEmbedding = await extractEmbedding(capturedImageFile);

      // Compare against each medicine's reference embeddings
      double bestOverallSimilarity = 0;
      String? matchedMedicineId;
      String? matchedMedicineName;

      for (final medicine in medicinesInSlot) {
        // Assuming medicine has 'id', 'name', and 'embeddings' properties
        final medicineEmbeddings =
            List<List<double>>.from(medicine['embeddings'] ?? []);

        if (medicineEmbeddings.isEmpty) continue;

        final result = compareAgainstReferences(
          capturedEmbedding,
          medicineEmbeddings,
        );

        final similarity = result['confidence'] as double;

        if (similarity > bestOverallSimilarity) {
          bestOverallSimilarity = similarity;
          if (result['isMatch'] == true) {
            matchedMedicineId = medicine['id'];
            matchedMedicineName = medicine['name'];
          }
        }
      }

      final isMatch = bestOverallSimilarity >= _SIMILARITY_THRESHOLD;

      return {
        'isMatch': isMatch,
        'confidence': bestOverallSimilarity,
        'matchedMedicineId': matchedMedicineId,
        'matchedMedicineName': matchedMedicineName,
      };
    } catch (e) {
      debugPrint('Error verifying medicine: $e');
      rethrow;
    }
  }

  // ========== UTILITY METHODS ==========

  /// Normalize image to [0, 1] range
  List<List<List<double>>> _normalizeImage(img.Image image) {
    final List<List<List<double>>> output = List.generate(
      _INPUT_SIZE,
      (i) => List.generate(
        _INPUT_SIZE,
        (j) => List.filled(3, 0.0),
      ),
    );

    for (int y = 0; y < _INPUT_SIZE; y++) {
      for (int x = 0; x < _INPUT_SIZE; x++) {
        final pixel = image.getPixelSafe(x, y);
        // Extract RGB channels and normalize to [0, 1]
        output[y][x][0] = pixel.r.toDouble() / 255.0;
        output[y][x][1] = pixel.g.toDouble() / 255.0;
        output[y][x][2] = pixel.b.toDouble() / 255.0;
      }
    }

    return output;
  }

  /// L2 normalization of vector
  List<double> _normalizeVector(List<double> vector) {
    double norm = 0;
    for (final val in vector) {
      norm += val * val;
    }
    norm = sqrt(norm);

    if (norm == 0) return vector;

    return vector.map((val) => val / norm).toList();
  }

  /// Check if model is loaded
  bool get isModelLoaded => _isModelLoaded;

  /// Get similarity threshold
  double get similarityThreshold => _SIMILARITY_THRESHOLD;
}
