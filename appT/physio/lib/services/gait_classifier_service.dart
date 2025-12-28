import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for classifying gait quality using TensorFlow Lite.
/// 
/// This service loads a TFLite model and classifies gait patterns as
/// "Good Gait" or "Poor Gait" based on pose angles, cadence, and balance metrics.
class GaitClassifierService {
  Interpreter? _interpreter;
  bool _isLoaded = false;
  String? _modelPath;

  /// Loads the TFLite model from assets.
  /// 
  /// [modelName] Name of the model file (e.g., 'gait_quality.tflite')
  /// 
  /// Returns true if model loaded successfully, false otherwise.
  Future<bool> loadModel(String modelName) async {
    try {
      // Get the model file from assets
      final byteData = await rootBundle.load('assets/models/$modelName');
      final bytes = byteData.buffer.asUint8List();

      // Write to temporary directory
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/$modelName');
      await modelFile.writeAsBytes(bytes);
      _modelPath = modelFile.path;

      // Load the interpreter
      _interpreter = Interpreter.fromFile(modelFile);
      _isLoaded = true;

      // Print model input/output details for debugging
      if (_interpreter != null) {
        print('Model loaded successfully');
        print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
        print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      }

      return true;
    } catch (e) {
      print('Error loading model: $e');
      _isLoaded = false;
      return false;
    }
  }

  /// Classifies gait quality based on input features.
  /// 
  /// [features] List of normalized features:
  ///   - Head tilt angle (normalized 0-1)
  ///   - Spine angle (normalized 0-1)
  ///   - Left knee angle (normalized 0-1)
  ///   - Right knee angle (normalized 0-1)
  ///   - Hip symmetry (normalized 0-1)
  ///   - Cadence (normalized 0-1)
  ///   - Sway (normalized 0-1)
  /// 
  /// Returns classification result: "Good Gait" or "Poor Gait"
  /// Returns null if model not loaded or classification fails.
  String? classifyGait(List<double> features) {
    if (!_isLoaded || _interpreter == null) {
      return null;
    }

    try {
      // Ensure features match model input size
      // Most gait models expect 7-10 features
      final inputSize = _interpreter!.getInputTensor(0).shape[1];
      final normalizedFeatures = List<double>.from(features);
      
      // Pad or truncate to match input size
      while (normalizedFeatures.length < inputSize) {
        normalizedFeatures.add(0.0);
      }
      if (normalizedFeatures.length > inputSize) {
        normalizedFeatures.removeRange(inputSize, normalizedFeatures.length);
      }

      // Prepare input and output buffers
      final input = [normalizedFeatures];
      final output = List.filled(1, List.filled(2, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Interpret output (assuming binary classification)
      // Output format: [probability_poor, probability_good]
      final poorGaitProb = output[0][0];
      final goodGaitProb = output[0][1];

      // Return classification based on higher probability
      if (goodGaitProb > poorGaitProb) {
        return 'Good Gait';
      } else {
        return 'Poor Gait';
      }
    } catch (e) {
      print('Error classifying gait: $e');
      return null;
    }
  }

  /// Classifies gait with confidence score.
  /// 
  /// Returns a map with 'classification' and 'confidence' (0.0-1.0).
  Map<String, dynamic>? classifyGaitWithConfidence(List<double> features) {
    if (!_isLoaded || _interpreter == null) {
      return null;
    }

    try {
      final inputSize = _interpreter!.getInputTensor(0).shape[1];
      final normalizedFeatures = List<double>.from(features);
      
      while (normalizedFeatures.length < inputSize) {
        normalizedFeatures.add(0.0);
      }
      if (normalizedFeatures.length > inputSize) {
        normalizedFeatures.removeRange(inputSize, normalizedFeatures.length);
      }

      final input = [normalizedFeatures];
      final output = List.filled(1, List.filled(2, 0.0));

      _interpreter!.run(input, output);

      final poorGaitProb = output[0][0];
      final goodGaitProb = output[0][1];

      final classification = goodGaitProb > poorGaitProb ? 'Good Gait' : 'Poor Gait';
      final confidence = goodGaitProb > poorGaitProb ? goodGaitProb : poorGaitProb;

      return {
        'classification': classification,
        'confidence': confidence,
        'goodGaitProb': goodGaitProb,
        'poorGaitProb': poorGaitProb,
      };
    } catch (e) {
      print('Error classifying gait: $e');
      return null;
    }
  }

  /// Normalizes a value to 0-1 range based on min/max.
  /// 
  /// Useful for feature normalization before model input.
  static double normalize(double value, double min, double max) {
    if (max == min) return 0.5;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// Normalizes angle to 0-1 range (assuming 0-180 degrees).
  static double normalizeAngle(double angle) {
    return normalize(angle, 0.0, 180.0);
  }

  /// Normalizes cadence to 0-1 range (assuming 0-200 steps/min).
  static double normalizeCadence(double cadence) {
    return normalize(cadence, 0.0, 200.0);
  }

  /// Checks if model is loaded and ready.
  bool get isLoaded => _isLoaded;

  /// Gets the model path.
  String? get modelPath => _modelPath;

  /// Disposes the interpreter and releases resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}

