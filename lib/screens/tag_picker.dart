import 'package:flutter/material.dart';

import '../functions/friend_service.dart';
import '../helpers/color.dart';
import '../helpers/game_tags.dart';
import 'splash.dart';

class TagPickerScreen extends StatefulWidget {
  const TagPickerScreen({super.key});
  @override
  State<TagPickerScreen> createState() => _TagPickerScreenState();
}

class _TagPickerScreenState extends State<TagPickerScreen> {
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await FriendService.myTags();
    if (!mounted) return;
    setState(() {
      _selected.addAll(tags);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FriendService.saveTags(_selected);
    if (!mounted) return;
    setState(() => _saving = false);
    utils.setSnackbar(context, 'Game tags saved!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              Text('MY GAME TAGS',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                      color: inkColor, letterSpacing: 1.5)),
              const Spacer(),
              const SizedBox(width: 42),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Pick the games you play. We\'ll help you find friends who play the same ones.',
              style: TextStyle(color: ink2Color, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: xColor))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _section('In-App Games', kInAppTags),
                      const SizedBox(height: 16),
                      _section('Other Games You Play', kExternalTags),
                    ],
                  ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _saving ? xColor.withValues(alpha: 0.5) : xColor,
                  boxShadow: _saving ? [] : [BoxShadow(
                      color: xColor.withValues(alpha: 0.35),
                      blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text('Save (${_selected.length} selected)',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, List<GameTag> tags) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(title,
            style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: tags.map((t) {
          final on = _selected.contains(t.id);
          return GestureDetector(
            onTap: () => setState(() {
              on ? _selected.remove(t.id) : _selected.add(t.id);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: on ? t.color.withValues(alpha: 0.15) : surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: on ? t.color.withValues(alpha: 0.7) : lineColor,
                  width: on ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.icon, color: on ? t.color : ink3Color, size: 15),
                const SizedBox(width: 6),
                Text(t.name,
                    style: TextStyle(
                      color: on ? t.color : ink2Color,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    )),
                if (on) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded, color: t.color, size: 14),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}
