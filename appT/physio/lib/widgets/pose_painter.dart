import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/angle_utils.dart';

/// Custom painter that draws the detected pose skeleton overlay on the camera preview.
/// 
/// This widget draws all 33 keypoints and connecting lines (MediaPipe-style) to visualize
/// the detected human pose, with optional angle labels.
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final Size widgetSize;
  final bool showLabels;
  final bool showAngles;

  /// Constructor for PosePainter.
  /// 
  /// [poses] List of detected poses to draw
  /// [imageSize] Size of the camera image
  /// [widgetSize] Size of the widget where the overlay will be drawn
  /// [showLabels] Whether to show joint name labels
  /// [showAngles] Whether to show angle measurements
  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.widgetSize,
    this.showLabels = false,
    this.showAngles = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    // Calculate scale factors to map image coordinates to widget coordinates
    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    // Draw each detected pose
    for (final pose in poses) {
      _drawPose(canvas, pose, scaleX, scaleY);
    }
  }

  /// Draws a single pose with keypoints and connections.
  void _drawPose(Canvas canvas, Pose pose, double scaleX, double scaleY) {
    // Draw connections (skeleton lines) first
    _drawConnections(canvas, pose, scaleX, scaleY);

    // Draw keypoints
    _drawKeypoints(canvas, pose, scaleX, scaleY);

    // Draw labels and angles if enabled
    if (showLabels || showAngles) {
      _drawLabelsAndAngles(canvas, pose, scaleX, scaleY);
    }
  }

  /// Draws the skeleton connections between keypoints (MediaPipe-style).
  /// 
  /// Includes all 33 landmarks with proper anatomical connections.
  void _drawConnections(Canvas canvas, Pose pose, double scaleX, double scaleY) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // MediaPipe Pose connections (all 33 landmarks)
    final connections = [
      // Face connections
      [PoseLandmarkType.nose, PoseLandmarkType.leftEyeInner],
      [PoseLandmarkType.nose, PoseLandmarkType.rightEyeInner],
      [PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye],
      [PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeOuter],
      [PoseLandmarkType.leftEyeOuter, PoseLandmarkType.leftEar],
      [PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye],
      [PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter],
      [PoseLandmarkType.rightEyeOuter, PoseLandmarkType.rightEar],
      
      // Upper body - shoulders and arms
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb],
      [PoseLandmarkType.leftPinky, PoseLandmarkType.leftIndex],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],
      [PoseLandmarkType.rightPinky, PoseLandmarkType.rightIndex],
      
      // Torso
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      
      // Lower body - legs
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
      [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
      [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
      [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
    ];

    for (final connection in connections) {
      final startLandmark = pose.landmarks[connection[0]];
      final endLandmark = pose.landmarks[connection[1]];

      if (startLandmark != null && endLandmark != null) {
        final startPoint = Offset(
          startLandmark.x * scaleX,
          startLandmark.y * scaleY,
        );
        final endPoint = Offset(
          endLandmark.x * scaleX,
          endLandmark.y * scaleY,
        );

        canvas.drawLine(startPoint, endPoint, paint);
      }
    }
  }

  /// Draws all 33 keypoints (joints) of the pose.
  void _drawKeypoints(Canvas canvas, Pose pose, double scaleX, double scaleY) {
    // Different colors for different body parts
    final headPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;
    
    final bodyPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    final limbPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    const keypointRadius = 5.0;

    // Draw all landmarks
    for (final entry in pose.landmarks.entries) {
      final landmark = entry.value;
      final point = Offset(
        landmark.x * scaleX,
        landmark.y * scaleY,
      );

      // Choose color based on landmark type
      Paint paint;
      if (_isHeadLandmark(entry.key)) {
        paint = headPaint;
      } else if (_isLimbLandmark(entry.key)) {
        paint = limbPaint;
      } else {
        paint = bodyPaint;
      }

      canvas.drawCircle(point, keypointRadius, paint);
    }
  }

  /// Draws labels and angle measurements on the pose.
  void _drawLabelsAndAngles(Canvas canvas, Pose pose, double scaleX, double scaleY) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black,
          blurRadius: 2,
        ),
      ],
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw angle measurements if enabled
    if (showAngles) {
      _drawAngleLabels(canvas, pose, scaleX, scaleY, textStyle, textPainter);
    }

    // Draw joint labels if enabled
    if (showLabels) {
      _drawJointLabels(canvas, pose, scaleX, scaleY, textStyle, textPainter);
    }
  }

  /// Draws angle measurements at key joints.
  void _drawAngleLabels(
    Canvas canvas,
    Pose pose,
    double scaleX,
    double scaleY,
    TextStyle textStyle,
    TextPainter textPainter,
  ) {
    final landmarks = pose.landmarks;

    // Head tilt angle
    final leftEar = landmarks[PoseLandmarkType.leftEar];
    final rightEar = landmarks[PoseLandmarkType.rightEar];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    if (leftEar != null && rightEar != null && leftShoulder != null) {
      final angle = AngleUtils.calculateHeadTiltAngle(leftEar, leftShoulder, rightEar);
      if (angle != null) {
        final point = Offset(
          leftShoulder.x * scaleX,
          (leftShoulder.y - 30) * scaleY,
        );
        _drawText(canvas, 'Head: ${angle.toStringAsFixed(1)}°', point, textStyle, textPainter);
      }
    }

    // Knee angles
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    if (leftHip != null && leftKnee != null && leftAnkle != null) {
      final angle = AngleUtils.calculateKneeAngle(leftHip, leftKnee, leftAnkle);
      if (angle != null) {
        final point = Offset(
          leftKnee.x * scaleX,
          (leftKnee.y - 20) * scaleY,
        );
        _drawText(canvas, 'L-Knee: ${angle.toStringAsFixed(1)}°', point, textStyle, textPainter);
      }
    }

    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    if (rightHip != null && rightKnee != null && rightAnkle != null) {
      final angle = AngleUtils.calculateKneeAngle(rightHip, rightKnee, rightAnkle);
      if (angle != null) {
        final point = Offset(
          rightKnee.x * scaleX,
          (rightKnee.y - 20) * scaleY,
        );
        _drawText(canvas, 'R-Knee: ${angle.toStringAsFixed(1)}°', point, textStyle, textPainter);
      }
    }
  }

  /// Draws joint name labels.
  void _drawJointLabels(
    Canvas canvas,
    Pose pose,
    double scaleX,
    double scaleY,
    TextStyle textStyle,
    TextPainter textPainter,
  ) {
    // Only draw labels for major joints to avoid clutter
    final majorJoints = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    final jointNames = {
      PoseLandmarkType.nose: 'Nose',
      PoseLandmarkType.leftShoulder: 'L-Shoulder',
      PoseLandmarkType.rightShoulder: 'R-Shoulder',
      PoseLandmarkType.leftHip: 'L-Hip',
      PoseLandmarkType.rightHip: 'R-Hip',
      PoseLandmarkType.leftKnee: 'L-Knee',
      PoseLandmarkType.rightKnee: 'R-Knee',
      PoseLandmarkType.leftAnkle: 'L-Ankle',
      PoseLandmarkType.rightAnkle: 'R-Ankle',
    };

    for (final jointType in majorJoints) {
      final landmark = pose.landmarks[jointType];
      if (landmark != null) {
        final point = Offset(
          landmark.x * scaleX,
          (landmark.y - 15) * scaleY,
        );
        final name = jointNames[jointType] ?? '';
        _drawText(canvas, name, point, textStyle, textPainter);
      }
    }
  }

  /// Helper to draw text on canvas.
  void _drawText(
    Canvas canvas,
    String text,
    Offset point,
    TextStyle style,
    TextPainter textPainter,
  ) {
    textPainter.text = TextSpan(text: text, style: style);
    textPainter.layout();
    textPainter.paint(canvas, point - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  /// Checks if landmark is part of the head.
  bool _isHeadLandmark(PoseLandmarkType type) {
    return [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.leftEyeInner,
      PoseLandmarkType.rightEyeInner,
      PoseLandmarkType.leftEyeOuter,
      PoseLandmarkType.rightEyeOuter,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
    ].contains(type);
  }

  /// Checks if landmark is part of limbs (arms/legs).
  bool _isLimbLandmark(PoseLandmarkType type) {
    return [
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
      PoseLandmarkType.leftThumb,
      PoseLandmarkType.rightThumb,
      PoseLandmarkType.leftIndex,
      PoseLandmarkType.rightIndex,
      PoseLandmarkType.leftPinky,
      PoseLandmarkType.rightPinky,
    ].contains(type);
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.poses != poses ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.widgetSize != widgetSize ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showAngles != showAngles;
  }
}
