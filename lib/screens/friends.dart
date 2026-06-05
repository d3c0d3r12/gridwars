import 'package:flutter/material.dart';

import '../functions/friend_service.dart';
import '../helpers/color.dart';
import '../helpers/game_tags.dart';
import 'chat_screen.dart';
import 'friend_challenge.dart';
import 'splash.dart';
import 'tag_picker.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    FriendService.goOnline();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: surfaceColor, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lineColor), boxShadow: [shadowSm],
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
                ),
              ),
              const Spacer(),
              Text('FRIENDS',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                      color: inkColor, letterSpacing: 1.5)),
              const Spacer(),
              const SizedBox(width: 42),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14), color: surface2Color),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: surfaceColor, boxShadow: [shadowSm]),
              labelColor: inkColor,
              unselectedLabelColor: ink3Color,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'Friends'), Tab(text: 'Requests'), Tab(text: 'Find')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [_FriendsTab(), _RequestsTab(), _FindTab()],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Friends list tab ──────────────────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendUser>>(
      stream: FriendService.friends(),
      builder: (_, snap) {
        final friends = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: xColor));
        }
        if (friends.isEmpty) {
          return _emptyState(Icons.people_outline_rounded,
              'No friends yet', 'Head to the Find tab to discover players who share your game tags.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: friends.length,
          itemBuilder: (_, i) => _FriendTile(friend: friends[i]),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final FriendUser friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineColor),
        boxShadow: [shadowSm],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _Avatar(pic: friend.pic, uid: friend.uid),
        title: Text(friend.name,
            style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: _PresenceLine(uid: friend.uid),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StreamBuilder<int>(
            stream: FriendService.unreadCount(friend.uid),
            builder: (_, s) {
              final n = s.data ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: red, shape: BoxShape.circle),
                child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: ink3Color),
            color: surfaceColor,
            onSelected: (v) async {
              if (v == 'challenge') {
                startChallenge(context, friend.uid, friend.name);
              } else if (v == 'remove') {
                await FriendService.removeFriend(friend.uid);
                if (context.mounted) utils.setSnackbar(context, 'Removed ${friend.name}');
              } else if (v == 'block') {
                await FriendService.blockUser(friend.uid);
                if (context.mounted) utils.setSnackbar(context, 'Blocked ${friend.name}');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'challenge', child: Row(children: [
                Icon(Icons.sports_esports_rounded, color: xColor, size: 18),
                const SizedBox(width: 10), Text('Challenge', style: TextStyle(color: inkColor)),
              ])),
              PopupMenuItem(value: 'remove', child: Row(children: [
                Icon(Icons.person_remove_rounded, color: ink2Color, size: 18),
                const SizedBox(width: 10), Text('Remove', style: TextStyle(color: inkColor)),
              ])),
              PopupMenuItem(value: 'block', child: Row(children: [
                Icon(Icons.block_rounded, color: red, size: 18),
                const SizedBox(width: 10), Text('Block', style: TextStyle(color: red)),
              ])),
            ],
          ),
        ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(friendUid: friend.uid, friendName: friend.name, friendPic: friend.pic),
        )),
      ),
    );
  }
}

class _PresenceLine extends StatelessWidget {
  final String uid;
  const _PresenceLine({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map>(
      stream: FriendService.presenceOf(uid),
      builder: (_, snap) {
        final p = snap.data ?? const {};
        final online = p['online'] == true;
        return Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? goodColor : ink3Color,
          )),
          const SizedBox(width: 6),
          Text(online ? 'Online' : 'Offline',
              style: TextStyle(color: online ? goodColor : ink3Color, fontSize: 11.5)),
        ]);
      },
    );
  }
}

// ── Requests tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: FriendService.incomingRequests(),
      builder: (_, snap) {
        final reqs = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: xColor));
        }
        if (reqs.isEmpty) {
          return _emptyState(Icons.inbox_rounded, 'No requests',
              'Friend requests sent to you will appear here.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: reqs.length,
          itemBuilder: (_, i) {
            final r = reqs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lineColor), boxShadow: [shadowSm],
              ),
              child: Row(children: [
                _Avatar(pic: r.fromPic, uid: r.fromUid),
                const SizedBox(width: 12),
                Expanded(child: Text(r.fromName,
                    style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                _miniBtn('Accept', goodColor, () async {
                  await FriendService.acceptRequest(r.fromUid, r.fromName, r.fromPic);
                  if (context.mounted) utils.setSnackbar(context, 'You are now friends with ${r.fromName}!');
                }),
                const SizedBox(width: 6),
                _miniBtn('Decline', ink3Color, () => FriendService.declineRequest(r.fromUid), outline: true),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Find tab (discovery) ──────────────────────────────────────────────────────

class _FindTab extends StatefulWidget {
  const _FindTab();
  @override
  State<_FindTab> createState() => _FindTabState();
}

class _FindTabState extends State<_FindTab> {
  Set<String>? _myTags;
  final Set<String> _sent = {};

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final t = await FriendService.myTags();
    if (mounted) setState(() => _myTags = t);
  }

  @override
  Widget build(BuildContext context) {
    if (_myTags == null) {
      return Center(child: CircularProgressIndicator(color: xColor));
    }
    if (_myTags!.isEmpty) {
      return _emptyState(Icons.tag_rounded, 'Pick your game tags first',
          'Select the games you play so we can match you with similar players.',
          action: ('Choose Tags', () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const TagPickerScreen()));
            _loadTags();
          }));
    }
    return StreamBuilder<List<DiscoveryUser>>(
      stream: FriendService.findByTags(_myTags!),
      builder: (_, snap) {
        final users = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: xColor));
        }
        if (users.isEmpty) {
          return _emptyState(Icons.search_off_rounded, 'No matches yet',
              'No other players share your tags right now. Try adding more game tags.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            final sent = _sent.contains(u.uid);
            final sharedTags = u.tags.intersection(_myTags!).take(3).map((id) => tagById(id).name).toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lineColor), boxShadow: [shadowSm],
              ),
              child: Row(children: [
                _Avatar(pic: u.profilePic, uid: u.uid),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.username,
                      style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${u.sharedCount} shared • ${sharedTags.join(", ")}',
                      style: TextStyle(color: ink3Color, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                _miniBtn(sent ? 'Sent' : 'Add', sent ? ink3Color : xColor, sent ? null : () async {
                  final err = await FriendService.sendRequest(u.uid, u.username);
                  if (!context.mounted) return;
                  if (err == null) {
                    setState(() => _sent.add(u.uid));
                    utils.setSnackbar(context, 'Request sent to ${u.username}');
                  } else {
                    utils.setSnackbar(context, err);
                  }
                }, outline: sent),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String pic, uid;
  const _Avatar({required this.pic, required this.uid});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: surface2Color,
      backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
      child: pic.isEmpty ? Icon(Icons.person_rounded, color: ink3Color, size: 22) : null,
    );
  }
}

Widget _miniBtn(String label, Color color, VoidCallback? onTap, {bool outline = false}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(10),
        border: outline ? Border.all(color: color.withValues(alpha: 0.5)) : null,
      ),
      child: Text(label, style: TextStyle(
        color: outline ? color : Colors.white,
        fontWeight: FontWeight.w700, fontSize: 12.5,
      )),
    ),
  );
}

Widget _emptyState(IconData icon, String title, String sub,
    {(String, VoidCallback)? action}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: ink3Color, size: 52),
        const SizedBox(height: 16),
        Text(title, style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text(sub, style: TextStyle(color: ink2Color, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: action.$2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: xColor),
              child: Text(action.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    ),
  );
}
