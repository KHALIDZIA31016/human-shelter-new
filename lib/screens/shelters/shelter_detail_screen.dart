import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/service_request.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/transfer_provider.dart';
import 'commitment.dart';
import '../../providers/request_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';

/// Shelter profile as users see it. Reads live from the registration, so
/// anything the shelter edits in its own profile appears here immediately.
class ShelterDetailScreen extends StatelessWidget {
  const ShelterDetailScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RegistrationProvider>().byId(shelterId);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shelter')),
        body: const EmptyState(
          icon: Icons.home_work_outlined,
          title: 'Shelter not found',
        ),
      );
    }
    final reqs = context.watch<RequestProvider>();
    final session = context.watch<SessionProvider>();
    final enrolled = reqs.enrolledAt(s.id);
    final myStay = session.persona == Persona.needy
        ? reqs.activeStay(session.deviceId)
        : null;
    final here = myStay != null && myStay.targetId == s.id;
    final chatStay = session.persona == Persona.needy
        ? reqs.chatStay(session.deviceId)
        : null;
    final canChat = chatStay != null && chatStay.targetId == s.id;
    final unread = canChat
        ? context.watch<ChatProvider>().unreadForUser(session.deviceId, s.id)
        : 0;
    final transfer = context.watch<TransferProvider>().openOf(session.deviceId);
    final applyState = _applyState(
      session.persona == Persona.needy
          ? reqs
                .sentBy(session.deviceId)
                .where((r) => r.type == RequestType.stay && r.targetId == s.id)
          : const [],
    );
    final services = [
      for (final c in HelpCategory.values)
        if (s.services.contains(c.name)) c,
    ];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230.h,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              if (canChat)
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: IconButton.filledTonal(
                    tooltip: 'Chat with shelter',
                    onPressed: () => AppRouter.push(
                      context,
                      AppRoutes.chat,
                      '${session.deviceId}|${s.id}',
                    ),
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: const Icon(Icons.chat_rounded),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsetsDirectional.only(
                start: 56.w,
                bottom: 14.h,
                end: 16.w,
              ),
              title: Text(
                s.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ShelterCover(shelter: s, height: 230.h),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ScreenUtils.maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 18.sp,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              '${s.city} · ${s.address}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.neutral,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      _StatStrip(
                        shelter: s,
                        enrolled: enrolled,
                        services: services.length,
                      ),
                      if (here) ...[
                        SizedBox(height: 14.h),
                        _RegisteredCard(
                          stay: myStay,
                          transferText: transfer?.status.label,
                        ),
                      ],
                      if (s.notes.isNotEmpty) ...[
                        const SectionTitle('About'),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.r),
                            child: Text(
                              s.notes,
                              style: TextStyle(fontSize: 14.sp, height: 1.45),
                            ),
                          ),
                        ),
                      ],
                      const SectionTitle('Help available here'),
                      services.isEmpty
                          ? const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'This shelter has not listed its services yet. Ask them directly.',
                                  style: TextStyle(color: AppColors.neutral),
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: [
                                for (final c in services)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      '${c.emoji}  ${c.label}',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                      const SectionTitle('Contact & hours'),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            children: [
                              InfoRow(
                                Icons.person_outline_rounded,
                                'Manager',
                                s.name,
                              ),
                              InfoRow(Icons.phone_outlined, 'Phone', s.phone),
                              if (s.email.isNotEmpty)
                                InfoRow(Icons.email_outlined, 'Email', s.email),
                              InfoRow(
                                Icons.place_outlined,
                                'Address',
                                s.address,
                              ),
                              if (s.hours.isNotEmpty)
                                InfoRow(
                                  Icons.schedule_rounded,
                                  'Hours',
                                  s.hours,
                                ),
                              InfoRow(
                                Icons.event_rounded,
                                'Joined',
                                fmtDate(s.createdAt),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      if (session.persona == Persona.admin)
                        AppButton(
                          label: 'Chat with shelter',
                          icon: Icons.chat_rounded,
                          onPressed: () => AppRouter.push(
                            context,
                            AppRoutes.chat,
                            '${NotificationProvider.adminId}|${s.id}',
                          ),
                        )
                      else ...[
                        if (here) ...[
                          const AppButton(
                            label: 'Checked in',
                            icon: Icons.how_to_reg_rounded,
                            onPressed: null,
                          ),
                          SizedBox(height: 10.h),
                          AppButton(
                            label: 'Withdraw from this shelter',
                            icon: Icons.logout_rounded,
                            outlined: true,
                            color: AppColors.rejected,
                            onPressed: () => _withdraw(context, myStay),
                          ),
                        ] else if (applyState.label != null)
                          AppButton(
                            label: applyState.label!,
                            icon: applyState.icon,
                            onPressed: null,
                          )
                        else
                          AppButton(
                            label: s.availableBeds > 0
                                ? 'Apply for a stay'
                                : 'No beds free right now',
                            icon: Icons.bed_rounded,
                            onPressed: s.availableBeds > 0
                                ? () async {
                                    if (await ensureCanApply(context, s) &&
                                        context.mounted) {
                                      AppRouter.push(
                                        context,
                                        AppRoutes.stay,
                                        s.id,
                                      );
                                    }
                                  }
                                : null,
                          ),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Food',
                                icon: Icons.restaurant_rounded,
                                outlined: true,
                                onPressed: () => AppRouter.push(
                                  context,
                                  AppRoutes.foodForm,
                                  FoodFormArgs(shelterId: s.id),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: AppButton(
                                label: 'Other help',
                                icon: Icons.volunteer_activism_rounded,
                                outlined: true,
                                onPressed: () => AppRouter.push(
                                  context,
                                  AppRoutes.help,
                                  s.id,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _withdraw(BuildContext context, ServiceRequest stay) async {
  final ctl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.logout_rounded, color: AppColors.rejected, size: 40.sp),
      title: const Text(
        'Withdraw from this shelter?',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your bed will be released and the shelter will be told. You can apply to any shelter afterwards.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: ctl,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stay'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rejected),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Withdraw'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final err = await context.read<RequestProvider>().withdrawStay(
    stay.id,
    reason: ctl.text.trim(),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(err ?? 'You withdrew from ${stay.targetName}.')),
  );
}

/// Read-only "you live here" card (not tappable).
class _RegisteredCard extends StatelessWidget {
  const _RegisteredCard({required this.stay, this.transferText});

  final ServiceRequest stay;
  final String? transferText;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData i, String t) => Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 14.sp, color: AppColors.approved),
          SizedBox(width: 5.w),
          Text(
            t,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.approved.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.approved.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: AppColors.approved,
                size: 20.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'YOU ARE REGISTERED HERE',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.approved,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              if (stay.bedLabel != null)
                chip(Icons.bed_rounded, stay.bedLabel!),
              if (stay.arrivalAt != null)
                chip(Icons.login_rounded, 'From ${fmtDate(stay.arrivalAt!)}'),
              if (stay.allottedUntil != null)
                chip(
                  Icons.event_available_rounded,
                  'Until ${fmtDate(stay.allottedUntil!)}',
                ),
              if ((stay.contactPerson ?? '').isNotEmpty)
                chip(Icons.badge_outlined, stay.contactPerson!),
            ],
          ),
          if (transferText != null) ...[
            SizedBox(height: 10.h),
            Text(
              'Change request: $transferText',
              style: TextStyle(
                fontSize: 12.5.sp,
                color: AppColors.pending,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.shelter,
    required this.enrolled,
    required this.services,
  });

  final Registration shelter;
  final int enrolled;
  final int services;

  @override
  Widget build(BuildContext context) {
    final s = shelter;
    final color = s.availableBeds == 0
        ? AppColors.rejected
        : (s.totalBeds > 0 && s.availableBeds / s.totalBeds < 0.25
              ? AppColors.pending
              : AppColors.approved);
    Widget cell(String v, String l, IconData i, Color c) => Expanded(
      child: Column(
        children: [
          Icon(i, color: c, size: 22.sp),
          SizedBox(height: 6.h),
          Text(
            v,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800),
          ),
          Text(
            l,
            style: TextStyle(fontSize: 11.5.sp, color: AppColors.neutral),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Row(
          children: [
            cell(
              '${s.totalBeds - s.availableBeds}/${s.totalBeds}',
              'Beds occupied',
              Icons.bed_rounded,
              color,
            ),
            cell(
              '$enrolled',
              'Enrolled',
              Icons.groups_rounded,
              AppColors.primary,
            ),
            cell(
              '$services',
              'Services',
              Icons.volunteer_activism_rounded,
              AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Directory card: photo header, location, live occupancy and a CTA.
class ShelterCard extends StatelessWidget {
  const ShelterCard({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RegistrationProvider>().byId(shelterId);
    if (s == null || s.kind != RegistrationKind.shelter) {
      return const SizedBox.shrink();
    }
    final enrolled = context.watch<RequestProvider>().enrolledAt(s.id);
    final ratio = s.totalBeds == 0
        ? 0.0
        : (s.totalBeds - s.availableBeds) / s.totalBeds;
    final freeRatio = s.totalBeds == 0 ? 0.0 : s.availableBeds / s.totalBeds;
    final color = s.availableBeds == 0
        ? AppColors.rejected
        : (freeRatio < 0.25 ? AppColors.pending : AppColors.approved);
    final services = [
      for (final c in HelpCategory.values)
        if (s.services.contains(c.name)) c,
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AppRouter.push(context, AppRoutes.shelter, s.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ShelterCover(shelter: s, height: 150.h),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.availableBeds == 0 ? 'FULL' : 'OPEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 14.sp,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                '${s.city} · ${s.address}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5.sp,
                                ),
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
                padding: EdgeInsets.all(16.r),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54.r,
                      height: 54.r,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: ratio,
                              strokeWidth: 5,
                              color: color,
                              backgroundColor: color.withValues(alpha: 0.15),
                            ),
                          ),
                          Text(
                            '${s.totalBeds - s.availableBeds}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.availableBeds == 0
                                ? 'No beds free'
                                : '${s.totalBeds - s.availableBeds}/${s.totalBeds} beds occupied',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '$enrolled enrolled'
                            '${services.isEmpty ? '' : '  ·  ${services.take(4).map((c) => c.emoji).join(' ')}'}',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: AppColors.neutral,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "12/40 beds occupied" with a progress bar.
class BedsBar extends StatelessWidget {
  const BedsBar({super.key, required this.available, required this.total});

  final int available;
  final int total;

  @override
  Widget build(BuildContext context) {
    final occupied = total - available;
    final ratio = total == 0 ? 0.0 : occupied / total;
    final freeRatio = total == 0 ? 0.0 : available / total;
    final color = available == 0
        ? AppColors.rejected
        : (freeRatio < 0.25 ? AppColors.pending : AppColors.approved);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          available == 0
              ? 'Full · $occupied/$total beds occupied'
              : '$occupied/$total beds occupied',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 14.sp,
          ),
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8.h,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

/// Label shown instead of "Apply for a stay" while an application to this
/// shelter is open or was rejected less than 24 hours ago (null = can apply).
({String? label, IconData icon}) _applyState(Iterable<ServiceRequest> mine) {
  final latest = mine.firstOrNull; // newest first
  if (latest == null) return (label: null, icon: Icons.bed_rounded);
  if (latest.isPending) {
    return (label: 'Applied · waiting for reply', icon: Icons.schedule_rounded);
  }
  if (latest.status == ReviewStatus.approved &&
      latest.closedAt == null &&
      latest.endedAt == null) {
    if (latest.fulfilledAt != null) {
      return (label: 'Checked in', icon: Icons.how_to_reg_rounded);
    }
    final at = latest.arrivalAt;
    return (
      label: at == null
          ? 'Applied · approved, check in at the shelter'
          : 'Applied · check in by ${fmtDateTime(at)}',
      icon: Icons.event_available_rounded,
    );
  }
  if (latest.status == ReviewStatus.rejected) {
    final byUser = latest.rejectReason == kUserCancelledNote;
    final retry = (latest.decidedAt ?? latest.createdAt).add(
      byUser ? kReapplyAfterCancel : const Duration(hours: 24),
    );
    final left = retry.difference(DateTime.now());
    if (!left.isNegative) {
      final h = left.inHours;
      final text = h >= 1 ? '${h}h' : '${left.inMinutes.clamp(1, 59)}m';
      return (
        label: byUser
            ? 'Cancelled · apply again in $text'
            : 'Rejected · apply again in $text',
        icon: Icons.lock_clock_rounded,
      );
    }
  }
  return (label: null, icon: Icons.bed_rounded);
}
