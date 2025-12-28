import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Utility class for calculating angles between pose keypoints using vector_math.
/// 
/// This class provides methods to calculate angles between three points
/// which is essential for posture and gait analysis (e.g., head tilt, spine alignment, knee angles).
class AngleUtils {
  /// Calculates the angle in degrees between three points (point1, point2, point3).
  /// 
  /// The angle is calculated at point2, forming an angle between vectors
  /// point2->point1 and point2->point3.
  /// 
  /// [point1] First point (e.g., left ear)
  /// [point2] Middle point (e.g., neck/shoulder)
  /// [point3] Third point (e.g., right ear or hip)
  /// 
  /// Returns the angle in degrees, or null if any point is null.
  static double? calculateAngle(
    PoseLandmark? point1,
    PoseLandmark? point2,
    PoseLandmark? point3,
  ) {
    if (point1 == null || point2 == null || point3 == null) {
      return null;
    }

    // Convert to vector_math Vector2 for better calculations
    final v1 = vm.Vector2(point1.x - point2.x, point1.y - point2.y);
    final v2 = vm.Vector2(point3.x - point2.x, point3.y - point2.y);

    // Normalize vectors
    if (v1.length2 == 0 || v2.length2 == 0) {
      return null;
    }

    v1.normalize();
    v2.normalize();

    // Calculate angle using dot product
    final dotProduct = vm.dot2(v1, v2);
    final clampedCos = dotProduct.clamp(-1.0, 1.0);
    final angleRadians = math.acos(clampedCos);
    final angleDegrees = angleRadians * 180 / math.pi;

    return angleDegrees;
  }

  /// Calculates the angle in degrees between three Offset points.
  /// 
  /// Convenience method for Flutter Offset coordinates.
  static double? calculateAngleFromOffsets(
    Offset point1,
    Offset point2,
    Offset point3,
  ) {
    final v1 = vm.Vector2(point1.dx - point2.dx, point1.dy - point2.dy);
    final v2 = vm.Vector2(point3.dx - point2.dx, point3.dy - point2.dy);

    if (v1.length2 == 0 || v2.length2 == 0) {
      return null;
    }

    v1.normalize();
    v2.normalize();

    final dotProduct = vm.dot2(v1, v2);
    final clampedCos = dotProduct.clamp(-1.0, 1.0);
    final angleRadians = math.acos(clampedCos);
    final angleDegrees = angleRadians * 180 / math.pi;

    return angleDegrees;
  }

  /// Calculates the head tilt angle using left ear, right ear, and neck/shoulder.
  /// 
  /// Returns the angle in degrees. A value close to 180° indicates a straight head,
  /// while values significantly different indicate tilting.
  static double? calculateHeadTiltAngle(
    PoseLandmark? leftEar,
    PoseLandmark? rightEar,
    PoseLandmark? neck,
  ) {
    return calculateAngle(leftEar, neck, rightEar);
  }

  /// Calculates the spine alignment angle using shoulder, hip, and knee.
  /// 
  /// This helps detect slouching or forward lean.
  /// Returns the angle in degrees.
  static double? calculateSpineAngle(
    PoseLandmark? shoulder,
    PoseLandmark? hip,
    PoseLandmark? knee,
  ) {
    return calculateAngle(shoulder, hip, knee);
  }

  /// Calculates the knee angle using hip, knee, and ankle.
  /// 
  /// This helps detect if the leg is straight or bent.
  /// Returns the angle in degrees.
  static double? calculateKneeAngle(
    PoseLandmark? hip,
    PoseLandmark? knee,
    PoseLandmark? ankle,
  ) {
    return calculateAngle(hip, knee, ankle);
  }

  /// Calculates the vertical deviation between two points.
  /// 
  /// Useful for detecting uneven stance (e.g., comparing left and right hip heights).
  /// Returns the absolute difference in y-coordinates.
  static double? calculateVerticalDeviation(
    PoseLandmark? point1,
    PoseLandmark? point2,
  ) {
    if (point1 == null || point2 == null) {
      return null;
    }
    return (point1.y - point2.y).abs();
  }

  /// Calculates hip symmetry by comparing left and right hip positions.
  /// 
  /// Returns the difference in y-coordinates (height difference).
  /// A value close to 0 indicates good symmetry.
  static double? calculateHipSymmetry(
    PoseLandmark? leftHip,
    PoseLandmark? rightHip,
  ) {
    return calculateVerticalDeviation(leftHip, rightHip);
  }

  /// Calculates the distance between two landmarks.
  /// 
  /// Useful for measuring stride length or limb lengths.
  static double? calculateDistance(
    PoseLandmark? point1,
    PoseLandmark? point2,
  ) {
    if (point1 == null || point2 == null) {
      return null;
    }
    final v = vm.Vector2(point1.x - point2.x, point1.y - point2.y);
    return v.length;
  }

  /// Calculates the 3D angle using z-coordinates for depth analysis.
  /// 
  /// Useful for detecting forward/backward lean.
  static double? calculate3DAngle(
    PoseLandmark? point1,
    PoseLandmark? point2,
    PoseLandmark? point3,
  ) {
    if (point1 == null || point2 == null || point3 == null) {
      return null;
    }

    final v1 = vm.Vector3(
      point1.x - point2.x,
      point1.y - point2.y,
      point1.z - point2.z,
    );
    final v2 = vm.Vector3(
      point3.x - point2.x,
      point3.y - point2.y,
      point3.z - point2.z,
    );

    if (v1.length2 == 0 || v2.length2 == 0) {
      return null;
    }

    v1.normalize();
    v2.normalize();

    final dotProduct = vm.dot3(v1, v2);
    final clampedCos = dotProduct.clamp(-1.0, 1.0);
    final angleRadians = math.acos(clampedCos);
    final angleDegrees = angleRadians * 180 / math.pi;

    return angleDegrees;
  }
}

