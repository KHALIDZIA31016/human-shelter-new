import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/service_request.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/approval_report.dart';
import '../../widgets/image_picker_field.dart';
import '../../widgets/request_widgets.dart';
import '../complaints/complaint_detail_screen.dart';
import 'user_profile_screen.dart';

/// The needy user's profile: personal details plus full request history.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final me = context.watch<RegistrationProvider>().individualOf(
      session.deviceId,
    );
    final reqs = context.watch<RequestProvider>();
    final history = reqs.sentBy(session.deviceId);
    final stay = reqs.activeStay(session.deviceId);
    final approved = approvalReports(history);
    final complaints = context.watch<ComplaintProvider>().by(session.deviceId);

    return PageBody(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(
            me: me,
            onTap: () => me == null
                ? AppRouter.push(context, AppRoutes.register)
                : Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UserProfileScreen(),
                    ),
                  ),
          ),
          SizedBox(height: 14.h),
          if (me == null) ...[
            const Callout(
              icon: Icons.info_outline_rounded,
              color: AppColors.pending,
              title: 'Not registered yet',
              text: 'Register to save your name, phone and location.',
            ),
            SizedBox(height: 10.h),
            AppButton(
              label: 'Register for help',
              icon: Icons.how_to_reg_rounded,
              onPressed: () => AppRouter.push(context, AppRoutes.register),
            ),
          ] else ...[
            const _ShelterTrack(),
            SizedBox(height: 12.h),
            SectionTitle('Manage my account'),
            Card(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const UserProfileScreen(),
                  ),
                ),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: ClipOval(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: (me.imageUrl == null || me.imageUrl!.isEmpty)
                          ? const Icon(
                              Icons.account_circle_rounded,
                              color: AppColors.primary,
                            )
                          : appImage(
                              me.imageUrl!,
                              fallback: const Icon(
                                Icons.account_circle_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                ),
                title: const Text(
                  'My profile',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('View all your details'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
            SizedBox(height: 4.h),
            _RegistrationTile(me: me, stay: stay),
            SizedBox(height: 4.h),
            _SettingTile(
              icon: Icons.edit_rounded,
              title: 'Edit profile',
              subtitle: 'Update your photo, phone and address',
              onTap: () => AppRouter.push(context, AppRoutes.myProfileEdit),
            ),
            _SettingTile(
              icon: Icons.notifications_rounded,
              title: 'Notifications',
              subtitle: 'Replies, approvals and updates',
              onTap: () => AppRouter.push(context, AppRoutes.alerts),
            ),
            _SettingTile(
              icon: Icons.event_available_rounded,
              title: 'My visits',
              subtitle: 'Upcoming and past shelter visits',
              onTap: () => AppRouter.push(context, AppRoutes.visits),
            ),
            _SettingTile(
              icon: Icons.history_rounded,
              title: 'History',
              subtitle: history.isEmpty
                  ? 'No stays or meals yet'
                  : '${history.length} past requests',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              ),
            ),
            _SettingTile(
              icon: Icons.report_gmailerrorred_rounded,
              title: 'Report a problem',
              subtitle: 'Send a complaint to the admin',
              onTap: () => AppRouter.push(context, AppRoutes.complaintForm),
            ),
            _SettingTile(
              icon: Icons.logout_rounded,
              color: AppColors.rejected,
              title: 'Log out',
              subtitle: 'Sign out and return to login',
              onTap: () => confirmLogout(context),
            ),
            if (approved.isNotEmpty) ...[
              SectionTitle('Approved report'),
              for (final r in approved) ...[
                ApprovalReportCard(request: r),
                SizedBox(height: 12.h),
              ],
            ],
          ],
          if (complaints.isNotEmpty) ...[
            SectionTitle('My complaints (${complaints.length})'),
            for (final c in complaints) ...[
              ComplaintCard(
                complaint: c,
                onTap: () => AppRouter.push(context, AppRoutes.complaint, c.id),
              ),
              SizedBox(height: 10.h),
            ],
          ],
        ],
      ),
    );
  }
}

/// Diagonal left edge: the photo ends in an inclined cut.
class _SlantClipper extends CustomClipper<Path> {
  const _SlantClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.34, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.me, required this.onTap});

  final Registration? me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = me?.name ?? 'Guest';
    final url = me?.imageUrl;
    final art = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -20,
            bottom: -10,
            child: Icon(
              Icons.person_rounded,
              size: 210.sp,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 36.w),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 72.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 214.h,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, Color(0xFF134E4A)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width:
                    ScreenUtils.width.clamp(0, ScreenUtils.maxContentWidth) *
                    0.5,
                child: ClipPath(
                  clipper: const _SlantClipper(),
                  child: (url == null || url.isEmpty)
                      ? art
                      : appImage(url, fallback: art),
                ),
              ),
              Positioned.fill(
                right:
                    ScreenUtils.width.clamp(0, ScreenUtils.maxContentWidth) *
                    0.42,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 18.h, 0, 18.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (me != null) StatusChip(me!.status),
                      SizedBox(height: 12.h),
                      if (me != null) ...[
                        _heroLine(Icons.phone_rounded, me!.phone),
                        _heroLine(Icons.location_on_rounded, me!.city),
                        _heroLine(
                          Icons.event_rounded,
                          'Since ${fmtDate(me!.createdAt)}',
                        ),
                      ] else
                        Text(
                          'No registration yet',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13.sp,
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

  Widget _heroLine(IconData i, String t) => Padding(
    padding: EdgeInsets.only(top: 3.h),
    child: Row(
      children: [
        Icon(i, size: 14.sp, color: Colors.white70),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white, fontSize: 12.5.sp),
          ),
        ),
      ],
    ),
  );
}

const _verifiedBlue = Color(0xFF1D9BF0);

enum _Track { unregistered, pending, registered }

/// Where the person stands with a shelter: unregistered, registration
/// pending (applied, or approved but not checked in) or registered (checked
/// in, blue tick). Tap for details.
class _ShelterTrack extends StatelessWidget {
  const _ShelterTrack();

  @override
  Widget build(BuildContext context) {
    final id = context.watch<SessionProvider>().deviceId;
    final reqs = context.watch<RequestProvider>();
    final checkedIn = reqs.activeStay(id);
    final awaiting = reqs.awaitingStay(id);
    final applied = reqs.pendingStay(id);
    final r = checkedIn ?? awaiting ?? applied;
    final track = checkedIn != null
        ? _Track.registered
        : r != null
        ? _Track.pending
        : _Track.unregistered;
    final color = switch (track) {
      _Track.unregistered => AppColors.neutral,
      _Track.pending => AppColors.pending,
      _Track.registered => _verifiedBlue,
    };
    final headline = switch (track) {
      _Track.unregistered => 'Unregistered',
      _Track.pending => 'Registration pending',
      _Track.registered => 'Registered',
    };
    final line = switch (track) {
      _Track.unregistered =>
        'You are not registered at any shelter. Apply from the Shelters tab.',
      _Track.pending =>
        checkedIn == null && awaiting != null
            ? 'Approved by ${awaiting.targetName}. Not checked in yet.'
            : 'Waiting for ${applied!.targetName} to reply.',
      _Track.registered => 'Checked in at ${checkedIn!.targetName}.',
    };

    Widget node(_Track t, String label) {
      final reached = t.index <= track.index;
      final here = t == track;
      final c = here ? color : (reached ? color.withValues(alpha: 0.6) : null);
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 30.r,
              height: 30.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? c : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: reached ? c! : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: Icon(
                t == _Track.registered && here
                    ? Icons.verified_rounded
                    : reached
                    ? Icons.check_rounded
                    : Icons.circle,
                size: reached ? 17.sp : 6.sp,
                color: reached ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: here ? FontWeight.w900 : FontWeight.w600,
                color: here ? color : AppColors.neutral,
              ),
            ),
          ],
        ),
      );
    }

    Widget bar(bool on) => Expanded(
      child: Padding(
        padding: EdgeInsets.only(bottom: 22.h),
        child: Container(
          height: 3,
          color: on ? color.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
        ),
      ),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetails(context, track, r, checkedIn != null),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.r, 16.r, 16.r, 12.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'SHELTER STATUS',
                            style: TextStyle(
                              fontSize: 11.sp,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                              color: AppColors.neutral,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18.sp,
                            color: color,
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          node(_Track.unregistered, 'Unregistered'),
                          bar(track.index >= 1),
                          node(_Track.pending, 'Pending'),
                          bar(track.index >= 2),
                          node(_Track.registered, 'Registered'),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 14.r),
                  color: color.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            headline,
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          if (track == _Track.registered) ...[
                            SizedBox(width: 5.w),
                            Icon(
                              Icons.verified_rounded,
                              color: _verifiedBlue,
                              size: 19.sp,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        line,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: AppColors.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    _Track track,
    ServiceRequest? r,
    bool checkedIn,
  ) {
    final color = switch (track) {
      _Track.unregistered => AppColors.neutral,
      _Track.pending => AppColors.pending,
      _Track.registered => _verifiedBlue,
    };
    Widget row(IconData i, String label, String value) => Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i, size: 16.sp, color: color),
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final title = switch (track) {
      _Track.unregistered => 'Not registered at a shelter',
      _Track.pending =>
        r != null && r.status == ReviewStatus.approved
            ? 'Registration pending'
            : 'Waiting for the shelter',
      _Track.registered => 'Registered',
    };
    final rows = <Widget>[
      if (r != null) ...[
        row(Icons.home_work_rounded, 'Shelter', r.targetName),
        if (r.status == ReviewStatus.approved) ...[
          row(
            Icons.badge_outlined,
            'Ask for on arrival',
            (r.contactPerson ?? '').isEmpty ? '—' : r.contactPerson!,
          ),
          if (r.arrivalAt != null)
            row(
              Icons.event_available_rounded,
              'Arrival time',
              fmtDateTime(r.arrivalAt!),
            ),
          if (r.bedLabel != null) row(Icons.bed_rounded, 'Bed', r.bedLabel!),
          if ((r.decisionNote ?? '').isNotEmpty)
            row(Icons.notes_rounded, 'Notice', r.decisionNote!),
          row(
            Icons.how_to_reg_rounded,
            'Check-in',
            checkedIn
                ? 'Done ${fmtDateTime(r.fulfilledAt!)}'
                : 'Not done yet. The shelter checks you in on arrival.',
          ),
        ] else
          row(Icons.schedule_rounded, 'Applied', fmtDateTime(r.createdAt)),
      ],
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: EdgeInsets.all(22.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    track == _Track.registered
                        ? Icons.verified_rounded
                        : track == _Track.pending
                        ? Icons.hourglass_top_rounded
                        : Icons.home_work_outlined,
                    color: color,
                    size: 30.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              if (r == null)
                Text(
                  'Pick a shelter with a free bed and apply. You are '
                  'registered once the shelter approves you and checks you in '
                  'on arrival.',
                  style: TextStyle(fontSize: 13.5.sp, height: 1.4),
                )
              else
                ...rows,
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (r == null) AppRouter.push(context, AppRoutes.stay);
                  },
                  child: Text(r == null ? 'Find a shelter' : 'Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({required this.me, required this.stay});

  final Registration me;
  final ServiceRequest? stay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => AppRouter.push(context, AppRoutes.myRegistration),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.badge_rounded, color: AppColors.primary),
        ),
        title: const Text(
          'My registration',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Registered ${fmtDate(me.createdAt)} · ${me.status.label}'
          '${stay == null ? '' : ' · ${stay!.targetName}'}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.history});

  final List<ServiceRequest> history;

  @override
  Widget build(BuildContext context) {
    int n(ReviewStatus s) => history.where((r) => r.status == s).length;
    Widget cell(String label, int v, Color c) => Expanded(
      child: Column(
        children: [
          Text(
            '$v',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            cell('Approved', n(ReviewStatus.approved), AppColors.approved),
            cell('Pending', n(ReviewStatus.pending), AppColors.pending),
            cell('Rejected', n(ReviewStatus.rejected), AppColors.rejected),
            cell('Cancelled', n(ReviewStatus.cancelled), AppColors.neutral),
          ],
        ),
      ),
    );
  }
}

/// One past request: what, from which shelter, when, and the outcome.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final details = <String>[
      'Requested ${fmtDateTime(r.createdAt)}',
      if (r.neededDate != null) 'For ${dayLabel(r.neededDate!)}',
      if (r.status == ReviewStatus.approved && r.arrivalAt != null)
        '${r.type.whenLabel}: ${fmtDateTime(r.arrivalAt!)}',
      if (r.bedLabel != null) 'Bed: ${r.bedLabel}',
      if (r.decidedAt != null && r.status != ReviewStatus.approved)
        '${r.status.label} ${fmtDateTime(r.decidedAt!)}',
      if (r.status == ReviewStatus.rejected && r.rejectReason != null)
        'Reason: ${r.rejectReason}',
    ];
    return Card(
      child: ListTile(
        onTap: () => AppRouter.push(context, AppRoutes.request, r.id),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(requestIcon(r.type), color: AppColors.primary),
        ),
        title: Text(
          r.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.type.label} · ${r.targetName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final d in details)
                Text(
                  d,
                  style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
                ),
            ],
          ),
        ),
        trailing: StatusChip(r.status),
      ),
    );
  }
}

Future<void> confirmLogout(BuildContext context) async {
  final nav = Navigator.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will return to the login screen.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await FirebaseAuth.instance.signOut();
  nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
}

/// Every stay, meal and help request the user has made.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.watch<SessionProvider>().deviceId;
    final history = context.watch<RequestProvider>().sentBy(id);
    return Scaffold(
      appBar: AppBar(title: Text('History (${history.length})')),
      body: history.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'No history yet',
              message: 'Stays and meals you request will be listed here.',
            )
          : PageBody(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Summary(history: history),
                  SizedBox(height: 8.h),
                  for (final r in history) _HistoryTile(request: r),
                ],
              ),
            ),
    );
  }
}
