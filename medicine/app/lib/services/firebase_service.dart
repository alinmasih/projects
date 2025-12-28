import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/index.dart';

/// Service to handle all Firebase operations:
/// - Firestore CRUD for users, medicines, and logs
/// - Storage uploads for medicine images
/// - Cloud Messaging for push notifications
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  late FirebaseFirestore _firestore;
  late FirebaseStorage _storage;
  late FirebaseMessaging _messaging;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal() {
    _firestore = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;
    _messaging = FirebaseMessaging.instance;
  }

  // ========== USER OPERATIONS ==========

  /// Create or update user profile
  Future<void> createUser({
    required String userId,
    required String name,
    required String parentPhone,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'id': userId,
        'name': name,
        'parentPhone': parentPhone,
        'slots': {},
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  /// Get user by ID
  Future<User?> getUser(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      if (snapshot.exists) {
        return User.fromFirestore(snapshot.data() ?? {});
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      rethrow;
    }
  }

  /// Update user parent phone
  Future<void> updateUserPhone(String userId, String phoneNumber) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'parentPhone': phoneNumber,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error updating user phone: $e');
      rethrow;
    }
  }

  // ========== MEDICINE SLOT OPERATIONS ==========

  /// Create or update a medicine slot (morning/afternoon/night)
  Future<void> setMedicineSlot({
    required String userId,
    required String slotName,
    required String startTime,
    required String endTime,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'slots.$slotName': {
          'name': slotName,
          'startTime': startTime,
          'endTime': endTime,
          'medicines': [],
        },
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error setting medicine slot: $e');
      rethrow;
    }
  }

  // ========== MEDICINE OPERATIONS ==========

  /// Add a medicine to a slot with reference images
  /// @param userId: User ID
  /// @param slotName: "morning", "afternoon", or "night"
  /// @param medicineName: Name of the medicine
  /// @param imageFiles: 3-5 reference photos (File objects)
  /// @param embeddings: ML embeddings extracted from the images
  Future<String> addMedicine({
    required String userId,
    required String slotName,
    required String medicineName,
    required List<File> imageFiles,
    required List<List<double>> embeddings,
  }) async {
    try {
      // Upload all images to Firebase Storage
      final medicineId = _generateId();
      final imageUrls = <String>[];

      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        final ref = _storage.ref(
          'medicines/$userId/$slotName/$medicineId/ref_$i.jpg',
        );
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // Create medicine map
      final medicineMap = {
        'id': medicineId,
        'name': medicineName,
        'imageUrls': imageUrls,
        'embeddings': embeddings,
        'createdAt': DateTime.now(),
      };

      // Add to Firestore under the slot
      await _firestore.collection('users').doc(userId).update({
        'slots.$slotName.medicines': FieldValue.arrayUnion([medicineMap]),
        'updatedAt': DateTime.now(),
      });

      return medicineId;
    } catch (e) {
      debugPrint('Error adding medicine: $e');
      rethrow;
    }
  }

  /// Delete a medicine from a slot
  Future<void> deleteMedicine({
    required String userId,
    required String slotName,
    required String medicineId,
  }) async {
    try {
      final user = await getUser(userId);
      if (user == null) return;

      final slot = user.slots[slotName];
      if (slot == null) return;

      final updatedMedicines = slot.medicines
          .where((m) => m.id != medicineId)
          .map((m) => m.toFirestore())
          .toList();

      await _firestore.collection('users').doc(userId).update({
        'slots.$slotName.medicines': updatedMedicines,
        'updatedAt': DateTime.now(),
      });

      // Delete images from Storage
      await _storage.ref('medicines/$userId/$slotName/$medicineId').delete();
    } catch (e) {
      debugPrint('Error deleting medicine: $e');
      rethrow;
    }
  }

  // ========== MEDICINE LOG OPERATIONS ==========

  /// Create a medicine log entry
  /// Called when user takes medicine and ML verifies it
  Future<String> createMedicineLog({
    required String userId,
    required String slot,
    required bool taken,
    required bool missed,
  }) async {
    try {
      final logId = _generateId();
      await _firestore.collection('medicineLogs').doc(logId).set({
        'id': logId,
        'userId': userId,
        'slot': slot,
        'taken': taken,
        'timestamp': taken ? DateTime.now() : null,
        'missed': missed,
        'whatsappSent': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
      return logId;
    } catch (e) {
      debugPrint('Error creating medicine log: $e');
      rethrow;
    }
  }

  /// Mark medicine as taken
  Future<void> markMedicineAsTaken({
    required String logId,
  }) async {
    try {
      await _firestore.collection('medicineLogs').doc(logId).update({
        'taken': true,
        'timestamp': DateTime.now(),
        'missed': false,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error marking medicine as taken: $e');
      rethrow;
    }
  }

  /// Mark medicine as missed (called by background scheduler)
  Future<void> markMedicineAsMissed({
    required String userId,
    required String slot,
  }) async {
    try {
      // Check if log already exists for today
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final query = await _firestore
          .collection('medicineLogs')
          .where('userId', isEqualTo: userId)
          .where('slot', isEqualTo: slot)
          .where('createdAt', isGreaterThanOrEqualTo: dayStart)
          .where('createdAt', isLessThan: dayEnd)
          .get();

      if (query.docs.isEmpty) {
        // Create a new missed log
        final logId = _generateId();
        await _firestore.collection('medicineLogs').doc(logId).set({
          'id': logId,
          'userId': userId,
          'slot': slot,
          'taken': false,
          'timestamp': null,
          'missed': true,
          'whatsappSent': false,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
      } else {
        // Update existing log
        await _firestore
            .collection('medicineLogs')
            .doc(query.docs.first.id)
            .update({
          'missed': true,
          'updatedAt': DateTime.now(),
        });
      }
    } catch (e) {
      debugPrint('Error marking medicine as missed: $e');
      rethrow;
    }
  }

  /// Mark WhatsApp message as sent
  Future<void> markWhatsappAsSent(String logId) async {
    try {
      await _firestore.collection('medicineLogs').doc(logId).update({
        'whatsappSent': true,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error marking WhatsApp as sent: $e');
      rethrow;
    }
  }

  /// Get medicine logs for a user
  Future<List<MedicineLog>> getMedicineLogs(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('medicineLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => MedicineLog.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting medicine logs: $e');
      rethrow;
    }
  }

  // ========== NOTIFICATIONS ==========

  /// Request user permission for push notifications
  Future<void> requestNotificationPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('User granted provisional notification permission');
      } else {
        debugPrint('User declined notification permission');
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Get device FCM token (for testing/debugging)
  Future<String?> getDeviceFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  // ========== UTILITY METHODS ==========

  /// Generate unique ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Stream for monitoring missed medicines (for Node.js backend)
  Stream<QuerySnapshot> streamMissedMedicines() {
    return _firestore
        .collection('medicineLogs')
        .where('missed', isEqualTo: true)
        .where('whatsappSent', isEqualTo: false)
        .snapshots();
  }

  /// Stream for user updates
  Stream<DocumentSnapshot> streamUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
