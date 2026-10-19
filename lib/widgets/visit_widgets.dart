import 'dart:async';

import 'package:flutter/material.dart';

import '../core/routes/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/screen_utils.dart';
import '../data/models/enums.dart';
import '../data/models/service_request.dart';
import 'request_widgets.dart';

Color visitColor(VisitState s) => switch (s) {
  VisitState.pending => AppColors.pending,
  VisitState.upcoming => const Color(0xFF2563EB),
  VisitState.due => AppColors.accent,
  VisitState.delayed => AppColors.rejected,
  VisitState.delivered => AppColors.approved,
  VisitState.registered => AppColors.approved,
  VisitState.missed => AppColors.neutral,
  VisitState.ended => AppColors.neutral,
  VisitState.rejected => AppColors.rejected,
  VisitState.cancelled => AppColors.neutral,
};

IconData visitIcon(VisitState s) => switch (s) {
  VisitState.pending => Icons.hourglass_top_rounded,
  VisitState.upcoming => Icons.schedule_rounded,
  VisitState.due => Icons.directions_walk_rounded,
  VisitState.delayed => Icons.warning_amber_rounded,
  VisitState.delivered => Icons.task_alt_rounded,
  VisitState.registered => Icons.how_to_reg_rounded,
  VisitState.missed => Icons.event_busy_rounded,
  VisitState.ended => Icons.logout_rounded,
  VisitState.rejected => Icons.cancel_rounded,
  VisitState.cancelled => Icons.block_rounded,
};

class VisitStateChip extends StatelessWidget {
  const VisitStateChip(this.state, {super.key});

  final VisitState state;

  @override
  Widget build(BuildContext context) {
    final c = visitColor(state);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visitIcon(state), size: 14.sp, color: c),
          SizedBox(width: 4.w),
          Text(
            state.label,
            style: TextStyle(
              color: c,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live ticking text until [target] ("2h 14m 05s"). Re-renders every second.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.target,
    this.style,
    this.prefix = '',
  });

  final DateTime target;
  final TextStyle? style;
  final String prefix;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  static String format(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (days > 0) return '${days}d ${h}h ${two(m)}m';
    if (d.inHours > 0) return '${d.inHours}h ${two(m)}m ${two(s)}s';
    return '${two(m)}m ${two(s)}s';
  }

  @override
  Widget build(BuildContext context) => Text(
    '${widget.prefix}${format(widget.target.difference(DateTime.now()))}',
    style: widget.style,
  );
}

/// One-line, state-aware time info used on visit cards.
Widget visitTimeLine(ServiceRequest r, {double size = 13}) {
  final s = r.visitState;
  final c = visitColor(s);
  final style = TextStyle(
    fontSize: size.sp,
    fontWeight: FontWeight.w800,
    color: c,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  switch (s) {
    case VisitState.upcoming:
      return r.arrivalAt == null
          ? Text('Scheduled', style: style)
          : Countdown(target: r.arrivalAt!, prefix: 'Starts in ', style: style);
    case VisitState.due:
      return Countdown(
        target: r.arrivalAt!.add(kNoShowGrace),
        prefix: 'Time to go · ',
        style: style,
      );
    case VisitState.delayed:
      return Text('Was due ${timeAgo(r.arrivalAt!)}', style: style);
    case VisitState.registered:
      return Text('Checked in ${timeAgo(r.fulfilledAt!)}', style: style);
    case VisitState.delivered:
      return Text('Done ${timeAgo(r.fulfilledAt!)}', style: style);
    case VisitState.missed:
      return Text('Closed ${timeAgo(r.closedAt!)}', style: style);
    case VisitState.ended:
      return Text(r.endReason ?? 'Ended', style: style);
    case VisitState.pending:
      return Text('Sent ${timeAgo(r.createdAt)}', style: style);
    case VisitState.rejected:
    case VisitState.cancelled:
      return Text(timeAgo(r.decidedAt ?? r.createdAt), style: style);
  }
}

/// Status-screen card: info + status only (notices live in Alerts).
class VisitCard extends StatelessWidget {
  const VisitCard({super.key, required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final s = r.visitState;
    final color = visitColor(s);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRouter.push(context, AppRoutes.request, r.id),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6.w, color: color),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(14.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20.r,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: r.helpCategory != null
                                ? Text(
                                    r.helpCategory!.emoji,
                                    style: TextStyle(fontSize: 20.sp),
                                  )
                                : Icon(requestIcon(r.type), color: color),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  r.targetName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.neutral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          VisitStateChip(s),
                          SizedBox(width: 10.w),
                          Expanded(child: visitTimeLine(r, size: 12.5)),
                        ],
                      ),
                      if (r.arrivalAt != null &&
                          (s == VisitState.upcoming ||
                              s == VisitState.due ||
                              s == VisitState.delayed)) ...[
                        SizedBox(height: 8.h),
                        Text(
                          '${r.type.whenLabel}: ${fmtDateTime(r.arrivalAt!)}'
                          '${(r.contactPerson ?? '').isEmpty ? '' : '  ·  ${r.type.contactLabel}: ${r.contactPerson}'}',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact card for the horizontal "Recent visits" strip on Home.
class VisitMiniCard extends StatelessWidget {
  const VisitMiniCard({super.key, required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final s = r.visitState;
    final color = visitColor(s);
    return SizedBox(
      width: 200.w,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => AppRouter.push(context, AppRoutes.request, r.id),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: r.helpCategory != null
                          ? Text(
                              r.helpCategory!.emoji,
                              style: TextStyle(fontSize: 18.sp),
                            )
                          : Icon(
                              requestIcon(r.type),
                              color: color,
                              size: 18.sp,
                            ),
                    ),
                    const Spacer(),
                    Icon(visitIcon(s), color: color, size: 18.sp),
                  ],
                ),
                Text(
                  r.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  r.targetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
                ),
                VisitStateChip(s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
