import 'package:flutter/material.dart';

extension ColorOpacityExtensions on Color {
  /// Applies opacity via `withAlpha` to avoid the deprecated `withOpacity` call.
  Color withPreciseOpacity(double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    final alpha = (clamped * 255).round().clamp(0, 255);
    return withAlpha(alpha);
  }
}
