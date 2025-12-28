import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Centralised configuration for Firebase, Agora, and FCM.
class AppConfig {
  static const String appName = 'WiFi Voice App';
  static const String packageName = 'com.example.wifi_voice_app';

  static const String firebaseProjectId = 'wificallingapp-15e87';
  static const String firebaseApiKey = 'YOUR_FIREBASE_WEB_API_KEY';
  static const String firebaseMessagingSenderId = 'YOUR_MESSAGING_SENDER_ID';
  static const String firebaseStorageBucket = '$firebaseProjectId.appspot.com';
  static const String firebaseAndroidAppId =
      '1:YOUR_MESSAGING_SENDER_ID:android:GENERATED_ID';
  static const String firebaseIosAppId =
      '1:YOUR_MESSAGING_SENDER_ID:ios:GENERATED_ID';
  static const String firebaseAndroidClientId =
      'YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com';
  static const String firebaseIosClientId =
      'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

  static const String agoraAppId = 'YOUR_AGORA_APP_ID';
  static const String agoraTokenServiceUrl =
      'https://your-cloud-function-url.example.com/agoraToken';

  /// HTTPS endpoint that relays FCM messages server-side (Cloud Function).
  static const String fcmRelayEndpoint =
      'https://your-cloud-function-url.example.com/relayCallEvent';

  static const FirebaseOptions firebaseOptionsAndroid = FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAndroidAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    storageBucket: firebaseStorageBucket,
    androidClientId: firebaseAndroidClientId,
  );

  static const FirebaseOptions firebaseOptionsApple = FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseIosAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    storageBucket: firebaseStorageBucket,
    iosClientId: firebaseIosClientId,
    iosBundleId: packageName,
  );

  static FirebaseOptions get firebaseOptions {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return firebaseOptionsApple;
      default:
        return firebaseOptionsAndroid;
    }
  }
}

/// Firestore collection names for a single source of truth.
abstract class FirestoreCollections {
  static const String users = 'users';
  static const String calls = 'calls';
}

/// Common FCM message types used by the app.
abstract class FcmMessageType {
  static const String callInvite = 'call_invite';
  static const String callCancel = 'call_cancel';
  static const String callAccept = 'call_accept';
  static const String callEnd = 'call_end';
}

/// Utility keys shared between FCM payloads and CallKit payloads.
abstract class CallPayloadKeys {
  static const String callId = 'call_id';
  static const String callerId = 'caller_id';
  static const String callerName = 'caller_name';
  static const String callerAvatar = 'caller_avatar';
  static const String calleeId = 'callee_id';
  static const String channelId = 'channel_id';
  static const String type = 'type';
  static const String timestamp = 'timestamp';
  static const String agoraToken = 'agora_token';
  static const String agoraUid = 'agora_uid';
}
