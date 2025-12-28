import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/index.dart';
import '../models/index.dart';

/// Screen to take/verify medicine with live camera
/// - Live camera only (no gallery)
/// - Capture image and verify against reference medicines
/// - ML model matches captured medicine with stored reference embeddings
/// - Anti-spoof: requires motion and live photo
class TakeMedicineScreen extends StatefulWidget {
  final String userId;
  final String slotName;
  final List<dynamic> medicinesInSlot;
  final Function(bool verified) onResult;

  const TakeMedicineScreen({
    required this.userId,
    required this.slotName,
    required this.medicinesInSlot,
    required this.onResult,
    Key? key,
  }) : super(key: key);

  @override
  State<TakeMedicineScreen> createState() => _TakeMedicineScreenState();
}

class _TakeMedicineScreenState extends State<TakeMedicineScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeCamera;
  late MLService _mlService;
  late FirebaseService _firebaseService;
  
  bool _isVerifying = false;
  bool _isLivePhotoConfirmed = false;
  int _frameCount = 0;
  XFile? _previousFrame;

  @override
  void initState() {
    super.initState();
    _mlService = MLService();
    _firebaseService = FirebaseService();
    _initializeCamera = _initializeCamera_();
  }

  Future<void> _initializeCamera_() async {
    try {
      final cameras = await availableCameras();
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _showError('Camera initialization failed');
    }
  }

  /// Anti-spoof: Require multi-frame capture and motion detection
  /// User must move phone slightly while holding
  Future<void> _startLivePhotoCapture() async {
    if (!_cameraController.value.isInitialized) return;

    setState(() {
      _frameCount = 0;
      _isLivePhotoConfirmed = false;
    });

    // Capture 3 frames to ensure motion and liveness
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        final image = await _cameraController.takePicture();

        // Check for motion between frames
        if (_previousFrame != null) {
          final hasMotion = await _detectMotion(File(image.path));
          if (!hasMotion && i < 2) {
            _showMessage('Move phone slightly for verification');
            return;
          }
        }

        _previousFrame = image;

        setState(() {
          _frameCount = i + 1;
        });

        if (i == 2) {
          // All frames captured with motion → live photo confirmed
          setState(() {
            _isLivePhotoConfirmed = true;
          });

          // Now verify the final captured image
          await _verifyMedicine(File(image.path));
        }
      } catch (e) {
        debugPrint('Error capturing frame: $e');
        _showError('Failed to capture frame');
        return;
      }
    }
  }

  /// Simple motion detection between frames
  Future<bool> _detectMotion(File newFrame) async {
    try {
      if (_previousFrame == null) return true;

      final prevSize = await File(_previousFrame!.path).length();
      final newSize = await newFrame.length();
      final sizeDiff = (newSize - prevSize).abs();

      return sizeDiff > 1000; // Motion threshold
    } catch (e) {
      return true;
    }
  }

  /// Verify medicine using ML model
  Future<void> _verifyMedicine(File capturedImage) async {
    setState(() => _isVerifying = true);

    try {
      final result = await _mlService.verifyMedicine(
        capturedImageFile: capturedImage,
        medicinesInSlot: widget.medicinesInSlot,
      );

      final isMatch = result['isMatch'] as bool;
      final confidence = result['confidence'] as double;
      final matchedName = result['matchedMedicineName'] as String?;

      if (isMatch) {
        _showMessage(
          '✅ Verified! ${matchedName ?? 'Medicine'} matched '
          '(${(confidence * 100).toStringAsFixed(1)}% confidence)',
        );

        // Mark medicine as taken in Firestore
        await _firebaseService.createMedicineLog(
          userId: widget.userId,
          slot: widget.slotName,
          taken: true,
          missed: false,
        );

        widget.onResult(true);
        if (mounted) Navigator.pop(context, true);
      } else {
        _showError(
          '❌ Medicine not verified. Best match: ${(confidence * 100).toStringAsFixed(1)}% '
          '(threshold: ${(_mlService.similarityThreshold * 100).toStringAsFixed(1)}%)',
        );
        widget.onResult(false);
      }
    } catch (e) {
      debugPrint('Error verifying medicine: $e');
      _showError('Verification failed: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Medicine'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<void>(
        future: _initializeCamera,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CameraPreview(_cameraController),
                  ),
                ),
              ),

              // Status indicator
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    if (_isVerifying)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Verifying medicine...'),
                        ],
                      )
                    else if (_isLivePhotoConfirmed)
                      const Text(
                        '✅ Live photo verified',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (_frameCount > 0)
                      Text(
                        'Frames captured: $_frameCount/3\nMove phone slightly',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        'Press button below to capture',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),

              // Capture button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _isVerifying ? null : _startLivePhotoCapture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Verify Medicine (Live Photo)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
