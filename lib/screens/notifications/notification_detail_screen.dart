import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/request_widgets.dart';
import '../../widgets/visit_widgets.dart';
import 'alerts_tab.dart';

/// Full notification: complete text, what it is about, and a way to open it.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notificationId});

  final String notificationId;

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationProvider>().byId(notificationId);
    if (n == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification')),
        body: const EmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'Not found',
        ),
      );
    }
    final (icon, color, tag) = notifStyle(n);
    final req = context.watch<RequestProvider>().byId(n.refId);
    final complaint = context.watch<ComplaintProvider>().byId(n.refId);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.75)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 24.sp),
                        ),
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      n.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 6.h),
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
              SizedBox(height: 14.h),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(18.r),
                  child: SelectableText(
                    n.body,
                    style: TextStyle(fontSize: 15.sp, height: 1.55),
                  ),
                ),
              ),
              if (req != null) ...[
                const SectionTitle('About this request'),
                Card(
                  child: ListTile(
                    onTap: () =>
                        AppRouter.push(context, AppRoutes.request, req.id),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        requestIcon(req.type),
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      req.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${req.targetName} · ${fmtDate(req.createdAt)}',
                    ),
                    trailing: req.type == RequestType.donation
                        ? StatusChip(req.status)
                        : VisitStateChip(req.visitState),
                  ),
                ),
              ],
              if (complaint != null && n.kind == NotifKind.complaint) ...[
                SizedBox(height: 14.h),
                AppButton(
                  label: 'Open case',
                  icon: Icons.open_in_new_rounded,
                  outlined: true,
                  onPressed: () => AppRouter.push(
                    context,
                    AppRoutes.complaint,
                    complaint.id,
                  ),
                ),
              ],
              if (n.kind == NotifKind.chat && n.refId != null) ...[
                SizedBox(height: 14.h),
                AppButton(
                  label: 'Open chat',
                  icon: Icons.chat_bubble_rounded,
                  onPressed: () =>
                      AppRouter.push(context, AppRoutes.chat, n.refId),
                ),
              ],
              if (n.kind == NotifKind.transfer && n.refId != null) ...[
                SizedBox(height: 14.h),
                AppButton(
                  label: 'Open shelter change',
                  icon: Icons.swap_horiz_rounded,
                  onPressed: () =>
                      AppRouter.push(context, AppRoutes.transfer, n.refId),
                ),
              ],
              if (req != null) ...[
                SizedBox(height: 14.h),
                AppButton(
                  label: 'Open request',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () =>
                      AppRouter.push(context, AppRoutes.request, req.id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
