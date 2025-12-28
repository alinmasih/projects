import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Service class for detecting human poses using Google ML Kit Pose Detection.
/// 
/// This service processes camera frames and detects pose keypoints in real-time.
/// It handles the pose detector lifecycle and provides pose detection results.
class PoseDetectorService {
  late final PoseDetector _poseDetector;
  bool _isProcessing = false;
  final int _targetFps = 15; // Process every ~15th frame for smooth performance
  int _frameCount = 0;

  /// Constructor that initializes the pose detector with default options.
  PoseDetectorService() {
    // Initialize pose detector with default options
    // You can customize options like detection mode and preferred hardward
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    );
    _poseDetector = PoseDetector(options: options);
  }

  /// Processes a camera image and detects poses.
  /// 
  /// [image] The camera image to process
  /// 
  /// Returns a list of detected poses, or empty list if no poses detected.
  /// Returns null if currently processing another frame (throttling).
  Future<List<Pose>?> processImage(CameraImage cameraImage) async {
    // Throttle processing to maintain smooth FPS
    _frameCount++;
    if (_frameCount % (30 ~/ _targetFps) != 0) {
      return null;
    }

    if (_isProcessing) {
      return null; // Skip if already processing
    }

    _isProcessing = true;

    try {
      // Convert CameraImage to InputImage
      final inputImage = _inputImageFromCameraImage(cameraImage);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      // Detect poses
      final poses = await _poseDetector.processImage(inputImage);
      _isProcessing = false;
      return poses;
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  /// Converts a CameraImage to InputImage format required by ML Kit.
  /// 
  /// [cameraImage] The camera image from the camera controller
  /// 
  /// Returns InputImage or null if conversion fails.
  InputImage? _inputImageFromCameraImage(CameraImage cameraImage) {
    try {
      // Determine image rotation based on platform and camera
      // For most cases, back camera uses 0deg, front camera uses 270deg on Android
      final imageRotation = InputImageRotation.rotation0deg;

      // Determine image format based on platform
      InputImageFormat format;
      if (Platform.isAndroid) {
        format = InputImageFormat.nv21; // Android typically uses YUV420
      } else if (Platform.isIOS) {
        // iOS uses BGRA8888 format
        format = InputImageFormat.bgra8888;
      } else {
        format = InputImageFormat.nv21; // Default fallback
      }

      // Get the first plane (Y plane for YUV, or the image data for BGRA)
      final plane = cameraImage.planes[0];
      
      // Create InputImageMetadata
      final metadata = InputImageMetadata(
        size: ui.Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: imageRotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      );

      // Create InputImage from bytes
      final inputImage = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: metadata,
      );

      return inputImage;
    } catch (e) {
      // Return null if conversion fails
      return null;
    }
  }

  /// Disposes the pose detector and releases resources.
  /// 
  /// Should be called when the service is no longer needed.
  Future<void> dispose() async {
    await _poseDetector.close();
  }
}

