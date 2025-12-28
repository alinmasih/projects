import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/index.dart';

/// Screen to add a medicine by capturing 3-5 reference photos
/// NO gallery uploads allowed - camera only
class AddMedicineScreen extends StatefulWidget {
  final String userId;
  final String slotName;
  final VoidCallback onSuccess;

  const AddMedicineScreen({
    required this.userId,
    required this.slotName,
    required this.onSuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeCamera;
  final List<File> _capturedImages = [];
  final TextEditingController _medicineNameController =
      TextEditingController();
  late MLService _mlService;
  late FirebaseService _firebaseService;
  bool _isProcessing = false;

  // Anti-spoof: track motion between frames
  XFile? _previousFrame;

  @override
  void initState() {
    super.initState();
    _mlService = MLService();
    _firebaseService = FirebaseService();
    _initializeCamera = _initializeFlashCamera();
  }

  Future<void> _initializeFlashCamera() async {
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

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _showError('Failed to initialize camera');
    }
  }

  /// Capture single frame for anti-spoof motion detection
  Future<void> _captureFrame() async {
    if (!_cameraController.value.isInitialized) return;

    try {
      if (_capturedImages.length >= 5) {
        _showError('Maximum 5 photos allowed');
        return;
      }

      final image = await _cameraController.takePicture();
      final file = File(image.path);

      // Anti-spoof: Check for motion (simplified)
      // In production, use optical flow or pose detection
      if (_previousFrame != null) {
        final hasMotion = await _detectMotion(file);
        if (!hasMotion) {
          _showError('Slight phone movement required. Keep your phone steady but not too still.');
          return;
        }
      }

      _previousFrame = image;

      setState(() {
        _capturedImages.add(file);
      });

      _showMessage('Photo ${_capturedImages.length}/5 captured');
    } catch (e) {
      debugPrint('Error capturing frame: $e');
      _showError('Failed to capture photo');
    }
  }

  /// Simple motion detection (compare adjacent frames)
  /// Returns true if motion is detected
  Future<bool> _detectMotion(File newFrame) async {
    try {
      // Simplified: just check file size difference
      // In production, use image difference metrics or pose estimation
      if (_previousFrame == null) return true;

      final prevSize = await File(_previousFrame!.path).length();
      final newSize = await newFrame.length();
      final sizeDiff = (newSize - prevSize).abs();

      // If file size differs significantly, motion detected
      return sizeDiff > 1000; // Arbitrary threshold
    } catch (e) {
      return true; // Assume motion if check fails
    }
  }

  /// Remove a captured image from list
  void _removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  /// Process medicine: extract embeddings and save
  Future<void> _processMedicine() async {
    if (_medicineNameController.text.isEmpty) {
      _showError('Enter medicine name');
      return;
    }

    if (_capturedImages.length < 3) {
      _showError('Capture at least 3 photos');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Extract embeddings from all captured images
      final embeddings = await _mlService.extractEmbeddingsFromImages(
        _capturedImages,
      );

      // Save to Firebase
      await _firebaseService.addMedicine(
        userId: widget.userId,
        slotName: widget.slotName,
        medicineName: _medicineNameController.text,
        imageFiles: _capturedImages,
        embeddings: embeddings,
      );

      _showMessage('Medicine saved successfully!');
      widget.onSuccess();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error processing medicine: $e');
      _showError('Failed to save medicine');
    } finally {
      setState(() => _isProcessing = false);
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
    _medicineNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medicine'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<void>(
        future: _initializeCamera,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Camera error: ${snapshot.error}'),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Camera preview
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CameraPreview(_cameraController),
                    ),
                  ),
                ),

                // Capture button
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _captureFrame,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                      'Capture Photo (${_capturedImages.length}/5)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),

                const SizedBox(height: 16),

                // Captured images preview
                if (_capturedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Captured Photos',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: _capturedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Image.file(
                                  _capturedImages[index],
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Medicine name input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _medicineNameController,
                    decoration: InputDecoration(
                      labelText: 'Medicine Name',
                      hintText: 'e.g., Aspirin 500mg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Save button
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processMedicine,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save Medicine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
