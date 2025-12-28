import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../config/config.dart';

/// Thin wrapper around the Agora SDK to keep engine lifecycle contained.
class AgoraService {
  AgoraService();

  RtcEngine? _engine;
  bool _isInitialized = false;

  RtcEngine get engine {
    final instance = _engine;
    if (instance == null) {
      throw StateError('Agora engine accessed before initialization.');
    }
    return instance;
  }

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(
      RtcEngineContext(
        appId: AppConfig.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    await engine.enableAudio();
    await engine.setClientRole(
      role: ClientRoleType.clientRoleBroadcaster,
      options: const ClientRoleOptions(),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType code, String message) {
          debugPrint('Agora error $code -> $message');
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('Joined Agora channel ${connection.channelId}');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Remote user $remoteUid joined channel');
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint('Remote user $remoteUid left channel: $reason');
            },
      ),
    );

    _engine = engine;
    _isInitialized = true;
  }

  Future<void> joinChannel({
    required String channelId,
    required int uid,
    required String token,
  }) async {
    final engine = this.engine;
    await engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> leaveChannel() async {
    if (!_isInitialized) return;
    await engine.leaveChannel();
  }

  Future<void> muteLocalAudio(bool muted) async {
    if (!_isInitialized) return;
    await engine.muteLocalAudioStream(muted);
  }

  Future<void> enableSpeakerphone(bool enabled) async {
    if (!_isInitialized) return;
    await engine.setEnableSpeakerphone(enabled);
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;
    await leaveChannel();
    await engine.release();
    _engine = null;
    _isInitialized = false;
  }
}
