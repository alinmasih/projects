import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'utils/angle_utils.dart';

class VideoPoseAnalysisView extends StatefulWidget {
  const VideoPoseAnalysisView({super.key});

  @override
  State<VideoPoseAnalysisView> createState() => _VideoPoseAnalysisViewState();
}

class _VideoPoseAnalysisViewState extends State<VideoPoseAnalysisView> {
  VideoPlayerController? _videoController;
  PoseDetector? _poseDetector;
  File? _selectedVideo;
  bool _isAnalyzing = false;
  bool _isVideoSelected = false;
  double _analysisProgress = 0.0;
  List<double> _angleResults = [];
  double? _averageAngle;
  String _statusMessage = 'Select a video to analyze';

  @override
  void initState() {
    super.initState();
    _initializePoseDetector();
  }

  void _initializePoseDetector() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<void> _pickVideo() async {
    // Request storage permission
    PermissionStatus permissionStatus;
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted ||
          await Permission.photos.isGranted ||
          await Permission.videos.isGranted) {
        permissionStatus = PermissionStatus.granted;
      } else {
        permissionStatus = await Permission.videos.request();
        if (permissionStatus.isDenied) {
          permissionStatus = await Permission.storage.request();
        }
      }
    } else {
      permissionStatus = await Permission.photos.request();
    }

    if (!permissionStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to select videos'),
          ),
        );
      }
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _isVideoSelected = true;
          _statusMessage = 'Video selected. Tap to analyze.';
          _angleResults.clear();
          _averageAngle = null;
          _analysisProgress = 0.0;
        });

        // Initialize video player
        _videoController?.dispose();
        _videoController = VideoPlayerController.file(_selectedVideo!);
        await _videoController!.initialize();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking video: $e'),
          ),
        );
      }
    }
  }

  Future<void> _analyzeVideo() async {
    if (_selectedVideo == null || _poseDetector == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0.0;
      _angleResults.clear();
      _averageAngle = null;
      _statusMessage = 'Analyzing video frames...';
    });

    try {
      final duration = _videoController!.value.duration;
      final totalSeconds = duration.inMilliseconds / 1000.0;
      const frameInterval = 0.5; // Analyze every 0.5 seconds (2 fps for performance)
      final totalFrames = (totalSeconds / frameInterval).ceil();

      // Get temp directory for storing extracted frames
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < totalFrames; i++) {
        if (!mounted || !_isAnalyzing) break;

        final timeMs = (i * frameInterval * 1000).round();

        // Extract frame at specific timestamp
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: _selectedVideo!.path,
          thumbnailPath: '${tempDir.path}/frame_$i.jpg',
          timeMs: timeMs,
          quality: 75,
        );

        if (thumbnailPath != null) {
          final frameFile = File(thumbnailPath);
          if (await frameFile.exists()) {
            final angle = await _extractAngleFromFrame(frameFile);
            if (angle != null) {
              _angleResults.add(angle);
            }
            // Clean up frame file
            try {
              await frameFile.delete();
            } catch (_) {
              // Ignore cleanup errors
            }
          }
        }

        setState(() {
          _analysisProgress = (i + 1) / totalFrames;
        });
      }

      // Calculate average angle
      if (_angleResults.isNotEmpty) {
        final sum = _angleResults.reduce((a, b) => a + b);
        setState(() {
          _averageAngle = sum / _angleResults.length;
          _statusMessage = 'Analysis complete!';
        });
      } else {
        setState(() {
          _statusMessage = 'No valid angles detected in video';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error analyzing video: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<double?> _extractAngleFromFrame(File frameFile) async {
    try {
      final inputImage = InputImage.fromFile(frameFile);
      final poses = await _poseDetector!.processImage(inputImage);
      
      if (poses.isNotEmpty) {
        return calculateKneeAngle(poses.first);
      }
    } catch (e) {
      // Handle errors silently
    }
    return null;
  }

  void _resetAnalysis() {
    setState(() {
      _isAnalyzing = false;
      _analysisProgress = 0.0;
      _angleResults.clear();
      _averageAngle = null;
      _statusMessage = 'Select a video to analyze';
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video Analysis'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Video preview section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Colors.grey[900],
                child: _videoController != null &&
                        _videoController!.value.isInitialized
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio:
                                _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                          if (!_isAnalyzing)
                            IconButton(
                              icon: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 48,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_videoController!.value.isPlaying) {
                                    _videoController!.pause();
                                  } else {
                                    _videoController!.play();
                                  }
                                });
                              },
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // Control and analysis section
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  if (_isAnalyzing)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: _analysisProgress,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(_analysisProgress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _pickVideo,
                        icon: const Icon(Icons.video_library),
                        label: const Text('Select Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: (_isAnalyzing || !_isVideoSelected)
                            ? null
                            : _analyzeVideo,
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.analytics),
                        label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Results section
                  if (_averageAngle != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Analysis Results',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Average Knee Angle: ${_averageAngle!.toStringAsFixed(1)}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Valid frames: ${_angleResults.length}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_angleResults.isNotEmpty && !_isAnalyzing) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _resetAnalysis,
                      child: const Text('Reset Analysis'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

