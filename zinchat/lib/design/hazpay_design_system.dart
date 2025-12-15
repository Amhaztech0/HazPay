import 'package:flutter/material.dart';
import 'hazpay_colors.dart';

// HazPayColors is now imported from hazpay_colors.dart above

class HazPaySpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class HazPayRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class HazPayTypography {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: HazPayColors.textPrimary,
    letterSpacing: 0.5,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: HazPayColors.textPrimary,
    letterSpacing: 0.2,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: HazPayColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: HazPayColors.textPrimary,
  );
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    color: HazPayColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: HazPayColors.textSecondary,
  );
}

class HazPayShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: HazPayColors.shadow,
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}

// Example reusable card widget
class HazPayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? radius;
  final List<BoxShadow>? shadow;

  const HazPayCard({
    required this.child,
    this.padding,
    this.color,
    this.radius,
    this.shadow,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? HazPayColors.card,
        borderRadius: BorderRadius.circular(radius ?? HazPayRadius.lg),
        boxShadow: shadow ?? HazPayShadows.card,
      ),
      padding: padding ?? EdgeInsets.all(HazPaySpacing.lg),
      child: child,
    );
  }
}
