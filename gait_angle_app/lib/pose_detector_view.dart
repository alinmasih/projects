import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'utils/angle_utils.dart';

class PoseDetectorView extends StatefulWidget {
  const PoseDetectorView({super.key});

  @override
  State<PoseDetectorView> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Initializing...';
  double? _kneeAngle;
  List<double> _angleHistory = [];
  static const int _historySize = 5; // For smoothing

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final permissionStatus = await Permission.camera.request();
      if (!permissionStatus.isGranted) {
        setState(() {
          _statusMessage = 'Camera permission denied';
        });
        return;
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _statusMessage = 'No cameras available';
        });
        return;
      }

      // Prefer rear camera, fallback to first available
      CameraDescription? selectedCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }
      selectedCamera ??= cameras.first;

      // Initialize camera controller
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Initialize pose detector
      final options = PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      );
      _poseDetector = PoseDetector(options: options);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Ready';
        });
        _startImageStream();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) {
      if (!_isProcessing) {
        _processImage(image);
      }
    });
  }

  Future<void> _processImage(CameraImage image) async {
    if (_poseDetector == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final angle = calculateKneeAngle(pose);
        
        if (angle != null) {
          setState(() {
            _kneeAngle = _smoothAngle(angle);
          });
        } else {
          setState(() {
            _kneeAngle = null;
          });
        }
      } else {
        setState(() {
          _kneeAngle = null;
        });
      }
    } catch (e) {
      // Handle errors silently to avoid spam
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final rotation = InputImageRotation.rotation0deg;
    final format = InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  double _smoothAngle(double newAngle) {
    _angleHistory.add(newAngle);
    if (_angleHistory.length > _historySize) {
      _angleHistory.removeAt(0);
    }

    // Calculate average for smoothing
    final sum = _angleHistory.reduce((a, b) => a + b);
    return sum / _angleHistory.length;
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_isInitialized && _cameraController != null)
              SizedBox.expand(
                child: CameraPreview(_cameraController!),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SpinKitFadingCircle(
                      color: Colors.white,
                      size: 50.0,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            // Angle display overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _kneeAngle != null
                          ? 'Knee Angle: ${_kneeAngle!.toStringAsFixed(1)}°'
                          : 'Knee Angle: --',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (_kneeAngle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _getAngleDescription(_kneeAngle!),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAngleDescription(double angle) {
    if (angle < 30) {
      return 'Fully Extended';
    } else if (angle < 60) {
      return 'Slightly Flexed';
    } else if (angle < 90) {
      return 'Moderately Flexed';
    } else if (angle < 120) {
      return 'Well Flexed';
    } else if (angle < 150) {
      return 'Highly Flexed';
    } else {
      return 'Maximum Flexion';
    }
  }
}

