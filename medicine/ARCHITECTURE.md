# System Architecture

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       Flutter Mobile App (Android)              │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────────┐ │
│  │ Home Screen  │  │ Add Medicine│  │ Take Medicine Screen   │ │
│  │              │  │             │  │  (Live Camera + ML)    │ │
│  │ - Slots      │  │ - Camera    │  │ - Anti-spoof motion   │ │
│  │ - Medicines  │  │ - ML embed  │  │ - Verify with embeddings
│  │ - History    │  │ - Upload    │  │ - Mark as taken       │ │
│  └──────────────┘  └─────────────┘  └────────────────────────┘ │
│                                                                  │
│  Services Layer:                                                │
│  ┌──────────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │ FirebaseService  │  │  MLService   │  │NotificationService│ │
│  │                  │  │              │  │                  │ │
│  │ - CRUD users     │  │ - Load model │  │ - Schedule local │ │
│  │ - Upload to      │  │ - Extract    │  │   notifications  │ │
│  │   Storage        │  │   embeddings │  │ - Handle delivery
│  │ - Query Firestore│  │ - Compare    │  │                  │ │
│  │ - Mark medicine  │  │   similarity │  │                  │ │
│  │   as taken/miss  │  │              │  │                  │ │
│  └──────────────────┘  └──────────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
           │                           │
           │  REST/WebSocket           │
           ▼                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Google Firebase                          │
│  ┌──────────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │  Cloud Firestore │  │   Storage   │  │Cloud Messaging  │  │
│  │                  │  │             │  │                  │  │
│  │ /users/{userId}  │  │/medicines/  │  │ FCM Tokens       │  │
│  │ /medicineLogs/   │  │  {userId}/  │  │ Push Notifications
│  │                  │  │  images     │  │                  │  │
│  │ Real-time sync   │  │             │  │                  │  │
│  └──────────────────┘  └─────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
           │
           │  Firestore Listener
           ▼
┌─────────────────────────────────────────────────────────────────┐
│            Node.js WhatsApp Bot (24/7 running)                 │
│  ┌──────────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │  Firebase Listener│  │ WhatsApp    │  │     Logger       │  │
│  │                  │  │  Client     │  │                  │  │
│  │ Watch for:       │  │             │  │ - Logs all events│  │
│  │ - missed=true    │  │ - QR login  │  │ - Error tracking │  │
│  │ - whatsappSent=0 │  │ - Stay login│  │ - Message status │  │
│  │                  │  │ - Send msg  │  │                  │  │
│  │ Trigger alert on │  │             │  │ → logs/combined. │  │
│  │ match            │  │             │  │   log            │  │
│  └──────────────────┘  └─────────────┘  └──────────────────┘  │
│                                                                  │
│  Message Flow:                                                  │
│  1. Detect missed medicine in Firestore                         │
│  2. Get user phone from users/{userId}.parentPhone              │
│  3. Compose WhatsApp message                                    │
│  4. Send via whatsapp-web.js                                    │
│  5. Update Firestore whatsappSent=true (prevent duplicates)     │
└─────────────────────────────────────────────────────────────────┘
           │
           ▼
    📱 Parent Phone
    (receives WhatsApp alert)
```

---

## Data Flow

### Adding a Medicine

```
1. User in AddMedicineScreen
   ├─ Take 3-5 photos with camera
   ├─ Anti-spoof: motion detection between frames
   ├─ Extract embeddings from each image
   │   └─ MLService.extractEmbedding(file) → List<double>
   │
2. Upload to Firebase
   ├─ Storage: medicine/{userId}/{slot}/{medicineId}/ref_0.jpg
   ├─ Storage: medicine/{userId}/{slot}/{medicineId}/ref_1.jpg
   │   └─ Get download URLs
   │
3. Save to Firestore
   └─ users/{userId}.slots.{slot}.medicines[]
      {
        id: "uuid"
        name: "Aspirin 500mg"
        imageUrls: ["url1", "url2", ...]
        embeddings: [[0.1, 0.2, ...], [...], ...]
        createdAt: timestamp
      }
```

### Taking a Medicine (Verification)

```
1. User in TakeMedicineScreen
   ├─ Capture 3 frames with phone motion
   │   └─ Anti-spoof: ensure movement between frames
   │
2. Extract embedding from final frame
   └─ MLService.extractEmbedding(capturedImage) → List<double>
   
3. Compare against all reference embeddings
   ├─ For each medicine in slot:
   │   └─ Cosine similarity between captured vs each reference
   │
4. Find best match
   ├─ Threshold check: similarity >= 0.75
   │
5. Result
   ├─ ✅ MATCH: Mark medicine as taken
   │  └─ Create MedicineLog: {taken: true, missed: false}
   │
   └─ ❌ NO MATCH: Retry or skip
      └─ Show confidence score
      
6. Firestore update
   └─ medicineLogs/{logId} created with timestamp
```

### Missed Medicine Detection

```
1. Time-based (automatic)
   ├─ Slot end time: 10:00 AM
   ├─ If no medicine log for today & slot
   │   └─ Mark as missed in background
   │
2. Firestore update
   └─ medicineLogs/{logId}
      {
        userId: "user123"
        slot: "morning"
        taken: false
        missed: true
        whatsappSent: false  ← Node.js watches this
        createdAt: timestamp
      }
      
3. Node.js bot detects
   ├─ Firestore listener triggers
   ├─ Get user: users/{userId}
   │   └─ Extract: name, parentPhone, slot times
   │
4. Compose message
   └─ "🚨 Medicine Alert\n\nAlin did NOT take Morning Medicine..."
   
5. Send WhatsApp
   ├─ whatsapp-web.js.sendMessage(parentPhone, message)
   │
6. Mark as sent
   └─ medicineLogs/{logId}.whatsappSent = true
      (prevents duplicate alerts)
```

---

## Database Schema

### Firestore Collections

```
/users
  /{userId}
    ├─ id: string
    ├─ name: string
    ├─ parentPhone: string
    ├─ slots: object
    │  ├─ morning: object
    │  │  ├─ name: string
    │  │  ├─ startTime: string ("HH:mm")
    │  │  ├─ endTime: string ("HH:mm")
    │  │  └─ medicines: array
    │  │     ├─ {id, name, imageUrls[], embeddings[][], createdAt}
    │  │     └─ ...
    │  ├─ afternoon: object (same structure)
    │  └─ night: object (same structure)
    ├─ createdAt: timestamp
    └─ updatedAt: timestamp

/medicineLogs
  /{logId}
    ├─ id: string
    ├─ userId: string
    ├─ slot: string
    ├─ taken: boolean
    ├─ timestamp: timestamp (when taken)
    ├─ missed: boolean
    ├─ whatsappSent: boolean
    ├─ createdAt: timestamp
    └─ updatedAt: timestamp
```

### Firebase Storage

```
/medicines
  /{userId}
    /{slotName}
      /{medicineId}
        ├─ ref_0.jpg (224x224, ~50KB)
        ├─ ref_1.jpg
        ├─ ref_2.jpg
        ├─ ref_3.jpg
        └─ ref_4.jpg
```

---

## Services Architecture

### FirebaseService (Singleton)

```dart
FirebaseService
├─ Initialize Firebase SDK
├─ Manage Firestore operations
│  ├─ createUser()
│  ├─ getUser()
│  ├─ setMedicineSlot()
│  ├─ addMedicine()
│  ├─ deleteMedicine()
│  ├─ createMedicineLog()
│  ├─ markMedicineAsTaken()
│  ├─ markMedicineAsMissed()
│  └─ getMedicineLogs()
├─ Manage Storage operations
│  └─ Upload images with putFile()
├─ Manage Messaging
│  ├─ requestNotificationPermission()
│  └─ getDeviceFCMToken()
└─ Stream operations
   ├─ streamUser(userId)
   └─ streamMissedMedicines()
```

### MLService (Singleton)

```dart
MLService
├─ TensorFlow Lite Interpreter
├─ loadModel() → Load medicine_embedder.tflite
├─ Image Processing
│  ├─ extractEmbedding(imageFile) → List<double>
│  └─ extractEmbeddingsFromImages(files) → List<List<double>>
├─ Embedding Comparison
│  ├─ cosineSimilarity(emb1, emb2) → double [0, 1]
│  └─ compareAgainstReferences() → best match
└─ Medicine Verification
   └─ verifyMedicine() → {isMatch, confidence, medicineId}
```

### NotificationService (Singleton)

```dart
NotificationService
├─ initialize() → Set up flutter_local_notifications
├─ Schedule notifications
│  ├─ scheduleNotification(title, body, DateTime)
│  ├─ scheduleDailyNotification(hour, minute)
│  └─ scheduleMedicineSlotNotification(slot, startTime)
└─ Cancel notifications
   ├─ cancelNotification(id)
   └─ cancelAllNotifications()
```

---

## Node.js Backend Architecture

### Firebase Module

```typescript
firebase.ts
├─ setupMissedMedicineListener()
│  └─ onSnapshot(medicineLogs where missed=true)
│     └─ Calls onMissedMedicine callback for each
├─ markWhatsappAsSent(logId)
│  └─ Update Firestore to prevent duplicates
├─ getPendingMissedMedicines()
│  └─ Query all unmailed missed logs
└─ getUser(userId)
   └─ Fetch user details (name, phone, slots)
```

### WhatsApp Module

```typescript
whatsapp.ts
├─ initializeWhatsAppClient()
│  ├─ Create Client with LocalAuth strategy
│  ├─ Handle QR for initial login
│  ├─ Store session locally
│  └─ Listen for ready/disconnect events
├─ sendWhatsAppMessage(phone, message)
│  └─ Format phone and send via whatsapp-web.js
├─ closeWhatsAppClient()
├─ isWhatsAppReady() → boolean
└─ getWhatsAppInfo()
```

### Main Entry Point

```typescript
index.ts
├─ Initialize Firebase Admin SDK
├─ Initialize WhatsApp Client
├─ Set up Firestore listener for missed medicines
├─ Handle incoming alerts
│  ├─ Get user details
│  ├─ Compose message
│  ├─ Send WhatsApp
│  └─ Mark as sent
├─ Error handling & logging
└─ Graceful shutdown (SIGINT/SIGTERM)
```

---

## Security Architecture

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User data - only user can read/write own
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Medicine logs - only user can read/write own
    match /medicineLogs/{logId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow write: if request.auth.uid == resource.data.userId;
    }
  }
}
```

### Storage Security Rules

```javascript
service firebase.storage {
  match /b/{bucket}/o {
    // Only users can upload to their own directory
    match /medicines/{userId}/{slotName}/{medicineId}/{filename} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId
        && request.resource.size <= 5 * 1024 * 1024  // 5MB
        && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

## ML Model Integration

### Embedding Extraction

```
Image → Resize (224×224) → Normalize [0, 1] 
  → TFLite Interpreter → Output Layer (128D)
  → L2 Normalize → Embedding Vector
```

### Similarity Matching

```
Captured Embedding vs Reference Embeddings
├─ Cosine Similarity for each reference
├─ Find maximum similarity
├─ Compare to threshold (default: 0.75)
└─ Return: isMatch, confidence, medicineId
```

---

## Deployment Architecture

### Flutter App
- Runs on Android 8.0+
- Target API 34+
- Requires: Camera, Storage, Notifications permissions

### Node.js Bot
- Runs 24/7 on laptop/Raspberry Pi/VPS
- Minimum: 512MB RAM, 1GB storage
- Network: Persistent internet connection required
- Deployment: PM2, systemd, or Docker

### Firebase Backend
- Serverless (no maintenance)
- Auto-scaling
- Free tier: 50K reads/writes per day
- Regional Firestore for lowest latency

---

## Error Handling

### Flutter App
- Try-catch in all service operations
- User-facing error messages via SnackBar
- Logging to console (debug) and files (production)

### Node.js Bot
- Winston logger with file rotation
- Error recovery: Auto-reconnect for WhatsApp/Firestore
- Graceful shutdown on SIGINT/SIGTERM
- Health check: Periodic Firestore query

### Firestore
- Retry logic for transient failures
- Validation on write operations
- Security rules prevent invalid data

