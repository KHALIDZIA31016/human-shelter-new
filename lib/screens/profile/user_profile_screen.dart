import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_picker_field.dart';
import 'profile_screen.dart' show confirmLogout;

/// Full, read-only profile of the signed-in user with every detail.
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final me = context.watch<RegistrationProvider>().individualOf(
      session.deviceId,
    );
    final reqs = context.watch<RequestProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: me == null
          ? const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'No profile yet',
              message: 'Register to create your profile.',
            )
          : _Body(
              me: me,
              requests: reqs.sentBy(session.deviceId).length,
              shelter:
                  (reqs.activeStay(session.deviceId) ??
                          reqs.awaitingStay(session.deviceId))
                      ?.targetName,
              checkedIn: reqs.activeStay(session.deviceId) != null,
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.me,
    required this.requests,
    required this.shelter,
    required this.checkedIn,
  });

  final Registration me;
  final int requests;
  final String? shelter;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    String orDash(String s) => s.trim().isEmpty ? '—' : s;
    final fallback = Container(
      color: Colors.white.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        me.name.isEmpty ? '?' : me.name[0].toUpperCase(),
        style: TextStyle(
          fontSize: 40.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
    final hasPhoto = me.imageUrl != null && me.imageUrl!.isNotEmpty;

    return PageBody(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- identity card -------------------------------------------
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, Color(0xFF134E4A)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 96.w,
                      height: 96.w,
                      child: hasPhoto
                          ? appImage(me.imageUrl!, fallback: fallback)
                          : fallback,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        me.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (me.isApproved) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.verified_rounded,
                        color: const Color(0xFF7DD3FC),
                        size: 22.sp,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '${me.city} · Member since ${fmtDate(me.createdAt)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                StatusChip(me.status),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    _Stat('$requests', 'Requests'),
                    SizedBox(width: 8.w),
                    _Stat('${me.familyMembers}', 'Family'),
                    SizedBox(width: 8.w),
                    _Stat(me.age == null ? '—' : '${me.age}', 'Age'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // ---- shelter ---------------------------------------------------
          _Section(
            title: 'Shelter',
            rows: [
              (
                checkedIn ? Icons.home_rounded : Icons.home_outlined,
                'Current shelter',
                shelter == null
                    ? 'Not registered at a shelter'
                    : checkedIn
                    ? shelter!
                    : '$shelter (not checked in yet)',
              ),
            ],
          ),
          _Section(
            title: 'Personal',
            rows: [
              (Icons.person_outline_rounded, 'Full name', me.name),
              (Icons.cake_outlined, 'Age', me.age == null ? '—' : '${me.age}'),
              (Icons.groups_rounded, 'Family members', '${me.familyMembers}'),
            ],
          ),
          _Section(
            title: 'Contact',
            rows: [
              (Icons.phone_outlined, 'Phone', orDash(me.phone)),
              (Icons.email_outlined, 'Email', orDash(me.email)),
            ],
          ),
          _Section(
            title: 'Location',
            rows: [
              (Icons.location_city_rounded, 'City', orDash(me.city)),
              (Icons.place_outlined, 'Address', orDash(me.address)),
            ],
          ),
          if (me.needs.isNotEmpty)
            _Card(
              title: 'Needs',
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [for (final n in me.needs) Chip(label: Text(n))],
              ),
            ),
          if (me.notes.trim().isNotEmpty)
            _Card(
              title: 'My situation',
              child: Text(me.notes, style: TextStyle(fontSize: 14.sp)),
            ),
          _Section(
            title: 'Account',
            rows: [
              (Icons.fingerprint_rounded, 'Member ID', me.id),
              (Icons.event_rounded, 'Registered on', fmtDateTime(me.createdAt)),
              if (me.reviewedAt != null)
                (
                  Icons.fact_check_rounded,
                  'Reviewed on',
                  fmtDateTime(me.reviewedAt!),
                ),
              if (me.status == ReviewStatus.rejected &&
                  (me.rejectReason ?? '').isNotEmpty)
                (Icons.info_outline_rounded, 'Reject reason', me.rejectReason!),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      AppRouter.push(context, AppRoutes.myProfileEdit),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit profile'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => confirmLogout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rejected,
                    side: const BorderSide(color: AppColors.rejected),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 14.h),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) => _Card(
    title: title,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 18.h, color: const Color(0xFFE2E8F0)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(rows[i].$1, size: 18.sp, color: AppColors.primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rows[i].$2,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.neutral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      rows[i].$3,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
