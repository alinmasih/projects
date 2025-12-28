import 'dart:async';
import 'dart:collection';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Service for handling motion sensor data (accelerometer and gyroscope).
/// 
/// This service collects sensor data to analyze gait patterns, step detection,
/// cadence, and balance metrics for posture and gait analysis.
class SensorService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  
  final Queue<AccelerometerEvent> _accelHistory = Queue();
  final Queue<GyroscopeEvent> _gyroHistory = Queue();
  final int _maxHistorySize = 100; // Keep last 100 samples
  
  // Gait analysis metrics
  int _stepCount = 0;
  DateTime? _lastStepTime;
  final List<double> _stepIntervals = [];
  double _cadence = 0.0; // Steps per minute
  double _sway = 0.0; // Lateral sway magnitude
  
  // Current sensor values
  vm.Vector3 _currentAcceleration = vm.Vector3.zero();
  vm.Vector3 _currentGyroscope = vm.Vector3.zero();
  
  // Callbacks
  Function(vm.Vector3)? onAccelerationUpdate;
  Function(vm.Vector3)? onGyroscopeUpdate;
  Function(int)? onStepDetected;
  
  bool _isListening = false;

  /// Starts listening to accelerometer and gyroscope sensors.
  /// 
  /// Begins collecting sensor data for gait analysis.
  void startListening() {
    if (_isListening) return;
    
    _isListening = true;
    _stepCount = 0;
    _stepIntervals.clear();
    _lastStepTime = null;
    
    // Listen to accelerometer
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _currentAcceleration = vm.Vector3(event.x, event.y, event.z);
        _addAccelEvent(event);
        _detectStep(event);
        _calculateSway(event);
        onAccelerationUpdate?.call(_currentAcceleration);
      },
      onError: (error) {
        // Handle error silently
      },
      cancelOnError: false,
    );
    
    // Listen to gyroscope
    _gyroscopeSubscription = gyroscopeEventStream().listen(
      (GyroscopeEvent event) {
        _currentGyroscope = vm.Vector3(event.x, event.y, event.z);
        _addGyroEvent(event);
        onGyroscopeUpdate?.call(_currentGyroscope);
      },
      onError: (error) {
        // Handle error silently
      },
      cancelOnError: false,
    );
  }

  /// Stops listening to sensors.
  /// 
  /// Stops collecting sensor data and clears history.
  void stopListening() {
    _isListening = false;
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _accelHistory.clear();
    _gyroHistory.clear();
  }

  /// Adds accelerometer event to history.
  void _addAccelEvent(AccelerometerEvent event) {
    _accelHistory.add(event);
    if (_accelHistory.length > _maxHistorySize) {
      _accelHistory.removeFirst();
    }
  }

  /// Adds gyroscope event to history.
  void _addGyroEvent(GyroscopeEvent event) {
    _gyroHistory.add(event);
    if (_gyroHistory.length > _maxHistorySize) {
      _gyroHistory.removeFirst();
    }
  }

  /// Detects steps based on accelerometer data.
  /// 
  /// Uses peak detection algorithm on vertical acceleration to detect steps.
  void _detectStep(AccelerometerEvent event) {
    if (_accelHistory.length < 10) return;
    
    // Calculate magnitude of acceleration
    final magnitude = vm.Vector3(event.x, event.y, event.z).length;
    
    // Simple peak detection: look for significant upward acceleration
    // followed by downward (step impact pattern)
    if (_accelHistory.length >= 3) {
      final recent = _accelHistory.toList().reversed.take(3).toList();
      if (recent.length == 3) {
        final mag1 = vm.Vector3(recent[2].x, recent[2].y, recent[2].z).length;
        final mag2 = vm.Vector3(recent[1].x, recent[1].y, recent[1].z).length;
        final mag3 = magnitude;
        
        // Detect peak: middle value is higher than neighbors
        if (mag2 > mag1 && mag2 > mag3 && mag2 > 12.0) {
          final now = DateTime.now();
          if (_lastStepTime == null || 
              now.difference(_lastStepTime!).inMilliseconds > 300) {
            // Minimum 300ms between steps (max ~200 steps/min)
            _stepCount++;
            if (_lastStepTime != null) {
              final interval = now.difference(_lastStepTime!).inSeconds.toDouble();
              _stepIntervals.add(interval);
              if (_stepIntervals.length > 20) {
                _stepIntervals.removeAt(0);
              }
              _updateCadence();
            }
            _lastStepTime = now;
            onStepDetected?.call(_stepCount);
          }
        }
      }
    }
  }

  /// Calculates lateral sway from accelerometer data.
  /// 
  /// Measures side-to-side movement which indicates balance issues.
  void _calculateSway(AccelerometerEvent event) {
    // Calculate average sway over recent history
    if (_accelHistory.length >= 10) {
      final recent = _accelHistory.toList().reversed.take(10).toList();
      final avgSway = recent.map((e) => e.x.abs()).reduce((a, b) => a + b) / recent.length;
      _sway = avgSway;
    }
  }

  /// Updates cadence (steps per minute) based on step intervals.
  void _updateCadence() {
    if (_stepIntervals.isEmpty) {
      _cadence = 0.0;
      return;
    }
    
    final avgInterval = _stepIntervals.reduce((a, b) => a + b) / _stepIntervals.length;
    if (avgInterval > 0) {
      _cadence = 60.0 / avgInterval;
    }
  }

  /// Gets current step count.
  int get stepCount => _stepCount;

  /// Gets current cadence (steps per minute).
  double get cadence => _cadence;

  /// Gets current sway magnitude.
  double get sway => _sway;

  /// Gets current acceleration vector.
  vm.Vector3 get currentAcceleration => _currentAcceleration;

  /// Gets current gyroscope vector.
  vm.Vector3 get currentGyroscope => _currentGyroscope;

  /// Resets all gait metrics.
  void resetMetrics() {
    _stepCount = 0;
    _stepIntervals.clear();
    _lastStepTime = null;
    _cadence = 0.0;
    _sway = 0.0;
  }

  /// Gets gait session data as a map.
  /// 
  /// Useful for saving session reports.
  Map<String, dynamic> getSessionData() {
    return {
      'stepCount': _stepCount,
      'cadence': _cadence,
      'sway': _sway,
      'avgStepInterval': _stepIntervals.isEmpty 
          ? 0.0 
          : _stepIntervals.reduce((a, b) => a + b) / _stepIntervals.length,
      'totalSteps': _stepCount,
    };
  }

  /// Disposes the service and releases resources.
  void dispose() {
    stopListening();
  }
}

