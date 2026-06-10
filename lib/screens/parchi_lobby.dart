import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../functions/parchi_service.dart';
import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import 'games/parchi_game.dart';

// 16 Parchi friends lobby — create a room (get a code) or join one, 2–4 players.
// Entry fee is taken from everyone on join; the last player standing wins the pot.
class ParchiLobbyScreen extends StatefulWidget {
  const ParchiLobbyScreen({super.key});
  @override
  State<ParchiLobbyScreen> createState() => _ParchiLobbyScreenState();
}

class _ParchiLobbyScreenState extends State<ParchiLobbyScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  String _name = 'Player';
  String _pic = '';
  String? _code;
  bool _isHost = false;
  bool _busy = false;
  StreamSubscription? _roomSub;
  Map<String, dynamic> _players = {};
  final _codeCtrl = TextEditingController();

  static const _accent = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final s = await FirebaseDatabase.instance.ref().child('users').child(_uid).get();
      final m = (s.value as Map?) ?? {};
      setState(() {
        _name = (m['username'] ?? 'Player').toString();
        _pic = (m['profilePic'] ?? '').toString();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _watchRoom(String code) {
    _roomSub?.cancel();
    _roomSub = ParchiService.roomStream(code).listen((ev) {
      if (!mounted) return;
      final v = ev.snapshot.value;
      if (v == null) {
        if (_code != null) {
          setState(() => _code = null);
          _snack('Room closed');
        }
        return;
      }
      final m = Map<String, dynamic>.from(v as Map);
      final status = (m['status'] ?? 'waiting').toString();
      final players = Map<String, dynamic>.from(m['players'] ?? {});
      if (status == 'started' && m['gameId'] != null) {
        final gameId = m['gameId'].toString();
        _roomSub?.cancel();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => ParchiGameScreen(online: true, gameId: gameId, myId: _uid),
          ));
        }
        return;
      }
      if (status == 'closed') {
        setState(() => _code = null);
        _snack('Host closed the room');
        return;
      }
      setState(() => _players = players);
    });
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final code = await ParchiService.createRoom(fixedEntryFee, _name, _pic);
    if (!mounted) return;
    setState(() => _busy = false);
    if (code == null) { _snack(ParchiService.lastError ?? 'Could not create room'); return; }
    setState(() { _code = code; _isHost = true; });
    _watchRoom(code);
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) { _snack('Enter a valid code'); return; }
    setState(() => _busy = true);
    final err = await ParchiService.joinRoom(code, _name, _pic);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) { _snack(err); return; }
    setState(() { _code = code; _isHost = false; });
    _watchRoom(code);
  }

  Future<void> _start() async {
    if (_players.length < 2) { _snack('Need at least 2 players'); return; }
    setState(() => _busy = true);
    final gameId = await ParchiService.startGame(_code!, fixedEntryFee);
    if (!mounted) return;
    setState(() => _busy = false);
    if (gameId == null) _snack(ParchiService.lastError ?? 'Could not start');
  }

  Future<void> _leave() async {
    if (_code != null) await ParchiService.leaveRoom(_code!);
    _roomSub?.cancel();
    if (mounted) setState(() { _code = null; _isHost = false; _players = {}; });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _code == null,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _leave(); },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: inkColor),
            onPressed: () { if (_code != null) { _leave(); } else { Navigator.pop(context); } },
          ),
          title: Text('16 Parchi — Friends',
              style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, letterSpacing: 1)),
          centerTitle: true,
        ),
        body: SafeArea(child: _code == null ? _home() : _room()),
      ),
    );
  }

  Widget _home() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.front_hand_rounded, color: _accent, size: 44),
        ),
        const SizedBox(height: 12),
        Text('Play 16 Parchi with 2–4 friends',
            style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 16),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.monetization_on_rounded, color: goldColor, size: 16),
          const SizedBox(width: 4),
          Text('Entry $fixedEntryFee • Last one standing takes the pot',
              style: TextStyle(color: ink2Color, fontSize: 12.5)),
        ]),
        const SizedBox(height: 24),

        _bigButton('Create Room', Icons.add_circle_outline_rounded, _accent, _busy ? null : _create),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: Divider(color: lineColor)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('or join', style: TextStyle(color: ink3Color, fontSize: 12))),
          Expanded(child: Divider(color: lineColor)),
        ]),
        const SizedBox(height: 16),

        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 5,
          style: TextStyle(color: inkColor, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
          decoration: InputDecoration(
            counterText: '',
            hintText: 'CODE',
            hintStyle: TextStyle(color: ink3Color, letterSpacing: 8),
            filled: true, fillColor: surfaceColor,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: lineColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _accent, width: 2)),
          ),
        ),
        const SizedBox(height: 12),
        _bigButton('Join Room', Icons.login_rounded, const Color(0xFF1976D2), _busy ? null : _join),
      ]),
    );
  }

  Widget _room() {
    final ids = _players.keys.toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 6),
        Text('ROOM CODE', style: TextStyle(color: ink3Color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () { Clipboard.setData(ClipboardData(text: _code!)); _snack('Code copied'); },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: surfaceColor, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_code!, style: const TextStyle(color: _accent, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 10)),
              const SizedBox(width: 10),
              Icon(Icons.copy_rounded, color: ink3Color, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text('Share this code with friends', style: TextStyle(color: ink3Color, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 20),

        Row(children: [
          Text('Players', style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: surface2Color, borderRadius: BorderRadius.circular(999)),
            child: Text('${ids.length}/${ParchiService.maxPlayers}', style: TextStyle(color: ink2Color, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final id = ids[i];
              final p = Map<String, dynamic>.from(_players[id]);
              final pic = (p['pic'] ?? '').toString();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: lineColor)),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: surface2Color, backgroundImage: pic.isEmpty ? null : NetworkImage(pic), child: pic.isEmpty ? Icon(Icons.person, color: ink3Color, size: 18) : null),
                  const SizedBox(width: 12),
                  Expanded(child: Text((p['name'] ?? 'Player').toString(), style: TextStyle(color: inkColor, fontWeight: FontWeight.w700))),
                  if (id == _uid) Text('You', style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              );
            },
          ),
        ),

        if (_isHost)
          _bigButton(_busy ? 'Starting…' : 'Start Game (${ids.length})', Icons.play_arrow_rounded, _accent,
              (_busy || ids.length < 2) ? null : _start)
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: surface2Color, borderRadius: BorderRadius.circular(14)),
            child: Text('Waiting for host to start…', style: TextStyle(color: ink2Color, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  Widget _bigButton(String label, IconData icon, Color color, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: () { if (enabled) { music.play(click); onTap(); } },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      ),
    );
  }
}
