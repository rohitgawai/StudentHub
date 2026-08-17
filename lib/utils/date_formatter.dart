const List<String> _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a date-time like `12 Aug 2026 at 2:40 pm`.
String formatEventDateTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'am' : 'pm';
  return '${dt.day} ${_monthShort[dt.month - 1]} ${dt.year} at $hour12:$minute $period';
}

/// Formats a timestamp into relative time (e.g. `Just now`, `5m ago`, `2h ago`, `3d ago`).
String formatTimeAgo(DateTime dt) {
  final nowUtc = DateTime.now().toUtc();
  final dtUtc = dt.toUtc();
  final diff = nowUtc.difference(dtUtc);
  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final local = dt.toLocal();
  return '${local.day} ${_monthShort[local.month - 1]} ${local.year}';
}