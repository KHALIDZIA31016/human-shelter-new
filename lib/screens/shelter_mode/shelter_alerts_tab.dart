import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/app_notification.dart';
import '../../providers/notification_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../notifications/alerts_tab.dart' show notifStyle;
import 'alert_helpers.dart';
import 'shelter_common.dart';

/// Shelter alerts as a day-by-day timeline; each alert names who sent it.
class ShelterAlertsTab extends StatelessWidget {
  const ShelterAlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<SessionProvider>().recipientIds;
    final notifs = context.watch<NotificationProvider>();
    final shown = notifs.forRecipients(ids);
    final unread = shown.where((n) => !n.read).length;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenUtils.maxContentWidth,
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 8.w, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$unread unread · ${shown.length} shown',
                            style: TextStyle(
                              color: AppColors.neutral,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: unread == 0
                              ? null
                              : () => notifs.markAllRead(ids),
                          icon: const Icon(Icons.done_all_rounded),
                          label: const Text('Mark all read'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (shown.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No alerts yet',
                  message:
                      'Updates from users, admin and other shelters will appear here.',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_timelineRows(shown)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _timelineRows(List<AppNotification> items) {
  final rows = <Widget>[];
  DateTime? day;
  for (final n in items) {
    final d = DateUtils.dateOnly(n.createdAt);
    if (day != d) {
      day = d;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
          child: Row(
            children: [
              Icon(Icons.circle, size: 9.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                _dayHeading(d),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutral,
                ),
              ),
              SizedBox(width: 10.w),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
        ),
      );
    }
    rows.add(
      Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: _AlertTile(n),
      ),
    );
  }
  return rows;
}

String _dayHeading(DateTime d) {
  final now = DateUtils.dateOnly(DateTime.now());
  if (d == now) return 'Today';
  if (d == now.subtract(const Duration(days: 1))) return 'Yesterday';
  return fmtFullDate(d);
}

class _AlertTile extends StatelessWidget {
  const _AlertTile(this.n);

  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final (icon, color, _) = notifStyle(n);
    final src = alertSource(n);
    return Card(
      color: n.read ? Colors.white : const Color(0xFFF0FDFA),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAlertPopup(context, n.id),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5.w, color: n.read ? Colors.transparent : color),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(14.r),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(icon, color: color, size: 20.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(src.icon, size: 14.sp, color: src.color),
                                SizedBox(width: 5.w),
                                Flexible(
                                  child: Text(
                                    src.longLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      color: src.color,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  fmtTime(n.createdAt),
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    color: AppColors.neutral,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: n.read
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              n.body.replaceAll('\n', ' '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                height: 1.35,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Marks the alert read and shows it in full. A "Visit" button appears only
/// when the alert is about something that has a screen in the app.
Future<void> showAlertPopup(BuildContext context, String notificationId) async {
  final notifs = context.read<NotificationProvider>();
  final n = notifs.byId(notificationId);
  if (n == null) return;
  await notifs.markRead(n.id);
  if (!context.mounted) return;
  final target = alertTarget(context, n);
  final (icon, color, tag) = notifStyle(n);
  final src = alertSource(n);
  final maxH = MediaQuery.sizeOf(context).height * 0.8;

  final go = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            constraints: BoxConstraints(maxWidth: 480, maxHeight: maxH),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 8.w, 18.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.72)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: Colors.white, size: 22.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '${tag.toUpperCase()} · ${src.longLabel.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11.sp,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 12.w),
                        child: Text(
                          n.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        fmtDateTime(n.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.r),
                    child: SelectableText(
                      n.body,
                      style: TextStyle(
                        fontSize: 15.sp,
                        height: 1.55,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Close'),
                        ),
                      ),
                      if (target != null) ...[
                        SizedBox(width: 10.w),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(ctx, true),
                            icon: Icon(target.icon),
                            label: Text('Visit · ${target.label}'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (go == true && target != null && context.mounted) {
    AppRouter.push(context, target.route, target.args);
  }
}
