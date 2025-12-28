import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Calculates the knee flexion/extension angle using hip, knee, and ankle landmarks.
/// 
/// Formula: θ = arccos( ((H−K)·(A−K)) / (|H−K| × |A−K|) )
/// where H = hip, K = knee, A = ankle coordinates.
/// 
/// Returns the angle in degrees, or null if landmarks are missing or invalid.
double? calculateKneeAngle(Pose pose) {
  try {
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (rightHip == null || rightKnee == null || rightAnkle == null) {
      return null;
    }

    // Extract coordinates
    final hip = vm.Vector3(rightHip.x, rightHip.y, rightHip.z);
    final knee = vm.Vector3(rightKnee.x, rightKnee.y, rightKnee.z);
    final ankle = vm.Vector3(rightAnkle.x, rightAnkle.y, rightAnkle.z);

    // Calculate vectors from knee to hip and knee to ankle
    final vectorHip = hip - knee;
    final vectorAnkle = ankle - knee;

    // Calculate angle using dot product formula
    // θ = arccos( (H-K)·(A-K) / (|H-K| × |A-K|) )
    final dotProduct = vectorHip.dot(vectorAnkle);
    final magnitudeHip = vectorHip.length;
    final magnitudeAnkle = vectorAnkle.length;

    if (magnitudeHip == 0 || magnitudeAnkle == 0) {
      return null;
    }

    final cosAngle = dotProduct / (magnitudeHip * magnitudeAnkle);
    // Clamp to [-1, 1] to avoid NaN from arccos
    final clampedCos = cosAngle.clamp(-1.0, 1.0);
    final angleRadians = math.acos(clampedCos);
    final angleDegrees = vm.degrees(angleRadians);

    return angleDegrees;
  } catch (e) {
    return null;
  }
}

/// Smooths a list of angles by calculating the average.
double smoothAngle(List<double> angleHistory) {
  if (angleHistory.isEmpty) return 0.0;
  final sum = angleHistory.reduce((a, b) => a + b);
  return sum / angleHistory.length;
}

