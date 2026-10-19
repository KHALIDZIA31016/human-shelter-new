import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/enums.dart';
import '../../providers/notification_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<SessionProvider>().recipientIds;
    final notifs = context.watch<NotificationProvider>();
    final items = notifs.forRecipients(ids);

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        message:
            'Updates about your registration and requests will appear here.',
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenUtils.maxContentWidth,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 8.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${notifs.unreadCount(ids)} unread',
                      style: TextStyle(
                        color: AppColors.neutral,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => notifs.markAllRead(ids),
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                itemCount: items.length,
                separatorBuilder: (_, _) => SizedBox(height: 10.h),
                itemBuilder: (_, i) => _NotificationTile(items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _short(String body) {
  final one = body.replaceAll('\n', ' ').trim();
  final dot = one.indexOf('. ');
  final first = dot > 20 && dot < 110 ? one.substring(0, dot + 1) : one;
  return first.length > 100 ? '${first.substring(0, 97)}…' : first;
}

(IconData, Color, String) notifStyle(AppNotification n) {
  final t = n.title.toLowerCase();
  if (t.contains('reject') || t.contains('closed') || t.contains('notice')) {
    return (Icons.error_outline_rounded, AppColors.rejected, 'Important');
  }
  if (t.contains('approved') ||
      t.contains('completed') ||
      t.contains('upheld')) {
    return (Icons.check_circle_rounded, AppColors.approved, 'Good news');
  }
  return switch (n.kind) {
    NotifKind.registration => (
      Icons.how_to_reg_rounded,
      AppColors.primary,
      'Registration',
    ),
    NotifKind.request => (Icons.inbox_rounded, AppColors.accent, 'Request'),
    NotifKind.decision => (Icons.gavel_rounded, AppColors.approved, 'Decision'),
    NotifKind.complaint => (
      Icons.report_gmailerrorred_rounded,
      AppColors.rejected,
      'Case',
    ),
    NotifKind.chat => (Icons.chat_bubble_rounded, AppColors.primary, 'Message'),
    NotifKind.transfer => (
      Icons.swap_horiz_rounded,
      const Color(0xFF7C3AED),
      'Shelter change',
    ),
    NotifKind.system => (Icons.info_rounded, AppColors.neutral, 'Info'),
  };
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.n);

  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tag) = notifStyle(n);
    return Card(
      color: n.read ? Colors.white : const Color(0xFFF0FDFA),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.read<NotificationProvider>().markRead(n.id);
          AppRouter.push(context, AppRoutes.notification, n.id);
        },
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
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  timeAgo(n.createdAt),
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
                              _short(n.body),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                height: 1.35,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: [
                                Text(
                                  'View details',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14.sp,
                                  color: AppColors.primary,
                                ),
                              ],
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
