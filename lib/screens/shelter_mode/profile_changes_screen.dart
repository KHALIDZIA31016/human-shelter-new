import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/profile_change.dart';
import '../../providers/profile_change_provider.dart';
import '../../providers/registration_provider.dart';
import '../../widgets/app_widgets.dart';
import 'shelter_common.dart' show PersonAvatar;

/// Residents' requests to change their profile details. Approve updates the
/// resident's profile; reject leaves it as it is.
class ProfileChangesScreen extends StatelessWidget {
  const ProfileChangesScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ProfileChangeProvider>().forShelter(shelterId);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile changes')),
      body: SafeArea(
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.edit_note_rounded,
                title: 'No change requests',
                message:
                    'When a resident asks to change their profile details, it appears here for your decision.',
              )
            : PageBody(
                child: Column(
                  children: [
                    for (final c in items) ...[
                      _ChangeCard(c),
                      SizedBox(height: 12.h),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard(this.c);

  final ProfileChange c;

  @override
  Widget build(BuildContext context) {
    final person = context.watch<RegistrationProvider>().byId(c.registrationId);
    final (color, label) = switch (c.status) {
      ReviewStatus.pending => (AppColors.pending, 'PENDING'),
      ReviewStatus.approved => (AppColors.approved, 'APPROVED'),
      _ => (AppColors.rejected, 'REJECTED'),
    };
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(
                name: c.userName,
                imageUrl: person?.imageUrl,
                radius: 22,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person?.name ?? c.userName,
                      style: TextStyle(
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Asked ${timeAgo(c.createdAt)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5.sp,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          for (final e in c.changed.entries)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kProfileFields[e.key]!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.sp,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: (c.before[e.key] ?? '').isEmpty
                              ? '—'
                              : c.before[e.key],
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.neutral,
                          ),
                        ),
                        const TextSpan(text: '  →  '),
                        TextSpan(
                          text: e.value.isEmpty ? '—' : e.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ],
              ),
            ),
          if (c.status == ReviewStatus.rejected &&
              (c.rejectReason ?? '').isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Reason: ${c.rejectReason}',
              style: TextStyle(color: AppColors.rejected, fontSize: 13.sp),
            ),
          ],
          if (c.status == ReviewStatus.pending) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rejected,
                      side: BorderSide(
                        color: AppColors.rejected.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () async {
                      final reason = await showReasonSheet(
                        context,
                        title: 'Reject changes by ${c.userName}',
                        quickReasons: const [
                          'Details could not be verified',
                          'Please contact the shelter first',
                        ],
                      );
                      if (reason == null || !context.mounted) return;
                      await context.read<ProfileChangeProvider>().reject(
                        c.id,
                        reason,
                      );
                    },
                    child: const Text('Reject'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        context.read<ProfileChangeProvider>().approve(c.id),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
