import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/config.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import 'agora_service.dart';
import 'auth_service.dart';
import 'fcm_service.dart';

/// Orchestrates call invites, Agora channel management, and call logs.
class CallService extends ChangeNotifier {
  CallService({
    required AuthService authService,
    required AgoraService agoraService,
    required FcmService fcmService,
  }) : _authService = authService,
       _agoraService = agoraService,
       _fcmService = fcmService;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final http.Client _httpClient = http.Client();
  final Uuid _uuid = const Uuid();

  final AuthService _authService;
  final AgoraService _agoraService;
  final FcmService _fcmService;

  CallSession? _activeCall;
  String? _agoraToken;
  int? _localAgoraUid;

  bool _muted = false;
  bool _speakerOn = true;

  CallSession? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  bool get isMuted => _muted;
  bool get isSpeakerOn => _speakerOn;

  Stream<List<CallSession>> callLogsStream(String userId) {
    return _firestore
        .collection(FirestoreCollections.calls)
        .where('participants', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CallSession.fromDocument).toList(),
        );
  }

  Future<void> startCall(AppUser callee) async {
    final caller = _authService.currentUser;
    if (caller == null) {
      throw StateError('Cannot start a call when not authenticated.');
    }

    final callId = _uuid.v4();
    final channelId = callId;
    _localAgoraUid = _generateAgoraUid(caller.uid);
    _agoraToken = await _fetchAgoraToken(
      channelId: channelId,
      uid: _localAgoraUid!,
    );

    final call = CallSession(
      id: callId,
      channelId: channelId,
      callerId: caller.uid,
      callerName: caller.displayName,
      calleeId: callee.uid,
      calleeName: callee.displayName,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
      participants: [caller.uid, callee.uid],
    );

    _activeCall = call;

    await _firestore
        .collection(FirestoreCollections.calls)
        .doc(callId)
        .set(call.toMap());

    await _fcmService.sendCallEvent(
      data: {
        CallPayloadKeys.type: FcmMessageType.callInvite,
        CallPayloadKeys.callId: callId,
        CallPayloadKeys.channelId: channelId,
        CallPayloadKeys.callerId: caller.uid,
        CallPayloadKeys.callerName: caller.displayName,
        CallPayloadKeys.calleeId: callee.uid,
        CallPayloadKeys.timestamp: DateTime.now().millisecondsSinceEpoch,
      },
    );

    notifyListeners();
  }

  Future<void> acceptActiveCall() async {
    final call = _activeCall;
    final user = _authService.currentUser;
    if (call == null || user == null) return;

    _localAgoraUid = _generateAgoraUid(user.uid);
    _agoraToken = await _fetchAgoraToken(
      channelId: call.channelId,
      uid: _localAgoraUid!,
    );

    await _fcmService.sendCallEvent(
      data: {
        CallPayloadKeys.type: FcmMessageType.callAccept,
        CallPayloadKeys.callId: call.id,
        CallPayloadKeys.channelId: call.channelId,
        CallPayloadKeys.callerId: call.callerId,
        CallPayloadKeys.calleeId: call.calleeId,
        CallPayloadKeys.timestamp: DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore
        .collection(FirestoreCollections.calls)
        .doc(call.id)
        .update({
          'status': CallStatus.connected.name,
          'connectedAt': Timestamp.fromDate(DateTime.now()),
        });

    _activeCall = call.copyWith(status: CallStatus.connected);
    notifyListeners();
  }

  Future<void> declineActiveCall() async {
    final call = _activeCall;
    final user = _authService.currentUser;
    if (call == null || user == null) return;

    await _fcmService.sendCallEvent(
      data: {
        CallPayloadKeys.type: FcmMessageType.callCancel,
        CallPayloadKeys.callId: call.id,
        CallPayloadKeys.channelId: call.channelId,
        CallPayloadKeys.callerId: call.callerId,
        CallPayloadKeys.calleeId: call.calleeId,
        CallPayloadKeys.timestamp: DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore
        .collection(FirestoreCollections.calls)
        .doc(call.id)
        .update({
          'status': CallStatus.missed.name,
          'endedAt': Timestamp.fromDate(DateTime.now()),
        });

    _activeCall = call.copyWith(status: CallStatus.missed);
    notifyListeners();
  }

  Future<void> endActiveCall() async {
    final call = _activeCall;
    if (call == null) return;

    await _fcmService.sendCallEvent(
      data: {
        CallPayloadKeys.type: FcmMessageType.callEnd,
        CallPayloadKeys.callId: call.id,
        CallPayloadKeys.channelId: call.channelId,
        CallPayloadKeys.callerId: call.callerId,
        CallPayloadKeys.calleeId: call.calleeId,
        CallPayloadKeys.timestamp: DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore
        .collection(FirestoreCollections.calls)
        .doc(call.id)
        .update({
          'status': CallStatus.ended.name,
          'endedAt': Timestamp.fromDate(DateTime.now()),
        });

    await _agoraService.leaveChannel();

    _activeCall = null;
    _agoraToken = null;
    _localAgoraUid = null;
    notifyListeners();
  }

  Future<void> joinAgoraChannel() async {
    if (_activeCall == null || _agoraToken == null || _localAgoraUid == null) {
      throw StateError('Missing Agora session information.');
    }

    await _agoraService.joinChannel(
      channelId: _activeCall!.channelId,
      uid: _localAgoraUid!,
      token: _agoraToken!,
    );
  }

  Future<void> handleIncomingCall(Map<String, dynamic> data) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final call = CallSession(
      id: data[CallPayloadKeys.callId] as String,
      channelId: data[CallPayloadKeys.channelId] as String,
      callerId: data[CallPayloadKeys.callerId] as String,
      callerName: data[CallPayloadKeys.callerName] as String? ?? 'Caller',
      calleeId: user.uid,
      calleeName: user.displayName,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
      participants: [data[CallPayloadKeys.callerId] as String, user.uid],
    );

    _activeCall = call;
    notifyListeners();
  }

  Future<void> handleCallAccepted(Map<String, dynamic> data) async {
    if (_activeCall == null) return;
    final callId = data[CallPayloadKeys.callId] as String?;
    if (callId != null) {
      await _firestore
          .collection(FirestoreCollections.calls)
          .doc(callId)
          .update({
            'status': CallStatus.connected.name,
            'connectedAt': Timestamp.fromDate(DateTime.now()),
          });
    }
    _activeCall = _activeCall!.copyWith(status: CallStatus.connected);
    notifyListeners();
  }

  Future<void> handleCallCancelled(Map<String, dynamic> data) async {
    final callId = data[CallPayloadKeys.callId] as String?;
    if (callId != null) {
      await _firestore
          .collection(FirestoreCollections.calls)
          .doc(callId)
          .update({
            'status': CallStatus.missed.name,
            'endedAt': Timestamp.fromDate(DateTime.now()),
          });
    }
    if (_activeCall != null) {
      _activeCall = _activeCall!.copyWith(status: CallStatus.missed);
    }
    notifyListeners();
  }

  Future<void> handleCallEnded(Map<String, dynamic> data) async {
    final callId = data[CallPayloadKeys.callId] as String?;
    if (callId != null) {
      await _firestore
          .collection(FirestoreCollections.calls)
          .doc(callId)
          .update({
            'status': CallStatus.ended.name,
            'endedAt': Timestamp.fromDate(DateTime.now()),
          });
    }
    await _agoraService.leaveChannel();
    _activeCall = null;
    _agoraToken = null;
    _localAgoraUid = null;
    notifyListeners();
  }

  Future<void> openCallFromNotification(Map<String, dynamic> data) async {
    // Intentionally left for the UI layer to decide. This method simply ensures
    // the call session is hydrated so that navigation can read from `activeCall`.
    if (_activeCall != null) return;

    final callId = data[CallPayloadKeys.callId] as String?;
    if (callId == null) return;
    final snapshot = await _firestore
        .collection(FirestoreCollections.calls)
        .doc(callId)
        .get();
    if (snapshot.exists) {
      _activeCall = CallSession.fromDocument(snapshot);
      notifyListeners();
    }
  }

  void toggleMute() {
    _muted = !_muted;
    _agoraService.muteLocalAudio(_muted);
    notifyListeners();
  }

  void toggleSpeaker() {
    _speakerOn = !_speakerOn;
    _agoraService.enableSpeakerphone(_speakerOn);
    notifyListeners();
  }

  int _generateAgoraUid(String uid) => uid.hashCode & 0x0FFFFFFF;

  Future<String> _fetchAgoraToken({
    required String channelId,
    required int uid,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(AppConfig.agoraTokenServiceUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'channelName': channelId, 'uid': uid}),
    );

    if (response.statusCode >= 400) {
      throw Exception(
        'Failed to retrieve Agora token: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Agora token response missing "token" field.');
    }
    return token;
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}
