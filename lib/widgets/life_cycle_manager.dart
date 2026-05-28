import 'package:xobattle/helpers/constant.dart';
import 'package:xobattle/helpers/utils.dart';
import 'package:flutter/material.dart';

class LifeCycleManager extends StatefulWidget {
  final Widget? child;

  const LifeCycleManager({super.key, this.child});

  @override
  _LifeCycleManagerState createState() => _LifeCycleManagerState();
}

class _LifeCycleManagerState extends State<LifeCycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await music.play(backMusic);
    } else {
      await music.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: widget.child,
    );
  }
}
