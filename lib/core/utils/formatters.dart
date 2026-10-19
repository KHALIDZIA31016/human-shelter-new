import 'dart:math';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
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

String fmtDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String fmtDateTime(DateTime d) => '${fmtDate(d)} · ${fmtTime(d)}';

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return fmtDate(d);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime d) {
  final now = DateTime.now();
  if (isSameDay(d, now)) return 'Today';
  if (isSameDay(d, now.add(const Duration(days: 1)))) return 'Tomorrow';
  return fmtDate(d);
}

final _rng = Random();

/// Collision-resistant enough id for a local store (swap for server ids later).
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_rng.nextInt(1 << 32).toRadixString(36)}';
