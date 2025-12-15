import 'package:intl/intl.dart';

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

/// Formats a number as Nigerian Naira currency with commas
/// Example: 101250.00 → ₦101,250.00
String formatNaira(num amount, {int decimals = 2}) {
  final formatter = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: decimals,
  );
  return formatter.format(amount);
}

/// Formats a number with commas without currency symbol
/// Example: 101250 → 101,250
String formatNumber(num number, {int decimals = 0}) {
  final formatter = NumberFormat('#,##0' + (decimals > 0 ? '.${'0' * decimals}' : ''), 'en_NG');
  return formatter.format(number);
}
