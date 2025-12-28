# WiFi Voice App - Setup Guide

A Flutter-based voice calling application powered by Agora, Firebase, and Cloud Messaging.

## Prerequisites

- **Flutter SDK**: Version ^3.8.1 or higher ([Download](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: Included with Flutter
- **Firebase Account**: [Create one here](https://firebase.google.com/)
- **Agora Account**: [Sign up here](https://www.agora.io/)
- **Git**: For version control
- **IDE**: Android Studio, VS Code, or IntelliJ IDEA
- **Device/Emulator**: Android device/emulator or iOS simulator

### Platform-Specific Requirements

**Android:**
- Android SDK (API 24 or higher recommended)
- Android Studio or Android SDK tools

**iOS:**
- macOS
- Xcode 14.0 or higher
- CocoaPods

## Step 1: Clone & Install Dependencies

```bash
# Navigate to project directory
cd ~/calling

# Get all Flutter dependencies
flutter pub get

# Upgrade packages (optional)
flutter pub upgrade
```

## Step 2: Configure Firebase

### 2.1 Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a new project"
3. Follow the setup wizard
4. Note your **Project ID** (used in config.dart)

### 2.2 Add Android App to Firebase

1. In Firebase Console, select your project
2. Click **+ Add App** → Select **Android**
3. Enter package name: `com.example.wifi_voice_app`
4. Download `google-services.json`
5. Place it in `android/app/` directory
6. Register app and generate API key

### 2.3 Add iOS App to Firebase

1. Click **+ Add App** → Select **iOS**
2. Enter bundle ID: `com.example.wifi_voice_app`
3. Download `GoogleService-Info.plist`
4. Add to Xcode project: Open `ios/Runner.xcworkspace` and add the file to the Runner target
5. Generate OAuth 2.0 credentials and iOS client ID

### 2.4 Enable Firebase Services

In Firebase Console:
- **Authentication**: Enable Email/Password and Google Sign-in
- **Cloud Firestore**: Create database in production mode
- **Cloud Messaging**: Enable Firebase Messaging

## Step 3: Configure Agora

### 3.1 Create Agora Account

1. Go to [Agora Console](https://console.agora.io/)
2. Create a new account/project
3. Get your **App ID** from the project dashboard

### 3.2 Set Up Token Service (Optional but Recommended)

For production, deploy a token generation service using the Agora SDK:
- Example: [Cloud Function Token Service](https://github.com/AgoraIO/agora-token-service)
- Or use your own backend to generate tokens

## Step 4: Update Configuration

### 4.1 Edit `lib/config/config.dart`

Replace the placeholder values with your actual credentials:

```dart
class AppConfig {
  // Firebase Credentials
  static const String firebaseProjectId = 'your-project-id';
  static const String firebaseApiKey = 'YOUR_FIREBASE_WEB_API_KEY';
  static const String firebaseMessagingSenderId = 'YOUR_MESSAGING_SENDER_ID';
  static const String firebaseAndroidAppId = '1:YOUR_MESSAGING_SENDER_ID:android:GENERATED_ID';
  static const String firebaseIosAppId = '1:YOUR_MESSAGING_SENDER_ID:ios:GENERATED_ID';
  static const String firebaseAndroidClientId = 'YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com';
  static const String firebaseIosClientId = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

  // Agora Credentials
  static const String agoraAppId = 'YOUR_AGORA_APP_ID';
  static const String agoraTokenServiceUrl = 'https://your-token-service-url.com/agoraToken';

  // FCM Relay Endpoint (Cloud Function)
  static const String fcmRelayEndpoint = 'https://your-cloud-function-url.com/relayCallEvent';
}
```

**How to find these credentials:**
- Firebase API Key: Firebase Console → Project Settings → Web API Key
- Firebase Messaging Sender ID: Firebase Console → Project Settings → Cloud Messaging tab
- Firebase Client IDs: Firebase Console → Project Settings → OAuth 2.0 Client IDs
- Agora App ID: Agora Console → Project Management → App ID

## Step 5: Android Configuration

### 5.1 Update Gradle Files

Check `android/app/build.gradle.kts`:
- Ensure `minSdk` is at least 24
- Ensure `compileSdk` is at least 34

### 5.2 Add Permissions

Android permissions are already configured in `AndroidManifest.xml`. Verify they include:
- `android.permission.INTERNET`
- `android.permission.RECORD_AUDIO`
- `android.permission.CAMERA`
- `android.permission.BLUETOOTH`
- `android.permission.MODIFY_AUDIO_SETTINGS`

### 5.3 Build Android

```bash
# Clean build
flutter clean
flutter pub get

# Run on connected device/emulator
flutter run

# Or build APK
flutter build apk --release
```

## Step 6: iOS Configuration

### 6.1 Update Pod Dependencies

```bash
cd ios
pod repo update
pod install --repo-update
cd ..
```

### 6.2 Configure Info.plist

Open `ios/Runner/Info.plist` and ensure these keys exist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app requires microphone access for voice calls</string>

<key>NSCameraUsageDescription</key>
<string>This app requires camera access for video calls</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth for audio routing</string>
```

### 6.3 Build iOS

```bash
# Open workspace in Xcode
open ios/Runner.xcworkspace

# Or build from command line
flutter build ios --release
```

## Step 7: Deploy Cloud Functions

Create Firebase Cloud Functions to:
1. **Generate Agora Tokens**: `/agoraToken` endpoint
2. **Relay FCM Messages**: `/relayCallEvent` endpoint

Example Node.js implementation:

```javascript
// functions/index.js
const functions = require("firebase-functions");
const { RtcTokenBuilder, RtcRole } = require("agora-token");

const AGORA_APP_ID = "YOUR_AGORA_APP_ID";
const AGORA_APP_CERTIFICATE = "YOUR_AGORA_CERTIFICATE";

exports.agoraToken = functions.https.onCall((data, context) => {
  const uid = data.uid;
  const channelName = data.channelName;
  
  const token = RtcTokenBuilder.buildTokenWithUid(
    AGORA_APP_ID,
    AGORA_APP_CERTIFICATE,
    channelName,
    uid,
    RtcRole.PUBLISHER,
    Math.floor(Date.now() / 1000) + 3600
  );
  
  return { token };
});

exports.relayCallEvent = functions.https.onRequest(async (req, res) => {
  // Handle FCM relay logic here
  res.json({ success: true });
});
```

## Step 8: Running the App

### 8.1 Development Mode

```bash
# Run on connected device
flutter run

# Run on specific device
flutter run -d <device_id>

# List available devices
flutter devices
```

### 8.2 Production Build

**Android:**
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## Troubleshooting

### Common Issues

**Flutter doctor shows issues:**
```bash
flutter doctor -v
# Fix any reported issues
```

**Dependencies fail to install:**
```bash
flutter clean
flutter pub get
```

**Gradle build fails:**
```bash
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

**CocoaPods issues (iOS):**
```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install --repo-update
cd ..
```

**Firebase initialization errors:**
- Verify `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in correct locations
- Check configuration values in `config.dart` match Firebase console

**Agora connection issues:**
- Verify Agora App ID is correct
- Check network connectivity
- Ensure token service URL is accessible
- Verify permissions are granted on device

## Project Structure

```
lib/
├── main.dart              # Entry point, Firebase initialization
├── config/
│   └── config.dart        # Centralized configuration
├── models/
│   ├── user_model.dart    # User data model
│   └── call_model.dart    # Call state model
├── screens/
│   ├── login_screen.dart  # Authentication
│   ├── home_screen.dart   # Main home screen
│   └── call_screen.dart   # Active call screen
├── services/
│   ├── auth_service.dart  # Firebase Auth
│   ├── agora_service.dart # Agora SDK integration
│   ├── call_service.dart  # Call logic
│   └── fcm_service.dart   # Push notifications
└── widgets/               # Reusable UI components
```

## Key Features

- **Voice Calling**: Real-time audio via Agora SDK
- **User Authentication**: Firebase Authentication
- **Push Notifications**: Firebase Cloud Messaging
- **Call Incoming**: Native call interface (flutter_callkit_incoming)
- **Secure Storage**: Encrypted credential storage
- **User Management**: Cloud Firestore database

## Environment Variables (Optional)

Create `.env` file in project root for sensitive data:

```env
FIREBASE_PROJECT_ID=your-project-id
AGORA_APP_ID=your-agora-app-id
FCM_RELAY_URL=https://your-function-url.com
```

## Next Steps

1. Create test users in Firebase Authentication
2. Test calls between two devices
3. Verify Firebase and Agora connection logs
4. Deploy to beta/production
5. Monitor crash logs and analytics

## Support Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Agora Documentation](https://docs.agora.io/)
- [flutter_callkit_incoming](https://pub.dev/packages/flutter_callkit_incoming)
- [Agora RTC Engine for Flutter](https://pub.dev/packages/agora_rtc_engine)

## License

This project is private and not published to pub.dev.

---

**Last Updated:** November 28, 2025
