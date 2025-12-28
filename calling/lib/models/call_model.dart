import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a call session persisted in Firestore for logs and analytics.
class CallSession {
  CallSession({
    required this.id,
    required this.channelId,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.status,
    required this.createdAt,
    this.connectedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.participants = const [],
  });

  final String id;
  final String channelId;
  final String callerId;
  final String callerName;
  final String calleeId;
  final String calleeName;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final List<String> participants;

  CallSession copyWith({
    CallStatus? status,
    DateTime? connectedAt,
    DateTime? endedAt,
    int? durationSeconds,
    List<String>? participants,
  }) {
    return CallSession(
      id: id,
      channelId: channelId,
      callerId: callerId,
      callerName: callerName,
      calleeId: calleeId,
      calleeName: calleeName,
      status: status ?? this.status,
      createdAt: createdAt,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      participants: participants ?? this.participants,
    );
  }

  factory CallSession.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CallSession(
      id: doc.id,
      channelId: data['channelId'] as String? ?? '',
      callerId: data['callerId'] as String? ?? '',
      callerName: data['callerName'] as String? ?? '',
      calleeId: data['calleeId'] as String? ?? '',
      calleeName: data['calleeName'] as String? ?? '',
      status: CallStatusX.fromString(data['status'] as String? ?? ''),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      connectedAt: (data['connectedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      durationSeconds: data['durationSeconds'] as int? ?? 0,
      participants: (data['participants'] as List<dynamic>? ?? [])
          .cast<String>(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'channelId': channelId,
      'callerId': callerId,
      'callerName': callerName,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (connectedAt != null) 'connectedAt': Timestamp.fromDate(connectedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      'durationSeconds': durationSeconds,
      'participants': participants,
    };
  }
}

/// Supported statuses for a call lifecycle.
enum CallStatus { ringing, connected, ended, missed }

extension CallStatusX on CallStatus {
  static CallStatus fromString(String value) {
    return CallStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CallStatus.ringing,
    );
  }

  String get label {
    switch (this) {
      case CallStatus.ringing:
        return 'Ringing';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.ended:
        return 'Ended';
      case CallStatus.missed:
        return 'Missed';
    }
  }
}
