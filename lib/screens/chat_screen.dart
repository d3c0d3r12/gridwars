import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../functions/friend_service.dart';
import '../helpers/color.dart';
import 'friend_challenge.dart';
import 'splash.dart';

class ChatScreen extends StatefulWidget {
  final String friendUid, friendName, friendPic;
  const ChatScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
    required this.friendPic,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _myUid = FirebaseAuth.instance.currentUser!.uid;
  bool _blocked = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    FriendService.goOnline();
    FriendService.markRead(widget.friendUid);
    _checkBlock();
  }

  Future<void> _checkBlock() async {
    final b = await FriendService.isBlockedEither(widget.friendUid);
    if (mounted) setState(() => _blocked = b);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    final err = await FriendService.sendMessage(widget.friendUid, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      utils.setSnackbar(context, err);
    } else {
      // Scroll to newest after the stream rebuilds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

  String _fmtTime(int ms) {
    if (ms == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _fmtLastSeen(int ms) {
    if (ms == 0) return 'Offline';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(child: _messageList()),
          _inputBar(),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: lineColor)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 22),
          ),
        ),
        CircleAvatar(
          radius: 18,
          backgroundColor: surface2Color,
          backgroundImage: widget.friendPic.isNotEmpty ? NetworkImage(widget.friendPic) : null,
          child: widget.friendPic.isEmpty ? Icon(Icons.person_rounded, color: ink3Color, size: 18) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.friendName,
              style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          StreamBuilder<Map>(
            stream: FriendService.presenceOf(widget.friendUid),
            builder: (_, snap) {
              final p = snap.data ?? const {};
              final online = p['online'] == true;
              final lastSeen = (p['lastSeen'] as int?) ?? 0;
              return Text(
                online ? 'Online' : _fmtLastSeen(lastSeen),
                style: TextStyle(color: online ? goodColor : ink3Color, fontSize: 11.5),
              );
            },
          ),
        ])),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: ink2Color),
          color: surfaceColor,
          onSelected: (v) async {
            if (v == 'challenge') {
              startChallenge(context, widget.friendUid, widget.friendName);
            } else if (v == 'block') {
              await FriendService.blockUser(widget.friendUid);
              if (mounted) {
                setState(() => _blocked = true);
                utils.setSnackbar(context, 'Blocked ${widget.friendName}');
              }
            } else if (v == 'unblock') {
              await FriendService.unblockUser(widget.friendUid);
              if (mounted) {
                setState(() => _blocked = false);
                utils.setSnackbar(context, 'Unblocked ${widget.friendName}');
              }
            }
          },
          itemBuilder: (_) => [
            if (!_blocked)
              PopupMenuItem(value: 'challenge', child: Row(children: [
                Icon(Icons.sports_esports_rounded, color: xColor, size: 18),
                const SizedBox(width: 10), Text('Challenge', style: TextStyle(color: inkColor)),
              ])),
            _blocked
                ? PopupMenuItem(value: 'unblock', child: Row(children: [
                    Icon(Icons.lock_open_rounded, color: goodColor, size: 18),
                    const SizedBox(width: 10), Text('Unblock', style: TextStyle(color: inkColor)),
                  ]))
                : PopupMenuItem(value: 'block', child: Row(children: [
                    Icon(Icons.block_rounded, color: red, size: 18),
                    const SizedBox(width: 10), Text('Block', style: TextStyle(color: red)),
                  ])),
          ],
        ),
      ]),
    );
  }

  Widget _messageList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: FriendService.messages(widget.friendUid),
      builder: (_, snap) {
        final msgs = snap.data ?? [];
        // Mark incoming as read whenever new messages arrive.
        if (msgs.any((m) => m.from != _myUid && !m.seen)) {
          FriendService.markRead(widget.friendUid);
        }
        if (msgs.isEmpty) {
          return Center(child: Text('Say hi 👋',
              style: TextStyle(color: ink3Color, fontSize: 14)));
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          itemCount: msgs.length,
          itemBuilder: (_, i) => _bubble(msgs[i]),
        );
      },
    );
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.from == _myUid;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? xColor : surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: lineColor),
          boxShadow: [shadowSm],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(m.text, style: TextStyle(
            color: mine ? Colors.white : inkColor, fontSize: 14, height: 1.3,
          )),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_fmtTime(m.time), style: TextStyle(
              color: mine ? Colors.white.withValues(alpha: 0.7) : ink3Color, fontSize: 10,
            )),
            if (mine) ...[
              const SizedBox(width: 3),
              Icon(m.seen ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 13,
                  color: m.seen ? const Color(0xFF8BE0FF) : Colors.white.withValues(alpha: 0.7)),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _inputBar() {
    if (_blocked) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: surfaceColor,
        child: Text('Messaging unavailable — user is blocked.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ink3Color, fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: lineColor)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surface2Color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: lineColor),
            ),
            child: TextField(
              controller: _ctrl,
              minLines: 1, maxLines: 4,
              style: TextStyle(color: inkColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: ink3Color),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: xColor, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
