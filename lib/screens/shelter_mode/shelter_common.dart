import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../../widgets/image_picker_field.dart';

/// Round avatar: photo when there is one, otherwise the first letter.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.color = AppColors.primary,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final letter = Text(
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: radius * 0.85,
      ),
    );
    final url = imageUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.12),
      child: (url == null || url.isEmpty)
          ? letter
          : ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: appImage(url, fallback: Center(child: letter)),
              ),
            ),
    );
  }
}

/// Small coloured number tile ("12 · Residents").
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 18.sp),
            SizedBox(height: 4.h),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5.sp, color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}

/// Wraps [children] tiles into rows of [perRow] equal columns, without any
/// fixed height so large text scales never overflow.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.perRow = 3});

  final List<Widget> children;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += perRow) {
      final slice = children.skip(i).take(perRow).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < perRow; j++) ...[
                if (j > 0) SizedBox(width: 8.w),
                Expanded(child: j < slice.length ? slice[j] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
      if (i + perRow < children.length) rows.add(SizedBox(height: 8.h));
    }
    return Column(children: rows);
  }
}

/// Coloured pill, e.g. "Current".
class Pill extends StatelessWidget {
  const Pill(this.text, this.color, {super.key, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.sp, color: color),
            SizedBox(width: 3.w),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rs 12,500
String rs(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'Rs $buf';
}

/// "3 Mar 2025"
String fmtFullDate(DateTime d) {
  const m = [
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
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// "1 year 2 months", "3 weeks", "5 days" between two dates.
String spanLabel(DateTime from, DateTime to) {
  final days = to.difference(from).inDays;
  if (days < 1) return 'less than a day';
  if (days < 14) return '$days day${days == 1 ? '' : 's'}';
  if (days < 60) return '${days ~/ 7} weeks';
  final months = days ~/ 30;
  if (months < 12) return '$months month${months == 1 ? '' : 's'}';
  final y = months ~/ 12, mo = months % 12;
  return '$y year${y == 1 ? '' : 's'}${mo > 0 ? ' $mo month${mo == 1 ? '' : 's'}' : ''}';
}

enum ResidentState { current, arriving, former }

extension ResidentStateX on ResidentState {
  String get label => switch (this) {
    ResidentState.current => 'Staying now',
    ResidentState.arriving => 'Arriving soon',
    ResidentState.former => 'Left',
  };

  Color get color => switch (this) {
    ResidentState.current => AppColors.approved,
    ResidentState.arriving => AppColors.accent,
    ResidentState.former => AppColors.neutral,
  };
}

/// Everything a shelter knows about one person registered with it.
class Resident {
  Resident(this.userId, this.stays);

  final String userId;

  /// Approved stay requests of this person here, newest first.
  final List<ServiceRequest> stays;

  ServiceRequest get latest => stays.first;
  String get name => latest.requesterName;
  String get phone => latest.phone;

  /// First day this person registered here.
  DateTime get since => stays
      .map((s) => s.arrivalAt ?? s.decidedAt ?? s.createdAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  /// Day the latest stay ended, if it has.
  DateTime? get until => stayEnd(latest);

  ResidentState get state {
    if (stayEnd(latest) != null) return ResidentState.former;
    // Registered here only after the shelter checked them in.
    if (latest.fulfilledAt == null) return ResidentState.arriving;
    return ResidentState.current;
  }

  int get people => latest.approvedPeople ?? latest.people;
}

/// When a stay stopped counting (user left, closed as no-show, or the
/// allotment ran out). Null while it is still running or about to start.
DateTime? stayEnd(ServiceRequest s) {
  if (s.endedAt != null) return s.endedAt;
  if (s.closedAt != null) return s.closedAt;
  final until = s.allottedUntil;
  if (until != null && !until.isAfter(DateTime.now())) return until;
  return null;
}

/// Groups approved stay requests sent to a shelter by person.
List<Resident> residentsRoster(List<ServiceRequest> sentToShelter) {
  final byUser = <String, List<ServiceRequest>>{};
  for (final r in sentToShelter) {
    if (r.type == RequestType.stay && r.status == ReviewStatus.approved) {
      byUser.putIfAbsent(r.requesterId, () => []).add(r);
    }
  }
  final out = [
    for (final e in byUser.entries)
      Resident(
        e.key,
        e.value..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
  ];
  int rank(Resident r) => switch (r.state) {
    ResidentState.current => 0,
    ResidentState.arriving => 1,
    ResidentState.former => 2,
  };
  out.sort((a, b) {
    final c = rank(a).compareTo(rank(b));
    return c != 0 ? c : b.since.compareTo(a.since);
  });
  return out;
}
