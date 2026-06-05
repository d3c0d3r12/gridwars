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
  final Set<String> _marked = {}; // message ids already marked seen (loop guard)
  bool _blocked = false;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    FriendService.goOnline();
    _ctrl.addListener(() {
      final can = _ctrl.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
    _checkBlock();
  }

  Future<void> _checkBlock() async {
    try {
      final b = await FriendService.iBlocked(widget.friendUid);
      if (mounted) setState(() => _blocked = b);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _canSend = false);
    // Fire-and-forget — RTDB echoes it back instantly via the stream.
    FriendService.sendMessage(widget.friendUid, text).then((err) {
      if (err != null && mounted) utils.setSnackbar(context, err);
    });
    _scrollToBottom(animated: true);
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      animated
          ? _scroll.animateTo(target,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut)
          : _scroll.jumpTo(target);
    });
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
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
    return 'last seen ${diff.inDays}d ago';
  }

  String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
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

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: lineColor)),
        boxShadow: [shadowSm],
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
          radius: 19,
          backgroundColor: surface2Color,
          backgroundImage: widget.friendPic.isNotEmpty ? NetworkImage(widget.friendPic) : null,
          child: widget.friendPic.isEmpty ? Icon(Icons.person_rounded, color: ink3Color, size: 19) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.friendName,
              style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 15.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          StreamBuilder<Map>(
            stream: FriendService.presenceOf(widget.friendUid),
            builder: (_, snap) {
              final p = snap.data ?? const {};
              final online = p['online'] == true;
              final lastSeen = (p['lastSeen'] as int?) ?? 0;
              return Row(children: [
                if (online) ...[
                  Container(width: 7, height: 7, decoration: const BoxDecoration(
                      color: Color(0xFF19B36B), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                ],
                Text(online ? 'Online' : _fmtLastSeen(lastSeen),
                    style: TextStyle(color: online ? goodColor : ink3Color, fontSize: 11.5)),
              ]);
            },
          ),
        ])),
        IconButton(
          icon: Icon(Icons.sports_esports_rounded, color: xColor, size: 22),
          tooltip: 'Challenge',
          onPressed: _blocked ? null : () => startChallenge(context, widget.friendUid, widget.friendName),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: ink2Color),
          color: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) async {
            if (v == 'block') {
              await FriendService.blockUser(widget.friendUid);
              if (mounted) { setState(() => _blocked = true); utils.setSnackbar(context, 'Blocked ${widget.friendName}'); }
            } else if (v == 'unblock') {
              await FriendService.unblockUser(widget.friendUid);
              if (mounted) { setState(() => _blocked = false); utils.setSnackbar(context, 'Unblocked ${widget.friendName}'); }
            }
          },
          itemBuilder: (_) => [
            _blocked
                ? PopupMenuItem(value: 'unblock', child: _menuRow(Icons.lock_open_rounded, 'Unblock', goodColor))
                : PopupMenuItem(value: 'block', child: _menuRow(Icons.block_rounded, 'Block', red)),
          ],
        ),
      ]),
    );
  }

  Widget _menuRow(IconData i, String t, Color c) => Row(children: [
        Icon(i, color: c, size: 18), const SizedBox(width: 10),
        Text(t, style: TextStyle(color: c == red ? red : inkColor)),
      ]);

  // ── Messages ───────────────────────────────────────────────────────────────

  Widget _messageList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: FriendService.messages(widget.friendUid),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Center(child: CircularProgressIndicator(color: xColor, strokeWidth: 2.5));
        }
        final msgs = snap.data ?? [];

        // Mark incoming unseen as read — once each (loop-safe via _marked set).
        final unseen = msgs
            .where((m) => m.from != _myUid && !m.seen && !_marked.contains(m.id))
            .map((m) => m.id)
            .toList();
        if (unseen.isNotEmpty) {
          _marked.addAll(unseen);
          FriendService.markRead(widget.friendUid, unseenIds: unseen);
        }

        if (msgs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.waving_hand_rounded, color: ink3Color, size: 44),
            const SizedBox(height: 12),
            Text('Say hi to ${widget.friendName}!',
                style: TextStyle(color: ink2Color, fontSize: 14)),
          ]));
        }

        _scrollToBottom();

        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final m = msgs[i];
            final prev = i > 0 ? msgs[i - 1] : null;
            final next = i < msgs.length - 1 ? msgs[i + 1] : null;
            final mine = m.from == _myUid;

            // Day separator when the date changes.
            final showDay = prev == null ||
                _dayLabel(prev.time) != _dayLabel(m.time);
            // Group consecutive messages from the same sender.
            final groupedWithNext = next != null && next.from == m.from &&
                _dayLabel(next.time) == _dayLabel(m.time);

            return Column(children: [
              if (showDay) _daySeparator(m.time),
              _bubble(m, mine, tail: !groupedWithNext),
            ]);
          },
        );
      },
    );
  }

  Widget _daySeparator(int ms) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: surface2Color,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: lineColor),
          ),
          child: Text(_dayLabel(ms),
              style: TextStyle(color: ink3Color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m, bool mine, {required bool tail}) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : (tail ? 4 : 18)),
      bottomRight: Radius.circular(mine ? (tail ? 4 : 18) : 18),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: EdgeInsets.only(bottom: tail ? 8 : 2, top: 1),
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
        decoration: BoxDecoration(
          gradient: mine
              ? LinearGradient(
                  colors: [xColor, xColor.withValues(alpha: 0.88)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: mine ? null : surfaceColor,
          borderRadius: radius,
          border: mine ? null : Border.all(color: lineColor),
          boxShadow: [shadowSm],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(m.text, style: TextStyle(
            color: mine ? Colors.white : inkColor, fontSize: 14.5, height: 1.32)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(_fmtTime(m.time), style: TextStyle(
              color: mine ? Colors.white.withValues(alpha: 0.75) : ink3Color, fontSize: 9.5)),
            if (mine) ...[
              const SizedBox(width: 3),
              Icon(m.seen ? Icons.done_all_rounded : Icons.done_rounded, size: 13,
                  color: m.seen ? const Color(0xFF9BE7FF) : Colors.white.withValues(alpha: 0.75)),
            ],
          ]),
        ]),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────

  Widget _inputBar() {
    if (_blocked) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        color: surfaceColor,
        child: Text('You blocked this user. Unblock to message.',
            textAlign: TextAlign.center, style: TextStyle(color: ink3Color, fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: lineColor)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: surface2Color,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: lineColor),
            ),
            child: TextField(
              controller: _ctrl,
              minLines: 1, maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: inkColor, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: ink3Color),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _canSend ? _send : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _canSend ? xColor : ink3Color.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              boxShadow: _canSend ? [BoxShadow(color: xColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
