import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/screen_utils.dart';
import '../data/models/service_request.dart';
import '../providers/registration_provider.dart';
import '../data/models/approval_report.dart';
import '../screens/shelter_mode/shelter_common.dart' show PersonAvatar;

export '../data/models/approval_report.dart';

/// The official approval report of a stay: who was approved, where, when to
/// arrive, whom to meet and any notice from the shelter.
class ApprovalReportCard extends StatelessWidget {
  const ApprovalReportCard({super.key, required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final person = context.watch<RegistrationProvider>().individualOf(
      r.requesterId,
    );
    final name = person?.name ?? r.requesterName;
    final phone = (person?.phone ?? '').isEmpty ? r.phone : person!.phone;
    final note = (r.decisionNote ?? '').trim();

    Widget row(IconData icon, String label, String value) => Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16.sp, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
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

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            color: AppColors.primary,
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 22.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFICIAL APPROVAL REPORT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'No. ${approvalReportNo(r)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'APPROVED',
                    style: TextStyle(
                      color: AppColors.approved,
                      fontSize: 10.5.sp,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: PersonAvatar(
                        name: name,
                        imageUrl: person?.imageUrl,
                        radius: 32,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 14.sp,
                                color: AppColors.neutral,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutral,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: const Divider(height: 1),
                ),
                row(Icons.home_work_rounded, 'Approved shelter', r.targetName),
                row(
                  Icons.event_available_rounded,
                  'Arrival time',
                  fmtDateTime(r.arrivalAt!),
                ),
                row(
                  Icons.badge_outlined,
                  'Report to on arrival',
                  (r.contactPerson ?? '').isEmpty ? '—' : r.contactPerson!,
                ),
                row(
                  Icons.notes_rounded,
                  'Notice',
                  note.isEmpty ? 'No notice' : note,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            color: const Color(0xFFF8FAFC),
            child: Text(
              'Issued ${fmtDateTime(r.decidedAt ?? r.createdAt)} · ${r.targetName}',
              style: TextStyle(fontSize: 11.5.sp, color: AppColors.neutral),
            ),
          ),
        ],
      ),
    );
  }
}
