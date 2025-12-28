import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

/// Main entry point of the Posture Analysis app.
/// 
/// This app uses Google ML Kit Pose Detection to analyze human posture in real-time
/// through the device camera, providing feedback on posture quality.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request camera permission before initializing cameras
  final hasPermission = await _requestCameraPermission();
  if (!hasPermission) {
    runApp(const _PermissionDeniedApp());
    return;
  }

  // Get available cameras
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    runApp(const _NoCameraApp());
    return;
  }

  runApp(MyApp(cameras: cameras));
}

/// Requests camera and activity recognition permissions from the user.
/// 
/// Returns true if all required permissions are granted, false otherwise.
Future<bool> _requestCameraPermission() async {
  // Request camera permission
  final cameraStatus = await Permission.camera.request();
  
  // Request activity recognition permission (for gait analysis)
  final activityStatus = await Permission.activityRecognition.request();
  
  return cameraStatus.isGranted && activityStatus.isGranted;
}

/// App widget shown when camera permission is denied.
class _PermissionDeniedApp extends StatelessWidget {
  const _PermissionDeniedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Analysis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Posture Analysis'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app needs camera access to analyze your posture. '
                  'Please grant camera permission in your device settings.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App widget shown when no cameras are available.
class _NoCameraApp extends StatelessWidget {
  const _NoCameraApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Analysis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Posture Analysis'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 24),
                Text(
                  'No Camera Available',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'No cameras were found on this device. '
                  'Please use a device with a camera.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main application widget.
class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Analysis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}
