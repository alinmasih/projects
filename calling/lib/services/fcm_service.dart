import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';
import 'auth_service.dart';
import 'call_service.dart';

/// Handles FCM permissions, tokens, foreground notifications, and relaying call
/// events to a backend endpoint that can talk to the FCM REST API securely.
class FcmService extends ChangeNotifier {
  FcmService();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final http.Client _httpClient = http.Client();

  CallService? _callService;

  String? _cachedToken;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  String? get currentToken => _cachedToken;

  Future<void> initialize({
    required AuthService authService,
    required CallService callService,
  }) async {
    if (_initialized) return;

    _callService = callService;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
      provisional: false,
    );

    _cachedToken = await _messaging.getToken();
    if (_cachedToken != null) {
      await authService.updateFcmToken(_cachedToken);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    _messaging.onTokenRefresh.listen((token) {
      _cachedToken = token;
      authService.updateFcmToken(token);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessage(initialMessage, isAppLaunch: true);
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _handleMessage(message);
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await _handleMessage(message, openedFromTray: true);
  }

  Future<void> _handleMessage(
    RemoteMessage message, {
    bool openedFromTray = false,
    bool isAppLaunch = false,
  }) async {
    final data = message.data;
    final type = data[CallPayloadKeys.type] as String?;

    switch (type) {
      case FcmMessageType.callInvite:
        await FlutterCallkitIncoming.showCallkitIncoming(
          _buildCallKitParams(data),
        );
        await _callService?.handleIncomingCall(data);
        break;
      case FcmMessageType.callCancel:
        await FlutterCallkitIncoming.endCall(data[CallPayloadKeys.callId]);
        await _callService?.handleCallCancelled(data);
        break;
      case FcmMessageType.callAccept:
        await _callService?.handleCallAccepted(data);
        break;
      case FcmMessageType.callEnd:
        await FlutterCallkitIncoming.endCall(data[CallPayloadKeys.callId]);
        await _callService?.handleCallEnded(data);
        break;
      default:
        debugPrint('Received unsupported FCM payload: $data');
    }

    if (openedFromTray || isAppLaunch) {
      await _callService?.openCallFromNotification(data);
    }
  }

  /// Sends a call event payload to a secure relay endpoint.
  Future<void> sendCallEvent({required Map<String, dynamic> data}) async {
    final uri = Uri.parse(AppConfig.fcmRelayEndpoint);
    final response = await _httpClient.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode >= 400) {
      debugPrint(
        'Failed to relay call event (${response.statusCode}): ${response.body}',
      );
    }
  }

  static CallKitParams _buildCallKitParams(Map<String, dynamic> data) {
    return CallKitParams(
      id: data[CallPayloadKeys.callId] as String?,
      nameCaller:
          data[CallPayloadKeys.callerName] as String? ?? 'Incoming Call',
      appName: AppConfig.appName,
      avatar: data[CallPayloadKeys.callerAvatar] as String?,
      handle: data[CallPayloadKeys.callerId] as String?,
      type: 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: data,
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
      ),
      ios: const IOSParams(handleType: 'number', supportsVideo: false),
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
      ),
    );
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final data = message.data;
    await FlutterCallkitIncoming.showCallkitIncoming(_buildCallKitParams(data));
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}
