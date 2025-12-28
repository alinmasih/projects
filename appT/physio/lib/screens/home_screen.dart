import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import '../services/pose_detector_service.dart';
import '../services/sensor_service.dart';
import '../services/gait_classifier_service.dart';
import '../utils/angle_utils.dart';
import '../widgets/pose_painter.dart';

/// Main screen for Posture, Gait & FMS Analysis.
/// 
/// This screen integrates:
/// - Real-time pose detection with 33 landmarks
/// - Motion sensor data (accelerometer, gyroscope)
/// - Gait classification using TFLite ML model
/// - Comprehensive posture and gait metrics
/// - Session recording and reporting
class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  PoseDetectorService? _poseDetectorService;
  SensorService? _sensorService;
  GaitClassifierService? _gaitClassifierService;
  
  List<Pose> _poses = [];
  bool _isDetecting = false;
  bool _isGaitSessionActive = false;
  bool _isInitialized = false;
  bool _showLabels = false;
  bool _showAngles = false;
  
  // Posture metrics
  String _postureFeedback = 'Position yourself in front of the camera';
  double? _headTiltAngle;
  double? _spineAngle;
  double? _leftKneeAngle;
  double? _rightKneeAngle;
  double? _hipSymmetry;
  
  // Gait metrics
  int _stepCount = 0;
  double _cadence = 0.0;
  double _sway = 0.0;
  String? _gaitClassification;
  double? _gaitConfidence;
  
  // Session data
  DateTime? _sessionStartTime;
  final List<Map<String, dynamic>> _sessionData = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeCamera();
  }

  /// Initializes all services (pose detector, sensors, gait classifier).
  Future<void> _initializeServices() async {
    _poseDetectorService = PoseDetectorService();
    _sensorService = SensorService();
    
    // Initialize gait classifier (optional - will work without model)
    _gaitClassifierService = GaitClassifierService();
    
    // Try to load TFLite model (optional)
    try {
      final loaded = await _gaitClassifierService!.loadModel('gait_quality.tflite');
      if (!loaded) {
        print('Gait model not found - ML classification disabled');
      }
    } catch (e) {
      print('Could not load gait model: $e');
    }
    
    // Set up sensor callbacks
    _sensorService!.onStepDetected = (count) {
      if (mounted) {
        setState(() {
          _stepCount = count;
        });
      }
    };
  }

  /// Initializes the camera controller.
  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras available')),
        );
      }
      return;
    }

    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startImageStream();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  /// Starts the image stream for pose detection.
  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (!_isDetecting || _poseDetectorService == null) {
        return;
      }

      final poses = await _poseDetectorService!.processImage(image);
      if (poses != null && mounted) {
        setState(() {
          _poses = poses;
          _analyzePosture(poses);
          _updateGaitMetrics(poses);
        });
      }
    });
  }

  /// Analyzes posture from detected poses.
  void _analyzePosture(List<Pose> poses) {
    if (poses.isEmpty) {
      setState(() {
        _postureFeedback = 'No pose detected. Position yourself in front of the camera.';
      });
      return;
    }

    final pose = poses.first;
    final landmarks = pose.landmarks;

    final leftEar = landmarks[PoseLandmarkType.leftEar];
    final rightEar = landmarks[PoseLandmarkType.rightEar];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    // Calculate average positions
    double? avgShoulderX, avgShoulderY;
    if (leftShoulder != null && rightShoulder != null) {
      avgShoulderX = (leftShoulder.x + rightShoulder.x) / 2;
      avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    }

    double? avgHipX, avgHipY;
    if (leftHip != null && rightHip != null) {
      avgHipX = (leftHip.x + rightHip.x) / 2;
      avgHipY = (leftHip.y + rightHip.y) / 2;
    }

    // Calculate angles
    if (leftEar != null && rightEar != null && 
        avgShoulderX != null && avgShoulderY != null && leftShoulder != null) {
      final virtualShoulder = PoseLandmark(
        type: PoseLandmarkType.leftShoulder,
        x: avgShoulderX,
        y: avgShoulderY,
        z: leftShoulder.z,
        likelihood: leftShoulder.likelihood,
      );
      _headTiltAngle = AngleUtils.calculateHeadTiltAngle(
        leftEar,
        virtualShoulder,
        rightEar,
      );
    }

    if (avgShoulderX != null && avgShoulderY != null && 
        avgHipX != null && avgHipY != null && 
        leftKnee != null && leftShoulder != null && leftHip != null) {
      final virtualShoulder = PoseLandmark(
        type: PoseLandmarkType.leftShoulder,
        x: avgShoulderX,
        y: avgShoulderY,
        z: leftShoulder.z,
        likelihood: leftShoulder.likelihood,
      );
      final virtualHip = PoseLandmark(
        type: PoseLandmarkType.leftHip,
        x: avgHipX,
        y: avgHipY,
        z: leftHip.z,
        likelihood: leftHip.likelihood,
      );
      _spineAngle = AngleUtils.calculateSpineAngle(
        virtualShoulder,
        virtualHip,
        leftKnee,
      );
    }

    if (leftHip != null && leftKnee != null && leftAnkle != null) {
      _leftKneeAngle = AngleUtils.calculateKneeAngle(leftHip, leftKnee, leftAnkle);
    }

    if (rightHip != null && rightKnee != null && rightAnkle != null) {
      _rightKneeAngle = AngleUtils.calculateKneeAngle(rightHip, rightKnee, rightAnkle);
    }

    if (leftHip != null && rightHip != null) {
      _hipSymmetry = AngleUtils.calculateHipSymmetry(leftHip, rightHip);
      if (_cameraController != null) {
        final imageHeight = _cameraController!.value.previewSize?.height ?? 1.0;
        _hipSymmetry = (_hipSymmetry! / imageHeight) * 100; // Convert to percentage
      }
    }

    // Determine feedback
    String feedback = 'Good posture';
    if (_headTiltAngle != null) {
      final headTiltDeviation = (_headTiltAngle! - 180).abs();
      if (headTiltDeviation > 15) {
        feedback = 'Leaning forward';
      }
    }
    if (_spineAngle != null) {
      final spineDeviation = (_spineAngle! - 180).abs();
      if (spineDeviation > 10) {
        feedback = 'Slouching';
      }
    }
    if (_hipSymmetry != null && _hipSymmetry! > 10) {
      feedback = 'Uneven stance';
    }

    setState(() {
      _postureFeedback = feedback;
    });
  }

  /// Updates gait metrics and runs ML classification.
  void _updateGaitMetrics(List<Pose> poses) {
    if (!_isGaitSessionActive || poses.isEmpty) return;

    // Update sensor metrics
    if (_sensorService != null) {
      setState(() {
        _cadence = _sensorService!.cadence;
        _sway = _sensorService!.sway;
      });
    }

    // Run gait classification if model is loaded
    if (_gaitClassifierService != null && _gaitClassifierService!.isLoaded) {
      // Prepare features for ML model
      final features = <double>[];
      
      // Normalize angles (0-1 range)
      if (_headTiltAngle != null) {
        features.add(GaitClassifierService.normalizeAngle(_headTiltAngle!));
      } else {
        features.add(0.5);
      }
      
      if (_spineAngle != null) {
        features.add(GaitClassifierService.normalizeAngle(_spineAngle!));
      } else {
        features.add(0.5);
      }
      
      if (_leftKneeAngle != null) {
        features.add(GaitClassifierService.normalizeAngle(_leftKneeAngle!));
      } else {
        features.add(0.5);
      }
      
      if (_rightKneeAngle != null) {
        features.add(GaitClassifierService.normalizeAngle(_rightKneeAngle!));
      } else {
        features.add(0.5);
      }
      
      // Hip symmetry (normalized)
      if (_hipSymmetry != null) {
        features.add((_hipSymmetry! / 100).clamp(0.0, 1.0));
      } else {
        features.add(0.0);
      }
      
      // Cadence (normalized)
      features.add(GaitClassifierService.normalizeCadence(_cadence));
      
      // Sway (normalized, assuming max 5.0)
      features.add((_sway / 5.0).clamp(0.0, 1.0));

      // Classify
      final result = _gaitClassifierService!.classifyGaitWithConfidence(features);
      if (result != null) {
        setState(() {
          _gaitClassification = result['classification'] as String?;
          _gaitConfidence = result['confidence'] as double?;
        });
      }
    }
  }

  /// Toggles pose detection on/off.
  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
      if (!_isDetecting) {
        _poses = [];
        _postureFeedback = 'Position yourself in front of the camera';
      }
    });
  }

  /// Starts a gait analysis session.
  void _startGaitSession() {
    setState(() {
      _isGaitSessionActive = true;
      _sessionStartTime = DateTime.now();
      _stepCount = 0;
      _sessionData.clear();
    });
    
    _sensorService?.resetMetrics();
    _sensorService?.startListening();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gait session started. Start walking!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Stops the gait analysis session.
  void _stopGaitSession() async {
    _sensorService?.stopListening();
    
    // Save session data
    if (_sessionStartTime != null) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      final sessionReport = {
        'startTime': _sessionStartTime!.toIso8601String(),
        'duration': sessionDuration.inSeconds,
        'stepCount': _stepCount,
        'avgCadence': _cadence,
        'avgSway': _sway,
        'gaitClassification': _gaitClassification ?? 'Unknown',
        'gaitConfidence': _gaitConfidence ?? 0.0,
        'postureMetrics': {
          'headTilt': _headTiltAngle,
          'spineAngle': _spineAngle,
          'leftKneeAngle': _leftKneeAngle,
          'rightKneeAngle': _rightKneeAngle,
          'hipSymmetry': _hipSymmetry,
        },
      };
      
      _sessionData.add(sessionReport);
      
      // Optionally save to file
      await _saveSessionReport(sessionReport);
    }
    
    setState(() {
      _isGaitSessionActive = false;
      _sessionStartTime = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gait session stopped. Report saved.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Saves session report to file.
  Future<void> _saveSessionReport(Map<String, dynamic> report) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gait_session_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(report));
      print('Session report saved to: ${file.path}');
    } catch (e) {
      print('Error saving session report: $e');
    }
  }

  /// Shows info dialog explaining the analysis.
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Posture & Gait Analysis Guide'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Posture Metrics:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Head Tilt: Angle between ears and shoulders\n'),
              const Text('• Spine Angle: Alignment from shoulder to hip to knee\n'),
              const Text('• Knee Angles: Left and right knee flexion\n'),
              const Text('• Hip Symmetry: Height difference between hips\n'),
              const SizedBox(height: 16),
              const Text(
                'Gait Metrics:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Step Count: Number of steps detected\n'),
              const Text('• Cadence: Steps per minute\n'),
              const Text('• Sway: Lateral balance measurement\n'),
              const Text('• Gait Classification: ML-based quality assessment\n'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetectorService?.dispose();
    _sensorService?.dispose();
    _gaitClassifierService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posture & Gait Analysis'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showLabels ? Icons.label : Icons.label_outline),
            onPressed: () => setState(() => _showLabels = !_showLabels),
            tooltip: 'Toggle Labels',
          ),
          IconButton(
            icon: Icon(_showAngles ? Icons.analytics : Icons.analytics_outlined),
            onPressed: () => setState(() => _showAngles = !_showAngles),
            tooltip: 'Toggle Angles',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Info',
          ),
        ],
      ),
      body: _isInitialized && _cameraController != null
          ? Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),
                // Pose overlay
                if (_isDetecting && _poses.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PosePainter(
                        poses: _poses,
                        imageSize: _cameraController!.value.previewSize ?? Size.zero,
                        widgetSize: MediaQuery.of(context).size,
                        showLabels: _showLabels,
                        showAngles: _showAngles,
                      ),
                    ),
                  ),
                // Metrics overlay
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMetricRow('Posture', _postureFeedback),
                        if (_headTiltAngle != null)
                          _buildMetricRow('Head Tilt', '${_headTiltAngle!.toStringAsFixed(1)}°'),
                        if (_spineAngle != null)
                          _buildMetricRow('Spine', '${_spineAngle!.toStringAsFixed(1)}°'),
                        if (_leftKneeAngle != null && _rightKneeAngle != null)
                          _buildMetricRow('Knees', 'L: ${_leftKneeAngle!.toStringAsFixed(1)}° R: ${_rightKneeAngle!.toStringAsFixed(1)}°'),
                        if (_hipSymmetry != null)
                          _buildMetricRow('Hip Symmetry', '${_hipSymmetry!.toStringAsFixed(1)}%'),
                        if (_isGaitSessionActive) ...[
                          const Divider(color: Colors.white54),
                          _buildMetricRow('Steps', '$_stepCount'),
                          _buildMetricRow('Cadence', '${_cadence.toStringAsFixed(1)} spm'),
                          _buildMetricRow('Sway', '${_sway.toStringAsFixed(2)}'),
                          if (_gaitClassification != null)
                            _buildMetricRow(
                              'Gait',
                              '$_gaitClassification (${(_gaitConfidence ?? 0.0 * 100).toStringAsFixed(0)}%)',
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Control buttons
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _toggleDetection,
                            icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
                            label: Text(_isDetecting ? 'Stop Detection' : 'Start Detection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDetecting ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (_isDetecting)
                            ElevatedButton.icon(
                              onPressed: _isGaitSessionActive ? _stopGaitSession : _startGaitSession,
                              icon: Icon(_isGaitSessionActive ? Icons.stop_circle : Icons.directions_walk),
                              label: Text(_isGaitSessionActive ? 'Stop Gait' : 'Start Gait'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isGaitSessionActive ? Colors.orange : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  /// Helper to build a metric row.
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
