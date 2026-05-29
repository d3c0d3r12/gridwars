import 'package:xobattle/helpers/color.dart';
import 'package:flutter/material.dart';

class Alert extends StatelessWidget {
  final Widget title;
  final bool isMultipleAction;
  final List<Widget>? multipleAction;
  final String defaultActionButtonName;
  final onTapActionButton;
  final Widget? content;

  const Alert(
      {Key? key,
      required this.title,
      required this.isMultipleAction,
      this.multipleAction,
      required this.defaultActionButtonName,
      required this.onTapActionButton,
      this.content})
      : assert(onTapActionButton != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      child: AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: lineColor, width: 1),
        ),
        title: title,
        actionsPadding: EdgeInsets.zero,
        actions: isMultipleAction
            ? multipleAction
            : [
                SizedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      child: Text(defaultActionButtonName,
                          style: TextStyle(color: secondarySelectedColor, fontWeight: FontWeight.bold)),
                      onPressed: onTapActionButton,
                    ),
                  ),
                )
              ],
        content: content,
      ),
    );
  }
}
