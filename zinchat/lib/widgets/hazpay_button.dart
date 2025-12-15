import 'package:flutter/material.dart';
import '../design/hazpay_design_system.dart';
import '../design/hazpay_colors.dart';

class HazPayButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool filled;
  final Color? color;
  final double height;

  const HazPayButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.filled = true,
    this.color,
    this.height = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (filled ? HazPayColors.primary : HazPayColors.card);
    final fg = filled ? HazPayColors.onPrimary : HazPayColors.textPrimary;

    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: HazPayColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: child,
      ),
    );
  }
}
