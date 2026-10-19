import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/routes/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/screen_utils.dart';
import '../data/models/enums.dart';
import '../data/models/service_request.dart';
import '../providers/request_provider.dart';
import 'app_widgets.dart';
import 'visit_widgets.dart';

IconData requestIcon(RequestType t) => switch (t) {
  RequestType.stay => Icons.bed_rounded,
  RequestType.food => Icons.restaurant_rounded,
  RequestType.donation => Icons.volunteer_activism_rounded,
  RequestType.help => Icons.volunteer_activism_rounded,
};

const _rejectQuick = {
  RequestType.stay: [
    'No free beds available',
    'Not eligible for this shelter',
    'Incomplete details',
  ],
  RequestType.food: [
    'Food stock finished for this meal',
    'Outside our service area',
    'Please request earlier',
  ],
  RequestType.help: [
    'We cannot provide this right now',
    'Stock finished',
    'Outside our service area',
  ],
  RequestType.donation: [
    'We have enough food today',
    'Cannot receive at that time',
    'Storage is full',
  ],
};

/// Approve / reject flows shared by list cards and the detail screen.
class RequestActions {
  RequestActions._();

  static Future<void> approve(BuildContext context, ServiceRequest r) async {
    final decision = await showModalBottomSheet<Decision>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ApproveSheet(request: r),
    );
    if (decision == null || !context.mounted) return;
    final err = await context.read<RequestProvider>().approve(r.id, decision);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? 'Approved. The applicant and admin were notified.',
        ),
        backgroundColor: err == null ? AppColors.approved : AppColors.rejected,
      ),
    );
  }

  static Future<void> reject(BuildContext context, ServiceRequest r) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject ${r.title}',
      quickReasons: _rejectQuick[r.type]!,
    );
    if (reason == null || !context.mounted) return;
    await context.read<RequestProvider>().reject(r.id, reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Rejected. The applicant and admin were notified with your reason.',
        ),
      ),
    );
  }
}

class _ApproveSheet extends StatefulWidget {
  const _ApproveSheet({required this.request});

  final ServiceRequest request;

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  final _form = GlobalKey<FormState>();
  final _contact = TextEditingController();
  final _note = TextEditingController();
  late DateTime _at;
  late int _people;
  String? _timeError;

  ServiceRequest get r => widget.request;

  @override
  void initState() {
    super.initState();
    _people = r.people;
    final now = DateTime.now();
    final day = r.neededDate ?? now;
    _at = isSameDay(day, now)
        ? now.add(const Duration(hours: 2))
        : DateTime(day.year, day.month, day.day, 13);
  }

  @override
  void dispose() {
    _contact.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime.now().subtract(const Duration(days: 0)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null) return;
    setState(() {
      _at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _timeError = null;
    });
  }

  void _submit() {
    final okForm = _form.currentState!.validate();
    final inPast = _at.isBefore(
      DateTime.now().subtract(const Duration(minutes: 1)),
    );
    setState(() => _timeError = inPast ? 'Choose a time in the future' : null);
    if (!okForm || inPast) return;
    Navigator.pop(
      context,
      Decision(
        arrivalAt: _at,
        contactPerson: _contact.text.trim(),
        note: _note.text.trim(),
        approvedPeople: r.type == RequestType.stay ? r.people : _people,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        0,
        20.w,
        MediaQuery.viewInsetsOf(context).bottom + 20.h,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approve ${r.title}',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4.h),
              Text(
                r.type == RequestType.stay
                    ? 'Set the arrival time, who ${r.requesterName} should '
                          'report to and any note. An official approval report '
                          'is saved and sent to the applicant and admin.'
                    : 'Tell ${r.requesterName} when to come and who to meet. '
                          'They and the admin will be notified.',
                style: TextStyle(fontSize: 13.sp, color: AppColors.neutral),
              ),
              SizedBox(height: 14.h),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: r.type.whenLabel,
                    prefixIcon: const Icon(Icons.event_rounded),
                    errorText: _timeError,
                  ),
                  child: Text(
                    fmtDateTime(_at),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              AppTextField(
                controller: _contact,
                label: r.type.contactLabel,
                hint: 'Person name / counter / gate',
                icon: Icons.badge_outlined,
                validator: (v) => v == null || v.trim().length < 2
                    ? 'This is required so the applicant knows where to go'
                    : null,
              ),
              if (r.type != RequestType.stay) ...[
                CountStepper(
                  label: r.type != RequestType.donation
                      ? 'Approved for (people)'
                      : 'Accepted meals',
                  value: _people,
                  max: 500,
                  onChanged: (v) => setState(() => _people = v),
                ),
                SizedBox(height: 14.h),
              ],
              AppTextField(
                controller: _note,
                label: r.type == RequestType.stay
                    ? 'Note on arrival (optional)'
                    : 'Note (optional)',
                icon: Icons.notes_rounded,
                maxLines: 2,
                maxLength: 200,
              ),
              AppButton(
                label: 'Approve & notify',
                icon: Icons.check_rounded,
                color: AppColors.approved,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List card for one request. Shows approve/reject when [canDecide].
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    this.canDecide = false,
    this.showTarget = false,
  });

  final ServiceRequest request;
  final bool canDecide;

  /// Show the shelter name (requester view) instead of the requester name.
  final bool showTarget;

  Widget _line(IconData i, String t) => Padding(
    padding: EdgeInsets.symmetric(vertical: 2.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, size: 15.sp, color: AppColors.neutral),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            t,
            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = request;
    final stripe = r.type == RequestType.donation
        ? statusColor(r.status)
        : visitColor(r.visitState);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRouter.push(context, AppRoutes.request, r.id),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6.w, color: stripe),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(14.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20.r,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              requestIcon(r.type),
                              color: AppColors.primary,
                              size: 20.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  showTarget
                                      ? 'To ${r.targetName}'
                                      : 'From ${r.requesterName} · ${r.phone}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.neutral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          r.type == RequestType.donation
                              ? StatusChip(r.status)
                              : VisitStateChip(r.visitState),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        [
                          r.type.label,
                          if (r.neededDate != null) dayLabel(r.neededDate!),
                          timeAgo(r.createdAt),
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.neutral,
                        ),
                      ),
                      if (canDecide) ...[
                        SizedBox(height: 10.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _line(
                                Icons.person_outline_rounded,
                                r.requesterName,
                              ),
                              _line(Icons.phone_outlined, r.phone),
                              _line(
                                Icons.groups_rounded,
                                '${r.people} ${r.people == 1 ? 'person' : 'people'}',
                              ),
                              if (r.items.isNotEmpty)
                                _line(
                                  Icons.checklist_rounded,
                                  r.items.join(', '),
                                ),
                              if (r.message.isNotEmpty)
                                _line(Icons.notes_rounded, '"${r.message}"'),
                            ],
                          ),
                        ),
                      ],
                      if (r.status == ReviewStatus.approved &&
                          r.arrivalAt != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          '${r.type.whenLabel}: ${fmtDateTime(r.arrivalAt!)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.approved,
                          ),
                        ),
                      ],
                      if (r.status == ReviewStatus.rejected &&
                          r.rejectReason != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          'Reason: ${r.rejectReason}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.rejected,
                          ),
                        ),
                      ],
                      if (canDecide && r.status == ReviewStatus.approved) ...[
                        SizedBox(height: 12.h),
                        FulfilmentBar(request: r),
                      ],
                      if (canDecide && r.isPending) ...[
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.rejected,
                                  side: const BorderSide(
                                    color: AppColors.rejected,
                                  ),
                                ),
                                onPressed: () =>
                                    RequestActions.reject(context, r),
                                child: const Text('Reject'),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.approved,
                                ),
                                onPressed: () =>
                                    RequestActions.approve(context, r),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
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

/// Horizontal filter chips for status lists.
class StatusFilterBar extends StatelessWidget {
  const StatusFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ReviewStatus? selected;
  final ValueChanged<ReviewStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <ReviewStatus?>[
      ReviewStatus.pending,
      ReviewStatus.approved,
      ReviewStatus.rejected,
      null,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: ChoiceChip(
                label: Text(o?.label ?? 'All'),
                selected: selected == o,
                onSelected: (_) => onChanged(o),
              ),
            ),
        ],
      ),
    );
  }
}

/// Several requests sent to the same shelter for the same kind of help,
/// shown as one card ("Applied 3×") that expands to every request.
class RequestGroup {
  RequestGroup(this.category, this.targetId, this.targetName, this.requests);

  final HelpCategory category;
  final String targetId;
  final String targetName;

  /// Newest first.
  final List<ServiceRequest> requests;
}

/// Groups repeats; singles stay as plain requests. Keeps newest-first order.
List<Object> groupRequests(List<ServiceRequest> sorted) {
  final groups = <String, List<ServiceRequest>>{};
  for (final r in sorted) {
    final c = r.helpCategory;
    if (c != null) (groups['${r.targetId}|${c.name}'] ??= []).add(r);
  }
  final out = <Object>[];
  final emitted = <String>{};
  for (final r in sorted) {
    final c = r.helpCategory;
    final key = c == null ? null : '${r.targetId}|${c.name}';
    if (key == null || groups[key]!.length == 1) {
      out.add(r);
    } else if (emitted.add(key)) {
      out.add(RequestGroup(c!, r.targetId, r.targetName, groups[key]!));
    }
  }
  return out;
}

class RequestGroupCard extends StatelessWidget {
  const RequestGroupCard({super.key, required this.group});

  final RequestGroup group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final n = g.requests.length;
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 10.h),
            child: Row(
              children: [
                Text(g.category.emoji, style: TextStyle(fontSize: 22.sp)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${g.category.label} · $n requests',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'All sent to ${g.targetName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: AppColors.neutral,
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
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$n× applied',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < n; i++) ...[
            Padding(
              padding: EdgeInsets.only(left: 6.w, bottom: 4.h),
              child: Text(
                'REQUEST ${n - i} OF $n',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutral,
                ),
              ),
            ),
            RequestCard(request: g.requests[i]),
            if (i < n - 1) SizedBox(height: 12.h),
          ],
        ],
      ),
    );
  }
}

/// Shelter-side actions on an approved order: a live countdown to the arrival
/// time, "Delivered" (enabled once the time is up), or close it as a no-show
/// once [kNoShowGrace] has passed.
class FulfilmentBar extends StatefulWidget {
  const FulfilmentBar({super.key, required this.request});

  final ServiceRequest request;

  @override
  State<FulfilmentBar> createState() => _FulfilmentBarState();
}

class _FulfilmentBarState extends State<FulfilmentBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final days = d.inDays;
    final h = two(d.inHours % 24), m = two(d.inMinutes % 60);
    final sec = two(d.inSeconds % 60);
    return days > 0 ? '${days}d $h:$m:$sec' : '$h:$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.status != ReviewStatus.approved ||
        r.fulfilledAt != null ||
        r.closedAt != null) {
      return const SizedBox.shrink();
    }
    final arrival = r.arrivalAt;
    final left = arrival?.difference(DateTime.now());
    final waiting = left != null && !left.isNegative && left != Duration.zero;
    final can = r.canCloseNoShow;
    final at = r.arrivalAt?.add(kNoShowGrace);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (arrival != null)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: (waiting ? AppColors.primary : AppColors.approved)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (waiting ? AppColors.primary : AppColors.approved)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  waiting
                      ? Icons.timer_rounded
                      : Icons.notifications_active_rounded,
                  color: waiting ? AppColors.primary : AppColors.approved,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waiting ? 'ARRIVES IN' : 'TIME IS UP · CHECK IN NOW',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neutral,
                        ),
                      ),
                      Text(
                        waiting
                            ? _clock(left)
                            : '${r.requesterName} was due at ${fmtTime(arrival)}',
                        style: TextStyle(
                          fontSize: waiting ? 22.sp : 14.sp,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: waiting
                              ? AppColors.primary
                              : AppColors.approved,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rejected,
                  side: BorderSide(
                    color: can ? AppColors.rejected : const Color(0xFFCBD5E1),
                  ),
                ),
                onPressed: can ? () => _close(context) : null,
                icon: const Icon(Icons.event_busy_rounded),
                label: const Text('Close · no-show'),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.approved,
                ),
                onPressed: waiting
                    ? null
                    : () => context.read<RequestProvider>().markDelivered(r.id),
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Delivered'),
              ),
            ),
          ],
        ),
        if (waiting)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              'Delivered unlocks at ${fmtDateTime(arrival!)}.',
              style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
            ),
          )
        else if (!can && at != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              'No-show can be closed after ${fmtDateTime(at)} '
              '(${kNoShowGrace.inHours}h wait).',
              style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
            ),
          ),
      ],
    );
  }

  Future<void> _close(BuildContext context) async {
    final request = widget.request;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close this order?'),
        content: Text(
          'Confirm you waited ${kNoShowGrace.inHours} hours and tried to '
          'contact ${request.requesterName}. A notice will be sent and the '
          'order can be given to someone else.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close with notice'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await context.read<RequestProvider>().closeNoShow(request.id);
    if (!context.mounted || err == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }
}

/// User-side live countdown to the arrival time the shelter set.
class ArrivalTimerPanel extends StatefulWidget {
  const ArrivalTimerPanel({super.key, required this.request});

  final ServiceRequest request;

  @override
  State<ArrivalTimerPanel> createState() => _ArrivalTimerPanelState();
}

class _ArrivalTimerPanelState extends State<ArrivalTimerPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final arrival = r.arrivalAt;
    if (r.status != ReviewStatus.approved ||
        arrival == null ||
        r.fulfilledAt != null ||
        r.closedAt != null ||
        r.endedAt != null) {
      return const SizedBox.shrink();
    }
    final left = arrival.difference(DateTime.now());
    final waiting = left > Duration.zero;
    final color = waiting ? AppColors.primary : AppColors.approved;
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = left.inDays > 0
        ? '${left.inDays}d ${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}'
        : '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              waiting ? Icons.timer_rounded : Icons.directions_walk_rounded,
              color: color,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waiting ? 'TIME LEFT TO REACH' : 'TIME IS UP · GO NOW',
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                  ),
                ),
                if (waiting)
                  Text(
                    clock,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w900,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                else
                  Text(
                    'Reach ${r.targetName} and meet ${r.contactPerson ?? 'the shelter'}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                SizedBox(height: 2.h),
                Text(
                  'Arrival time: ${fmtDateTime(arrival)}',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color statusColor(ReviewStatus s) => switch (s) {
  ReviewStatus.pending => AppColors.pending,
  ReviewStatus.approved => AppColors.approved,
  ReviewStatus.rejected => AppColors.rejected,
  ReviewStatus.cancelled => AppColors.neutral,
};
