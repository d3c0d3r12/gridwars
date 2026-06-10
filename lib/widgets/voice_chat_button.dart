import 'package:flutter/material.dart';

import '../functions/voice_service.dart';

// Hold-to-talk voice button for online game screens. Joins the room's Agora
// channel on mount (muted), leaves on dispose. Hold = mic open, release = mute.
// Renders nothing if Agora isn't configured (kAgoraAppId empty), so it's safe
// to drop in before the App ID is set.
class VoiceChatButton extends StatefulWidget {
  final String channel;
  final String myFbUid;
  final Color color;
  const VoiceChatButton({
    super.key,
    required this.channel,
    required this.myFbUid,
    this.color = const Color(0xFF00C853),
  });

  @override
  State<VoiceChatButton> createState() => _VoiceChatButtonState();
}

class _VoiceChatButtonState extends State<VoiceChatButton> {
  @override
  void initState() {
    super.initState();
    if (VoiceService.instance.available) {
      VoiceService.instance
          .join(channel: widget.channel, myFbUid: widget.myFbUid);
    }
  }

  @override
  void dispose() {
    VoiceService.instance.leave();
    super.dispose();
  }

  void _down(_) => VoiceService.instance.startTalking();
  void _up([_]) => VoiceService.instance.stopTalking();

  @override
  Widget build(BuildContext context) {
    if (!VoiceService.instance.available) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: VoiceService.instance.inChannel,
      builder: (context, connected, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: VoiceService.instance.talking,
          builder: (context, talking, __) {
            final active = talking && connected;
            return GestureDetector(
              onTapDown: connected ? _down : null,
              onTapUp: _up,
              onTapCancel: _up,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? widget.color : Colors.black54,
                  border: Border.all(
                    color: active ? Colors.white : widget.color,
                    width: 2,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.7),
                            blurRadius: 18,
                            spreadRadius: 3,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  connected
                      ? (active ? Icons.mic : Icons.mic_none)
                      : Icons.mic_off,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Wrap a player's avatar with this to show a green glowing ring when that
/// player is speaking. Pass the player's Firebase uid.
class VoiceSpeakingRing extends StatelessWidget {
  final String playerFbUid;
  final Widget child;
  final Color color;
  const VoiceSpeakingRing({
    super.key,
    required this.playerFbUid,
    required this.child,
    this.color = const Color(0xFF00C853),
  });

  @override
  Widget build(BuildContext context) {
    if (!VoiceService.instance.available) return child;
    final uid = VoiceService.agoraUid(playerFbUid);
    return ValueListenableBuilder<Set<int>>(
      valueListenable: VoiceService.instance.speaking,
      builder: (context, speaking, _) {
        final isSpeaking = speaking.contains(uid);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSpeaking ? color : Colors.transparent,
              width: 3,
            ),
            boxShadow: isSpeaking
                ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 2)]
                : null,
          ),
          child: child,
        );
      },
    );
  }
}
