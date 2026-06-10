import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

// ════════════════════════════════════════════════════════════════════════════
// VoiceService — in-game group voice chat (push-to-talk) via Agora.
//
// Players in the same online room join the SAME Agora channel (= room code).
// Each player's Agora uid is derived deterministically from their Firebase uid
// (agoraUid()), so every device can map "who is speaking" to a player WITHOUT
// any extra Firebase bookkeeping — both sides compute the same number.
//
// Push-to-talk: you join MUTED; holding the mic button unmutes your stream,
// releasing mutes it again. `speaking` lists the Agora uids currently talking
// (from Agora's audio-volume indication), so the UI can glow that player.
//
// Free: Agora's free tier (~10,000 min/month). Firebase is NOT involved in the
// audio — this is a separate service. Set kAgoraAppId after creating a free
// Agora project (https://console.agora.io).
const String kAgoraAppId = 'fbc9b0850eef4b75aa566dd9b02b436a';
// ════════════════════════════════════════════════════════════════════════════

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  RtcEngine? _engine;
  String? _channel;
  bool _initing = false;

  // UI state.
  final ValueNotifier<bool> inChannel = ValueNotifier(false);
  final ValueNotifier<bool> talking = ValueNotifier(false); // mic open (PTT held)
  final ValueNotifier<Set<int>> speaking = ValueNotifier(<int>{}); // agora uids
  final ValueNotifier<Set<int>> remotes = ValueNotifier(<int>{}); // joined uids

  bool get available => kAgoraAppId.isNotEmpty;

  /// Deterministic 31-bit Agora uid for a Firebase uid (same on every device).
  static int agoraUid(String fbUid) {
    // FNV-1a hash, masked to a positive 31-bit int (Agora uid must be != 0).
    int h = 0x811c9dc5;
    for (final c in fbUid.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    final v = h & 0x7fffffff;
    return v == 0 ? 1 : v;
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _ensureEngine() async {
    if (_engine != null || _initing) return;
    _initing = true;
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(const RtcEngineContext(
        appId: kAgoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      await engine.enableAudio();
      // Speaking detection: report every 200ms with voice-activity flag.
      await engine.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: true,
      );
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          inChannel.value = true;
        },
        onLeaveChannel: (conn, stats) {
          inChannel.value = false;
          remotes.value = {};
          speaking.value = {};
        },
        onUserJoined: (conn, uid, elapsed) {
          remotes.value = {...remotes.value, uid};
        },
        onUserOffline: (conn, uid, reason) {
          remotes.value = {...remotes.value}..remove(uid);
          speaking.value = {...speaking.value}..remove(uid);
        },
        onAudioVolumeIndication: (conn, speakers, total, volume) {
          final now = <int>{};
          for (final s in speakers) {
            // uid 0 = local speaker. volume 0..255; treat >5 with VAD as talking.
            final uid = (s.uid == 0)
                ? (_myUid ?? 0)
                : (s.uid ?? 0);
            final vol = s.volume ?? 0;
            final vad = s.vad ?? 0;
            if (uid != 0 && vol > 5 && (vad == 1 || vol > 15)) now.add(uid);
          }
          speaking.value = now;
        },
      ));
      _engine = engine;
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService init error: $e');
    } finally {
      _initing = false;
    }
  }

  int? _myUid;

  /// Join the room's voice channel (muted — push-to-talk). Returns false if mic
  /// denied or Agora not configured.
  Future<bool> join({required String channel, required String myFbUid}) async {
    if (!available) return false;
    if (!await _ensureMicPermission()) return false;
    await _ensureEngine();
    final engine = _engine;
    if (engine == null) return false;

    if (_channel == channel && inChannel.value) return true;
    if (_channel != null) await leave();

    _channel = channel;
    _myUid = agoraUid(myFbUid);
    await engine.joinChannel(
      token: '', // App-ID-only mode (no token server yet)
      channelId: channel,
      uid: _myUid!,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
    // Start muted → push-to-talk.
    await engine.muteLocalAudioStream(true);
    talking.value = false;
    return true;
  }

  /// Open the mic (PTT pressed).
  Future<void> startTalking() async {
    final e = _engine;
    if (e == null || !inChannel.value) return;
    await e.muteLocalAudioStream(false);
    talking.value = true;
  }

  /// Close the mic (PTT released).
  Future<void> stopTalking() async {
    final e = _engine;
    if (e == null) return;
    await e.muteLocalAudioStream(true);
    talking.value = false;
  }

  /// Toggle the earpiece/speaker on remote audio (optional).
  Future<void> setSpeakerphone(bool on) async {
    await _engine?.setEnableSpeakerphone(on);
  }

  Future<void> leave() async {
    final e = _engine;
    _channel = null;
    _myUid = null;
    talking.value = false;
    speaking.value = {};
    remotes.value = {};
    inChannel.value = false;
    try {
      await e?.muteLocalAudioStream(true);
      await e?.leaveChannel();
    } catch (_) {}
  }

  /// Full teardown (e.g. on logout). Re-join will re-create the engine.
  Future<void> dispose() async {
    await leave();
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }
}
