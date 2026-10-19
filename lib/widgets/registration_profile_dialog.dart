import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/screen_utils.dart';
import '../data/models/enums.dart';
import '../data/models/registration.dart';
import '../screens/shelter_mode/shelter_common.dart';
import 'app_widgets.dart';
import 'suspension_widgets.dart';

/// Admin popup with everything a user (or partner) submitted. Approved
/// profiles get a blue tick on the photo; others show their status tag.
Future<void> showRegistrationProfile(BuildContext context, Registration r) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: _ProfileBody(r),
    ),
  );
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody(this.r);

  final Registration r;

  @override
  Widget build(BuildContext context) {
    final approved = r.status == ReviewStatus.approved;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 420.w),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.r, 24.r, 20.r, 18.r),
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PersonAvatar(
                        name: r.displayName,
                        imageUrl: r.imageUrl,
                        radius: 44,
                      ),
                      if (approved)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              color: const Color(0xFF1D9BF0),
                              size: 26.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    r.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    r.isPartner ? '${r.kind.label} partner' : 'Registered user',
                    style: TextStyle(fontSize: 13.sp, color: AppColors.neutral),
                  ),
                  SizedBox(height: 10.h),
                  StatusChip(r.status),
                  if (r.suspended) ...[
                    SizedBox(height: 8.h),
                    SuspensionChips(account: r),
                    SizedBox(height: 10.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: AppColors.rejected.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Violation: ${r.suspendReason ?? '—'}',
                            style: const TextStyle(
                              color: AppColors.rejected,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (r.appealPending) ...[
                            SizedBox(height: 6.h),
                            Text('Appeal: ${r.appealText}'),
                            SizedBox(height: 6.h),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => showAppealReview(context, r),
                                icon: const Icon(Icons.gavel_rounded),
                                label: const Text('Review appeal'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.r, 12.r, 20.r, 8.r),
              child: Column(
                children: [
                  InfoRow(
                    Icons.person_outline_rounded,
                    r.isPartner ? 'Contact' : 'Full name',
                    r.name,
                  ),
                  InfoRow(Icons.phone_outlined, 'Phone', r.phone),
                  if (r.email.isNotEmpty)
                    InfoRow(Icons.email_outlined, 'Email', r.email),
                  if (r.age != null)
                    InfoRow(Icons.cake_outlined, 'Age', '${r.age}'),
                  InfoRow(Icons.location_city_rounded, 'City', r.city),
                  InfoRow(Icons.place_outlined, 'Address', r.address),
                  if (!r.isPartner)
                    InfoRow(
                      Icons.groups_rounded,
                      'People with them',
                      '${r.familyMembers}',
                    ),
                  if (r.needs.isNotEmpty)
                    InfoRow(
                      Icons.volunteer_activism_outlined,
                      'Needs',
                      r.needs.join(', '),
                    ),
                  if (r.kind == RegistrationKind.shelter)
                    InfoRow(Icons.bed_outlined, 'Beds', '${r.totalBeds}'),
                  if (r.notes.isNotEmpty)
                    InfoRow(Icons.notes_rounded, 'Notes', r.notes),
                  InfoRow(
                    Icons.schedule_rounded,
                    'Submitted',
                    timeAgo(r.createdAt),
                  ),
                  if (r.status == ReviewStatus.rejected &&
                      (r.rejectReason ?? '').isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 8.h),
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: AppColors.rejected.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Rejected: ${r.rejectReason}',
                        style: TextStyle(
                          color: AppColors.rejected,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.r, 4.r, 20.r, 16.r),
              child: AppButton(
                label: 'Close',
                outlined: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
