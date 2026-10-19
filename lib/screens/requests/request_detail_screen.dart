import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/request_widgets.dart';

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final r = context.watch<RequestProvider>().byId(requestId);
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: SafeArea(
        child: r == null
            ? const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Request not found',
              )
            : PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54.r,
                            height: 54.r,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              requestIcon(r.type),
                              color: Colors.white,
                              size: 28.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.type.label.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11.sp,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  r.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.all(2.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: StatusChip(r.status),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (r.status == ReviewStatus.approved) _approvedBox(r),
                    if (!session.recipientIds.contains(r.targetId)) ...[
                      SizedBox(height: 12.h),
                      ArrivalTimerPanel(request: r),
                    ],
                    if (r.status == ReviewStatus.rejected)
                      _Banner(
                        icon: Icons.cancel_rounded,
                        color: AppColors.rejected,
                        title: 'Rejected',
                        text: r.rejectReason ?? 'No reason given.',
                      ),
                    if (r.status == ReviewStatus.pending)
                      const _Banner(
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.pending,
                        title: 'Waiting for the shelter',
                        text: 'A decision will arrive as a notification.',
                      ),
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.r, 10.r, 16.r, 10.r),
                        child: Column(
                          children: [
                            _Detail(
                              Icons.person_outline_rounded,
                              'From',
                              r.requesterName,
                            ),
                            _Detail(Icons.phone_outlined, 'Phone', r.phone),
                            _Detail(
                              Icons.home_work_outlined,
                              'Shelter',
                              r.targetName,
                            ),
                            _Detail(
                              Icons.groups_rounded,
                              'People',
                              '${r.people}',
                            ),
                            if (r.category != null)
                              _Detail(
                                Icons.category_rounded,
                                'Category',
                                '${r.category!.emoji} ${r.category!.label}',
                              ),
                            if (r.items.isNotEmpty)
                              _Detail(
                                Icons.checklist_rounded,
                                'Items',
                                r.items.join(', '),
                              ),
                            if (r.meal != null)
                              _Detail(
                                Icons.restaurant_menu_rounded,
                                'Meal',
                                r.meal!.label,
                              ),
                            if (r.neededDate != null)
                              _Detail(
                                Icons.event_rounded,
                                'For',
                                dayLabel(r.neededDate!),
                              ),
                            if (r.message.isNotEmpty)
                              _Detail(
                                Icons.notes_rounded,
                                'Message',
                                r.message,
                              ),
                            _Detail(
                              Icons.schedule_rounded,
                              'Sent',
                              fmtDateTime(r.createdAt),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    if (r.isPending &&
                        session.recipientIds.contains(r.targetId))
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Reject',
                              outlined: true,
                              color: AppColors.rejected,
                              onPressed: () =>
                                  RequestActions.reject(context, r),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: AppButton(
                              label: 'Approve',
                              color: AppColors.approved,
                              onPressed: () =>
                                  RequestActions.approve(context, r),
                            ),
                          ),
                        ],
                      ),
                    if (session.recipientIds.contains(r.targetId))
                      FulfilmentBar(request: r),
                    if (r.isPending &&
                        session.recipientIds.contains(r.requesterId))
                      _CancelButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.transparent,
                              insetPadding: EdgeInsets.symmetric(
                                horizontal: 28.w,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(22.r),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(14.r),
                                      decoration: BoxDecoration(
                                        color: AppColors.rejected.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.event_busy_rounded,
                                        color: AppColors.rejected,
                                        size: 30.sp,
                                      ),
                                    ),
                                    SizedBox(height: 14.h),
                                    Text(
                                      'Cancel this request?',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 19.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 20.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Keep'),
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.rejected,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Cancel it'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (ok == true && context.mounted) {
                            await context.read<RequestProvider>().cancel(r.id);
                          }
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _approvedBox(ServiceRequest r) => Padding(
    padding: EdgeInsets.only(bottom: 4.h),
    child: _Banner(
      icon: Icons.check_circle_rounded,
      color: AppColors.approved,
      title: 'Approved',
      text: [
        '${r.type.whenLabel}: ${fmtDateTime(r.arrivalAt!)}',
        '${r.type.contactLabel}: ${r.contactPerson}',
        if (r.bedLabel != null) 'Your bed: ${r.bedLabel}',
        if (r.approvedPeople != null) 'Approved for: ${r.approvedPeople}',
        if ((r.decisionNote ?? '').isNotEmpty) 'Note: ${r.decisionNote}',
      ].join('\n'),
    ),
  );
}

/// Status banner: tinted card with a colour bar on the left.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5.w, color: color),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14.r),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 24.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 15.sp,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              height: 1.4,
                              color: const Color(0xFF0F172A),
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
    );
  }
}

/// One labelled detail: teal icon tile, small caps label, value below.
class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17.sp, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft red pill button for cancelling a request.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rejected.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 15.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.rejected.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close_rounded, size: 19.sp, color: AppColors.rejected),
              SizedBox(width: 8.w),
              Text(
                'Cancel request',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.rejected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
