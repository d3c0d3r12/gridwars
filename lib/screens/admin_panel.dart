import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../functions/admin_service.dart';
import '../helpers/color.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<AdminUser> _allUsers = [];
  List<AdminUser> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _filter = 'all';
  final _searchCtrl = TextEditingController();
  StreamSubscription? _usersSub;

  @override
  void initState() {
    super.initState();
    _subscribeUsers();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _subscribeUsers() {
    _usersSub?.cancel();
    _usersSub = AdminService.usersStream().listen((users) {
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _loading = false;
      });
      _applyFilter();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _subscribeUsers();
  }

  void _applyFilter() {
    var list = _allUsers.where((u) {
      final q = _search.toLowerCase();
      final matchesSearch = q.isEmpty ||
          u.username.toLowerCase().contains(q) ||
          u.uid.toLowerCase().contains(q);
      final matchesFilter = _filter == 'all' ||
          (_filter == 'banned' && u.banned) ||
          (_filter == 'guest' && u.type == 'GUEST') ||
          (_filter == 'authorized' && u.type == 'AUTHORIZED');
      return matchesSearch && matchesFilter;
    }).toList();
    setState(() => _filtered = list);
  }

  // ── Stats derived from full list ──────────────────────────────────────────

  int get _totalUsers => _allUsers.length;
  int get _bannedCount => _allUsers.where((u) => u.banned).length;
  int get _totalCoins =>
      _allUsers.fold(0, (s, u) => s + u.coins);

  // ── User actions ──────────────────────────────────────────────────────────

  void _openUserSheet(AdminUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _UserActionSheet(
        user: user,
        onDone: _load,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lineColor),
                    boxShadow: [shadowSm],
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
                ),
              ),
              const Spacer(),
              Column(children: [
                Text('ADMIN PANEL',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                        color: inkColor, letterSpacing: 1.5)),
                Text('${FirebaseAuth.instance.currentUser?.uid.substring(0, 8)}…',
                    style: TextStyle(fontSize: 10, color: ink3Color)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lineColor),
                    boxShadow: [shadowSm],
                  ),
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: xColor))
                      : Icon(Icons.refresh_rounded, color: inkColor, size: 20),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Stats row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _StatCard('Users', '$_totalUsers', Icons.people_rounded, xColor),
              const SizedBox(width: 10),
              _StatCard('Banned', '$_bannedCount', Icons.block_rounded, red),
              const SizedBox(width: 10),
              _StatCard('Coins', '${_totalCoins ~/ 1000}k',
                  Icons.monetization_on_rounded, goldColor),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lineColor),
                boxShadow: [shadowSm],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _search = v;
                  _applyFilter();
                },
                style: TextStyle(color: inkColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by username or UID…',
                  hintStyle: TextStyle(color: ink3Color, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: ink3Color, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            _search = '';
                            _applyFilter();
                          },
                          child: Icon(Icons.close_rounded, color: ink3Color, size: 18))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Filter chips ──────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final f in [
                ('all', 'All', inkColor),
                ('banned', 'Banned', red),
                ('authorized', 'Registered', goodColor),
                ('guest', 'Guest', ink2Color),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _filter = f.$1;
                      _applyFilter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _filter == f.$1
                            ? f.$3.withValues(alpha: 0.15)
                            : surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _filter == f.$1
                              ? f.$3.withValues(alpha: 0.6)
                              : lineColor,
                        ),
                      ),
                      child: Text(f.$2,
                          style: TextStyle(
                            color: _filter == f.$1 ? f.$3 : ink2Color,
                            fontWeight: _filter == f.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          )),
                    ),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 10),

          // ── User list ─────────────────────────────────────────────────────
          Expanded(
            child: _loading && _allUsers.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: xColor))
                : _filtered.isEmpty
                    ? Center(
                        child: Text('No users found',
                            style: TextStyle(color: ink2Color)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) =>
                            _UserTile(user: _filtered[i], onTap: _openUserSheet),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [shadowSm],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      color: inkColor, fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  style: TextStyle(color: ink3Color, fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final void Function(AdminUser) onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: user.banned
              ? red.withValues(alpha: 0.06)
              : surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: user.banned
                ? red.withValues(alpha: 0.35)
                : lineColor,
          ),
          boxShadow: [shadowSm],
        ),
        child: Row(children: [
          // Avatar
          Stack(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: surface2Color,
              backgroundImage: user.profilePic.isNotEmpty
                  ? NetworkImage(user.profilePic)
                  : null,
              child: user.profilePic.isEmpty
                  ? Icon(Icons.person_rounded, color: ink3Color, size: 22)
                  : null,
            ),
            if (user.banned)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                      color: red, shape: BoxShape.circle,
                      border: Border.all(color: surfaceColor, width: 1.5)),
                  child: const Icon(Icons.block, color: Colors.white, size: 9),
                ),
              ),
          ]),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(user.username,
                      style: TextStyle(color: inkColor,
                          fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: user.type == 'AUTHORIZED'
                        ? goodColor.withValues(alpha: 0.12)
                        : ink3Color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.type == 'AUTHORIZED' ? 'REG' : 'GUEST',
                    style: TextStyle(
                      color: user.type == 'AUTHORIZED' ? goodColor : ink3Color,
                      fontSize: 9, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.monetization_on_rounded,
                    color: goldColor, size: 12),
                const SizedBox(width: 3),
                Text('${user.coins}',
                    style: TextStyle(color: ink2Color, fontSize: 11)),
                const SizedBox(width: 10),
                Icon(Icons.sports_esports_rounded,
                    color: ink3Color, size: 12),
                const SizedBox(width: 3),
                Text('${user.matchWon}W / ${user.matchPlayed}P',
                    style: TextStyle(color: ink3Color, fontSize: 11)),
              ]),
              if (user.banned && user.banReason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('Banned: ${user.banReason}',
                      style: TextStyle(
                          color: red.withValues(alpha: 0.8),
                          fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ),
            ]),
          ),

          Icon(Icons.chevron_right_rounded, color: ink3Color, size: 18),
        ]),
      ),
    );
  }
}

// ── User action bottom sheet ───────────────────────────────────────────────────

class _UserActionSheet extends StatefulWidget {
  final AdminUser user;
  final VoidCallback onDone;
  const _UserActionSheet({required this.user, required this.onDone});
  @override
  State<_UserActionSheet> createState() => _UserActionSheetState();
}

class _UserActionSheetState extends State<_UserActionSheet> {
  bool _busy = false;
  late AdminUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      // Refresh user data
      final data = await AdminService.getUserData(_user.uid);
      if (mounted && data != null) {
        setState(() {
          _user = AdminUser.fromMap(_user.uid, data);
          _busy = false;
        });
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: red));
      }
    }
  }

  void _showBanDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ban ${_user.username}?',
            style: TextStyle(color: inkColor, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('The user will be immediately locked out.',
              style: TextStyle(color: ink2Color, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            style: TextStyle(color: inkColor),
            decoration: InputDecoration(
              hintText: 'Reason (optional)',
              hintStyle: TextStyle(color: ink3Color),
              filled: true,
              fillColor: surface2Color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: ink2Color))),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _run(() => AdminService.banUser(
                    _user.uid, ctrl.text.trim()));
              },
              child: Text('Ban', style: TextStyle(
                  color: red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _showCoinDialog() {
    final ctrl = TextEditingController();
    int mode = 1; // 1=add, -1=remove, 0=set
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Manage Coins — ${_user.username}',
              style: TextStyle(
                  color: inkColor, fontWeight: FontWeight.w700, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Current: ${_user.coins} coins',
                style: TextStyle(color: ink2Color, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              for (final m in [
                (1, 'Add', goodColor),
                (-1, 'Remove', red),
                (0, 'Set', xColor),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => setS(() => mode = m.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: mode == m.$1
                              ? m.$3.withValues(alpha: 0.15)
                              : surface2Color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: mode == m.$1
                                ? m.$3.withValues(alpha: 0.5)
                                : lineColor,
                          ),
                        ),
                        child: Text(m.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mode == m.$1 ? m.$3 : ink3Color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            )),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: inkColor),
              decoration: InputDecoration(
                hintText: 'Amount',
                hintStyle: TextStyle(color: ink3Color),
                filled: true,
                fillColor: surface2Color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: ink2Color))),
            TextButton(
                onPressed: () {
                  final amount = int.tryParse(ctrl.text.trim()) ?? 0;
                  if (amount <= 0) return;
                  Navigator.pop(context);
                  if (mode == 0) {
                    _run(() => AdminService.setCoins(_user.uid, amount));
                  } else {
                    _run(() => AdminService.adjustCoins(
                        _user.uid, mode * amount));
                  }
                },
                child: Text('Apply',
                    style: TextStyle(
                        color: xColor, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Stats?',
            style: TextStyle(color: inkColor, fontWeight: FontWeight.w700)),
        content: Text(
            'This will set ${_user.username}\'s matches played, won, and score to 0.',
            style: TextStyle(color: ink2Color, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: ink2Color))),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _run(() => AdminService.resetStats(_user.uid));
              },
              child: Text('Reset',
                  style: TextStyle(
                      color: red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: lineColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // User header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: surface2Color,
                backgroundImage: _user.profilePic.isNotEmpty
                    ? NetworkImage(_user.profilePic)
                    : null,
                child: _user.profilePic.isEmpty
                    ? Icon(Icons.person_rounded, size: 28, color: ink3Color)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_user.username,
                      style: TextStyle(color: inkColor,
                          fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(_user.uid,
                      style: TextStyle(color: ink3Color, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, children: [
                    _chip('${_user.coins} coins', goldColor),
                    _chip('${_user.matchWon}W/${_user.matchPlayed}P',
                        xColor),
                    _chip('Score ${_user.score}', oColor),
                    if (_user.banned) _chip('BANNED', red),
                  ]),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 20),
          Divider(color: lineColor, height: 1),
          const SizedBox(height: 8),

          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            Column(children: [
              // Ban / Unban
              _ActionTile(
                icon: _user.banned
                    ? Icons.lock_open_rounded
                    : Icons.block_rounded,
                label: _user.banned ? 'Unban User' : 'Ban User',
                sub: _user.banned
                    ? 'Restore access to the app'
                    : 'Lock user out immediately',
                color: _user.banned ? goodColor : red,
                onTap: _user.banned
                    ? () => _run(() => AdminService.unbanUser(_user.uid))
                    : _showBanDialog,
              ),

              // Coins
              _ActionTile(
                icon: Icons.monetization_on_rounded,
                label: 'Manage Coins',
                sub: 'Add, remove, or set exact coin balance',
                color: goldColor,
                onTap: _showCoinDialog,
              ),

              // Reset stats
              _ActionTile(
                icon: Icons.restart_alt_rounded,
                label: 'Reset Stats',
                sub: 'Zero out matches played, won and score',
                color: ink2Color,
                onTap: _showResetConfirm,
              ),

              // Copy UID
              _ActionTile(
                icon: Icons.copy_rounded,
                label: 'Copy UID',
                sub: _user.uid,
                color: xColor,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _user.uid));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UID copied')));
                },
              ),

              const SizedBox(height: 16),
            ]),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: inkColor, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(sub,
          style: TextStyle(color: ink3Color, fontSize: 11),
          overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.chevron_right_rounded, color: ink3Color),
      onTap: onTap,
    );
  }
}

// ── Ban screen (shown when current user is banned) ────────────────────────────

class BannedScreen extends StatelessWidget {
  final String reason;
  const BannedScreen({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_rounded, color: red, size: 56),
              ),
              const SizedBox(height: 24),
              Text('Account Banned',
                  style: TextStyle(
                      color: inkColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 24)),
              const SizedBox(height: 10),
              Text(
                reason.isNotEmpty
                    ? 'Reason: $reason'
                    : 'Your account has been suspended for violating our terms of service.',
                style: TextStyle(color: ink2Color, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/authscreen', (_) => false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: surfaceColor,
                    border: Border.all(color: lineColor),
                  ),
                  child: Text('Sign Out',
                      style: TextStyle(
                          color: ink2Color, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
