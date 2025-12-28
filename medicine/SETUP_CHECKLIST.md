# Setup Checklist

Complete this checklist to get the system running end-to-end.

## ✅ Pre-requisites
- [ ] Flutter 3.0+ installed
- [ ] Android SDK 34+ configured
- [ ] Node.js 18+ installed
- [ ] Firebase account (free tier OK)
- [ ] WhatsApp account for bot (uses WhatsApp Web)

---

## ✅ Firebase Project Setup

### Create Project
- [ ] Go to https://console.firebase.google.com
- [ ] Click "Create project"
- [ ] Name it "medicine-tracker" (or preferred name)
- [ ] Accept Google Analytics (optional)

### Enable Services
- [ ] Firestore Database
  - [ ] Choose "Production mode"
  - [ ] Select region closest to you
- [ ] Cloud Storage
  - [ ] Create storage bucket
- [ ] Cloud Messaging
  - [ ] Copy "Server API Key" for reference
- [ ] Authentication (optional, for security)
  - [ ] Enable Email/Password or Anonymous

### Download Credentials
- [ ] Project Settings → Service Accounts
- [ ] Generate new private key
- [ ] Save as `server/firebase-credentials.json`
- [ ] **IMPORTANT**: Add to `.gitignore` (never commit)

---

## ✅ Flutter App Setup

### Configuration
- [ ] `cd app`
- [ ] `dart pub global activate flutterfire_cli`
- [ ] `flutterfire configure`
  - [ ] Select Firebase project
  - [ ] Choose Android platform
- [ ] Verify `lib/firebase_options.dart` was generated
- [ ] Download `google-services.json` from Firebase
- [ ] Place in `android/app/google-services.json`

### Dependencies
- [ ] `flutter pub get`
- [ ] Verify all packages resolve (no red errors)

### Test Run
- [ ] Connect Android device or start emulator
- [ ] `flutter run`
- [ ] Sign in with test user ID and name
- [ ] Verify app launches and connects to Firestore

---

## ✅ ML Model Setup

### Obtain Model
- [ ] Download pre-trained embedder model from TensorFlow Hub
- [ ] Or convert your trained model to .tflite format
- [ ] Verify file: `medicine_embedder.tflite` (~10-50MB)

### Place in App
- [ ] Copy to `app/assets/models/medicine_embedder.tflite`
- [ ] Verify in `app/pubspec.yaml` assets section
- [ ] Run `flutter pub get` to bundle asset

### Verify Dimensions
- [ ] Check model input size (default: 224×224)
- [ ] Check model output size (default: 128D embedding)
- [ ] Update in `lib/services/ml_service.dart` if different

---

## ✅ Node.js Bot Setup

### Environment
- [ ] `cd server`
- [ ] `cp .env.example .env`
- [ ] Edit `.env`:
  - [ ] `FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json`
  - [ ] `WHATSAPP_SESSION_DIR=./whatsapp-session`
  - [ ] `LOG_LEVEL=info`
- [ ] Copy credentials: `cp ../server/firebase-credentials.json ./`

### Dependencies
- [ ] `npm install`
- [ ] Verify no critical errors

### WhatsApp Login (First Time)
- [ ] `npm run dev`
- [ ] QR code appears in terminal
- [ ] Open WhatsApp on your phone
- [ ] Scan QR code from terminal
- [ ] Bot logs in and saves session locally
- [ ] Press `Ctrl+C` to stop (session persists)

### Verify Setup
- [ ] Session stored in `whatsapp-session/`
- [ ] Logs created in `logs/combined.log`
- [ ] No errors in output

---

## ✅ Firebase Security Rules

### Deploy Rules
- [ ] `npm install -g firebase-tools` (global)
- [ ] `firebase login`
- [ ] `cd /path/to/medicine` (project root)
- [ ] `firebase deploy --only firestore:rules,storage:rules`
- [ ] Verify "Deploy complete" message

### Verify in Console
- [ ] Firestore → Rules → Check content matches `firestore.rules`
- [ ] Storage → Rules → Check content matches `storage.rules`

---

## ✅ Test Scenario 1: Add Medicine

### Steps
1. [ ] Open Flutter app
2. [ ] Sign in as test user
3. [ ] Home screen → Morning slot card → "Add Medicine"
4. [ ] Capture 3-5 photos of a pill bottle
5. [ ] Enter medicine name (e.g., "Aspirin 500mg")
6. [ ] Tap "Save Medicine"
7. [ ] Wait for upload (may take 30-60s)

### Verification
- [ ] Verify in Firestore:
  - [ ] `users/{userId}/slots/morning/medicines[]` has entry
  - [ ] `imageUrls[]` has 3+ URLs
  - [ ] `embeddings[]` has 3+ embedding vectors
- [ ] Verify in Storage:
  - [ ] `medicines/{userId}/morning/{medicineId}/` has images

---

## ✅ Test Scenario 2: Take Medicine

### Steps
1. [ ] Home screen → Morning slot → "Take Medicine"
2. [ ] Move phone slightly while holding (anti-spoof)
3. [ ] Tap "Verify Medicine (Live Photo)"
4. [ ] Capture 3 frames with motion
5. [ ] ML verifies against reference embeddings

### Verification
- [ ] See confirmation message with confidence score
- [ ] Check Firestore:
  - [ ] New document in `medicineLogs/`
  - [ ] `taken: true`, `timestamp: now`
  - [ ] `missed: false`

---

## ✅ Test Scenario 3: Missed Medicine Alert

### Steps
1. [ ] Configure morning slot: 8:00-10:00 AM
2. [ ] Manually set `missed: true` in Firestore for today's log
3. [ ] Node.js bot running: `npm start`
4. [ ] Check Node.js bot output

### Verification
- [ ] Bot logs: "Sending WhatsApp to {parentPhone}"
- [ ] Check WhatsApp on phone: Alert message received
- [ ] Firestore: `whatsappSent: true` auto-updated

---

## ✅ Production Deployment

### Flutter APK
- [ ] `cd app`
- [ ] `flutter build apk --release`
- [ ] Output: `app/build/app/outputs/apk/release/app-release.apk`
- [ ] Test on real device
- [ ] Upload to Google Play Store

### Node.js Bot (Keep Running 24/7)
- [ ] Option A: PM2
  - [ ] `npm install -g pm2`
  - [ ] `pm2 start "npm start" --name medicine-bot`
  - [ ] `pm2 save && pm2 startup`
  
- [ ] Option B: Systemd (Linux)
  - [ ] Copy `scripts/medicine-bot.service` to `/etc/systemd/system/`
  - [ ] `sudo systemctl daemon-reload`
  - [ ] `sudo systemctl enable medicine-bot`
  - [ ] `sudo systemctl start medicine-bot`
  
- [ ] Option C: Docker
  - [ ] Create Dockerfile
  - [ ] Build: `docker build -t medicine-bot .`
  - [ ] Run: `docker run -d medicine-bot`

### Monitoring
- [ ] Check bot logs: `tail -f logs/combined.log`
- [ ] Monitor bot uptime
- [ ] Set up health check (e.g., HTTP endpoint)

---

## ✅ Common Troubleshooting

### Flutter
- [ ] Camera permission denied → Check `AndroidManifest.xml`
- [ ] Firestore connection error → Verify `firebase_options.dart`
- [ ] ML model not found → Check `assets/models/` path in `pubspec.yaml`

### Node.js
- [ ] "WhatsApp not ready" → Scan QR code again
- [ ] "Firebase credentials not found" → Check `.env` path
- [ ] "Firestore listener not triggering" → Verify Firestore rules deployed

### General
- [ ] Check Firebase console for errors/usage
- [ ] Verify device has internet connection
- [ ] Check Firestore quota not exceeded
- [ ] Review security rules for permission errors

---

## ✅ Optional Enhancements

- [ ] Add Firebase Authentication
- [ ] Implement reminder notifications (1 hour before slot)
- [ ] Add medicine dosage/quantity tracking
- [ ] Support multiple family members
- [ ] Add medicine side effects/drug interactions database
- [ ] Create admin dashboard for monitoring
- [ ] Implement backup/export functionality
- [ ] Add SMS fallback alerts

---

## 📞 Support

If stuck:
1. Check `logs/combined.log` for bot errors
2. Review Firestore console for data state
3. Test manually in Firestore/Storage consoles
4. Verify all security rules deployed
5. Check Flutter logcat for app errors

**All done! System should be live.** 🎉
