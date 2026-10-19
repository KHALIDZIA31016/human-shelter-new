import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/service_request.dart';
import '../../providers/notification_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/request_widgets.dart';
import '../../widgets/visit_widgets.dart';
import '../shelters/commitment.dart';
import 'home_shell.dart';

// Bottom-nav indexes of the needy shell.
const _tabShelters = 1;
const _tabRequests = 2;

void _goTab(BuildContext c, int i) =>
    c.findAncestorStateOfType<ShellScaffoldState>()?.goTo(i);

class NeedyHomeTab extends StatelessWidget {
  const NeedyHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final regs = context.watch<RegistrationProvider>();
    final requests = context.watch<RequestProvider>().sentBy(session.deviceId);
    final unread = context.watch<NotificationProvider>().unreadCount(
      session.recipientIds,
    );
    final me = regs.individualOf(session.deviceId);
    final open = regs.approvedShelters
        .where((s) => s.availableBeds > 0)
        .toList();

    // Nearest first: same city as the user, then most free beds.
    final city = me?.city.trim().toLowerCase() ?? '';
    open.sort((a, b) {
      final ac = a.city.trim().toLowerCase() == city ? 0 : 1;
      final bc = b.city.trim().toLowerCase() == city ? 0 : 1;
      return ac != bc ? ac - bc : b.availableBeds.compareTo(a.availableBeds);
    });

    final visits = requests
        .where((r) => r.type != RequestType.donation)
        .toList();
    final next = _nextVisit(visits);
    final pending = requests.where((r) => r.isPending).length;

    return PageBody(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Until a shelter has approved the user, the shelter registration
          // card leads; afterwards it is replaced by the auto-scroll cards.
          if (context.watch<RequestProvider>().chatStay(session.deviceId) !=
              null) ...[
            _HeroCarousel(me: me, unread: unread),
            SizedBox(height: 14.h),
          ] else if (me?.isApproved == true) ...[
            const _ShelterRegisterCard(),
            SizedBox(height: 14.h),
          ],
          if (context.watch<RequestProvider>().frozenBy(session.deviceId)
              case final hold?) ...[
            Callout(
              icon: Icons.lock_clock_rounded,
              color: AppColors.rejected,
              title: 'Account on hold',
              text:
                  'You were due at ${hold.targetName} at '
                  '${fmtDateTime(hold.arrivalAt!)} and are not checked in. '
                  'You can chat with the shelter. New requests unlock once '
                  'the shelter checks you in.',
            ),
            SizedBox(height: 14.h),
          ],
          _StatusCard(me: me),
          SectionTitle(
            'Right now',
            trailing: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                textStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () => _goTab(context, _tabShelters),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Visit all'),
                  SizedBox(width: 2.w),
                  Icon(Icons.arrow_forward_rounded, size: 16.sp),
                ],
              ),
            ),
          ),
          _LiveStats(
            shelters: regs.approvedShelters.length,
            freeBeds: regs.freeBeds,
            pending: pending,
          ),
          if (next != null) ...[
            SectionTitle(
              'Your next visit',
              trailing: TextButton(
                onPressed: () => AppRouter.push(context, AppRoutes.visits),
                child: const Text('See all'),
              ),
            ),
            _NextVisitCard(request: next),
          ],
          if (visits.isNotEmpty) ...[
            SectionTitle(
              'Recent visits',
              trailing: next == null
                  ? TextButton(
                      onPressed: () =>
                          AppRouter.push(context, AppRoutes.visits),
                      child: const Text('See all'),
                    )
                  : null,
            ),
            SizedBox(
              height: 164.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: visits.take(6).length,
                separatorBuilder: (_, _) => SizedBox(width: 12.w),
                itemBuilder: (_, i) => VisitMiniCard(request: visits[i]),
              ),
            ),
          ],
          SectionTitle('What do you need?'),
          _Actions(
            me: me,
            open: open,
            stay: context.watch<RequestProvider>().activeStay(session.deviceId),
          ),
        ],
      ),
    );
  }

  /// Soonest approved visit that is still ahead of the person (or due now).
  static ServiceRequest? _nextVisit(List<ServiceRequest> all) {
    final up =
        all.where((r) {
          final st = r.visitState;
          return st == VisitState.upcoming || st == VisitState.due;
        }).toList()..sort(
          (a, b) => (a.arrivalAt ?? a.createdAt).compareTo(
            b.arrivalAt ?? b.createdAt,
          ),
        );
    return up.isEmpty ? null : up.first;
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

// Network photos behind the Home carousel slides. If one cannot load (offline)
// the slide's gradient shows instead.
const _heroPhoto =
    'https://images.unsplash.com/photo-1582213782179-e0d53f98f2ca?auto=format&fit=crop&w=900&q=70';
const _emergencyPhoto =
    'https://images.unsplash.com/photo-1587745416684-47953f16f02f?auto=format&fit=crop&w=900&q=70';

void _ignoreImageError(Object _, StackTrace? _) {}

class _Hero extends StatelessWidget {
  const _Hero({required this.me, required this.unread});

  final Registration? me;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final first = (me?.name ?? '').trim().split(' ').first;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF134E4A)],
        ),
        image: DecorationImage(
          image: const NetworkImage(_heroPhoto),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            const Color(0xFF042F2E).withValues(alpha: 0.7),
            BlendMode.srcOver,
          ),
          onError: _ignoreImageError,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10.w,
            bottom: -14.h,
            child: Icon(
              Icons.home_rounded,
              size: 84.sp,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Text(
              first.isEmpty ? _greeting() : '${_greeting()}, $first',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFFDE68A)],
                  ).createShader(r),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'You are not alone.',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -0.8,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 36.w,
                  height: 3.h,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'A safe bed or a warm meal is a few taps away.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (unread > 0) ...[
                      SizedBox(width: 10.w),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => AppRouter.push(context, AppRoutes.alerts),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_active_rounded,
                                size: 16.sp,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                '$unread new update${unread == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.me});

  final Registration? me;

  @override
  Widget build(BuildContext context) {
    final r = me;
    if (r == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need a place to stay?',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4.h),
              Text(
                'Register once and apply to shelters that have a free bed. '
                'Meals need no sign-up.',
                style: TextStyle(color: AppColors.neutral, fontSize: 13.5.sp),
              ),
              SizedBox(height: 14.h),
              AppButton(
                label: 'Register for help',
                icon: Icons.how_to_reg_rounded,
                onPressed: () => AppRouter.push(context, AppRoutes.register),
              ),
            ],
          ),
        ),
      );
    }
    return switch (r.status) {
      ReviewStatus.pending => const Callout(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.pending,
        title: 'Registration under review',
        text: 'Admin will respond within 24–48 hours. We will notify you.',
      ),
      ReviewStatus.approved => const SizedBox.shrink(),
      _ => Column(
        children: [
          Callout(
            icon: Icons.cancel_rounded,
            color: AppColors.rejected,
            title: 'Registration rejected',
            text: 'Reason: ${r.rejectReason ?? '—'}',
          ),
          SizedBox(height: 10.h),
          AppButton(
            label: 'Register again',
            outlined: true,
            onPressed: () => AppRouter.push(context, AppRoutes.register),
          ),
        ],
      ),
    };
  }
}

/// Shown until a shelter has registered the user: invites them to apply,
/// or shows the pending application.
class _ShelterRegisterCard extends StatelessWidget {
  const _ShelterRegisterCard();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final reqs = context.watch<RequestProvider>();
    if (reqs.activeStay(session.deviceId) != null)
      return const SizedBox.shrink();
    final pending = reqs.pendingStay(session.deviceId);
    final awaiting = reqs.awaitingStay(session.deviceId);
    final isPending = pending != null || awaiting != null;
    final target = pending ?? awaiting;
    final colors = isPending
        ? const [Color(0xFFD97706), Color(0xFF92400E)]
        : const [Color(0xFF0F766E), Color(0xFF064E3B)];
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34.w,
            top: -34.h,
            child: Container(
              width: 130.r,
              height: 130.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 18.r,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10.w,
            bottom: -18.h,
            child: Icon(
              Icons.home_work_rounded,
              size: 96.sp,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(18.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPending
                            ? Icons.hourglass_top_rounded
                            : Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        awaiting != null
                            ? 'APPROVED · NOT CHECKED IN'
                            : isPending
                            ? 'APPLICATION SENT'
                            : 'NOT REGISTERED YET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5.sp,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  awaiting != null
                      ? 'Go to ${awaiting.targetName}'
                      : isPending
                      ? 'Waiting for ${pending!.targetName}'
                      : 'Register at a shelter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  awaiting != null
                      ? 'You are registered once the shelter checks you in on arrival.'
                      : isPending
                      ? 'Your application is with the shelter. You will be notified.'
                      : 'Pick a shelter with a free bed to get a safe place and unlock chat.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (awaiting?.arrivalAt != null &&
                    awaiting!.arrivalAt!.isAfter(DateTime.now())) ...[
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      SizedBox(width: 6.w),
                      Countdown(
                        target: awaiting.arrivalAt!,
                        prefix: 'Reach in ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 14.h),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colors.first,
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 12.h,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => isPending
                      ? AppRouter.push(context, AppRoutes.request, target!.id)
                      : AppRouter.push(context, AppRoutes.stay),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(isPending ? 'View' : 'Register'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextVisitCard extends StatelessWidget {
  const _NextVisitCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final st = r.visitState;
    final color = visitColor(st);
    return Card(
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => AppRouter.push(context, AppRoutes.request, r.id),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: color.withValues(alpha: 0.14),
                child: r.helpCategory != null
                    ? Text(
                        r.helpCategory!.emoji,
                        style: TextStyle(fontSize: 22.sp),
                      )
                    : Icon(requestIcon(r.type), color: color),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      maxLines: 1,
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
                        fontSize: 12.5.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        VisitStateChip(st),
                        SizedBox(width: 8.w),
                        Expanded(child: visitTimeLine(r, size: 12.5)),
                      ],
                    ),
                    if (r.arrivalAt != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          '${r.type.whenLabel}: ${fmtDateTime(r.arrivalAt!)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.neutral,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.me, required this.open, this.stay});

  final Registration? me;

  /// Set once the user is checked in: food and bed requests are locked.
  final ServiceRequest? stay;

  /// Shelters with free beds, nearest first.
  final List<Registration> open;

  @override
  Widget build(BuildContext context) {
    void toast(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    final approved = me?.isApproved == true;
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        mainAxisExtent: 118.r,
      ),
      children: [
        _ActionTile(
          icon: Icons.restaurant_rounded,
          title: 'Request food',
          subtitle: stay != null
              ? 'Locked while checked in'
              : 'No sign-up needed',
          locked: stay != null,
          onTap: stay != null
              ? () => _showLocked(context, stay!)
              : () => AppRouter.push(
                  context,
                  AppRoutes.foodForm,
                  const FoodFormArgs(),
                ),
        ),
        _ActionTile(
          icon: Icons.bed_rounded,
          title: 'Need a bed',
          subtitle: stay != null
              ? 'Locked while checked in'
              : approved
              ? 'Pick a shelter'
              : 'Register first',
          locked: stay != null,
          onTap: () {
            if (stay != null) {
              _showLocked(context, stay!);
            } else if (approved) {
              if (open.isEmpty) {
                toast('No shelter has a free bed right now. Try again soon.');
              } else {
                () async {
                  final s = open.first;
                  if (await ensureCanApply(context, s) && context.mounted) {
                    AppRouter.push(context, AppRoutes.stay, s.id);
                  }
                }();
              }
            } else if (me?.status == ReviewStatus.pending) {
              toast('Your registration is under review (24–48 hours).');
            } else {
              AppRouter.push(context, AppRoutes.register);
            }
          },
        ),
        _ActionTile(
          icon: Icons.volunteer_activism_rounded,
          title: 'Request help',
          subtitle: 'Clothes, medical, more',
          onTap: () => AppRouter.push(context, AppRoutes.help),
        ),
        _ActionTile(
          icon: Icons.report_gmailerrorred_rounded,
          title: 'Report a problem',
          subtitle: 'Confidential to admin',
          onTap: () => AppRouter.push(context, AppRoutes.complaintForm),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: locked
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : const Color(0xFFE2E8F0),
              width: locked ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 22.h,
                bottom: 22.h,
                child: Container(
                  width: 4.w,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: locked ? 0.5 : 1,
                child: Padding(
                  padding: EdgeInsets.all(14.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              icon,
                              color: AppColors.primary,
                              size: 22.sp,
                            ),
                          ),
                          Icon(
                            locked
                                ? Icons.lock_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18.sp,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.neutral,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (locked)
                Positioned(
                  right: 12.w,
                  top: 12.h,
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 16.sp,
                      color: Colors.white,
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

class _LiveStats extends StatelessWidget {
  const _LiveStats({
    required this.shelters,
    required this.freeBeds,
    required this.pending,
  });

  final int shelters;
  final int freeBeds;
  final int pending;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String v, String l, Color c, int tab) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _goTab(context, tab),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.withValues(alpha: 0.16), c.withValues(alpha: 0.04)],
            ),
            border: Border.all(color: c.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(i, color: Colors.white, size: 18.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                v,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                l,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          tile(
            Icons.home_work_rounded,
            '$shelters',
            'Shelters',
            AppColors.primary,
            _tabShelters,
          ),
          SizedBox(width: 8.w),
          tile(
            Icons.bed_rounded,
            '$freeBeds',
            'Free beds',
            AppColors.approved,
            _tabShelters,
          ),
          SizedBox(width: 8.w),
          tile(
            Icons.hourglass_top_rounded,
            '$pending',
            'Awaiting reply',
            AppColors.pending,
            _tabRequests,
          ),
        ],
      ),
    );
  }
}

/// Emergency slide of the Home carousel.
class _EmergencySlide extends StatelessWidget {
  const _EmergencySlide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
        ),
        image: DecorationImage(
          image: const NetworkImage(_emergencyPhoto),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            const Color(0xFF450A0A).withValues(alpha: 0.7),
            BlendMode.srcOver,
          ),
          onError: _ignoreImageError,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rejected.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10.w,
            bottom: -14.h,
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 84.sp,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emergency_rounded,
                    color: Colors.white,
                    size: 15.sp,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'EMERGENCY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFFDE68A)],
                  ).createShader(r),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'In danger or need urgent help?',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -0.8,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 36.w,
                  height: 3.h,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Call your local emergency number first. Then come back here for a bed or a meal.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

/// Top-of-Home banner: slides sideways by itself every few seconds.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.me, required this.unread});

  final Registration? me;
  final int unread;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  static const _count = 2;
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _count,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 165.h,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                child: _Hero(me: widget.me, unread: widget.unread),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                child: const _EmergencySlide(),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: i == _page ? 18.w : 7.w,
                height: 7.h,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.primary
                      : AppColors.neutral.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Overlay shown when a locked card is tapped while checked in.
void _showLocked(BuildContext context, ServiceRequest stay) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: EdgeInsets.all(22.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.6,
                ),
              ),
              child: Icon(
                Icons.lock_rounded,
                color: AppColors.primary,
                size: 30.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'You are checked in',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8.h),
            Text(
              'You are checked in at ${stay.targetName}, so food and bed '
              'requests are locked. Report a problem or request help from '
              'your shelter instead.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.4,
                color: const Color(0xFF475569),
              ),
            ),
            SizedBox(height: 18.h),
            AppButton(
              label: 'Request help from shelter',
              icon: Icons.volunteer_activism_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                AppRouter.push(context, AppRoutes.help, stay.targetId);
              },
            ),
            SizedBox(height: 10.h),
            AppButton(
              label: 'Report a problem',
              icon: Icons.report_gmailerrorred_rounded,
              outlined: true,
              onPressed: () {
                Navigator.pop(ctx);
                AppRouter.push(context, AppRoutes.complaintForm);
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}
