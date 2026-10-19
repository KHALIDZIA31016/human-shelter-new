import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/shelter_transfer.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../complaints/complaint_detail_screen.dart';

/// User asks their current shelter to let them move to [toShelterId].
class ShelterChangeScreen extends StatefulWidget {
  const ShelterChangeScreen({super.key, required this.toShelterId});

  final String toShelterId;

  @override
  State<ShelterChangeScreen> createState() => _ShelterChangeScreenState();
}

class _ShelterChangeScreenState extends State<ShelterChangeScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String _quick = '';
  bool _busy = false;

  static const _reasons = [
    'Closer to my family',
    'Closer to work or school',
    'Medical needs',
    'Safety concern',
    'Facilities do not suit me',
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final session = context.read<SessionProvider>();
    final stay = context.read<RequestProvider>().activeStay(session.deviceId);
    if (stay == null) return;
    setState(() => _busy = true);
    final text = [
      if (_quick.isNotEmpty) _quick,
      _reason.text.trim(),
    ].join(' — ');
    final err = await context.read<TransferProvider>().request(
      stay: stay,
      toShelterId: widget.toShelterId,
      reason: text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await showSuccessDialog(
      context,
      title: 'Request sent',
      message:
          '${stay.targetName} received your request. You will get feedback '
          'within 24 hours. If approved, ${context.read<RegistrationProvider>().byId(widget.toShelterId)?.displayName ?? 'the new shelter'} '
          'verifies it and you are moved automatically.',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final stay = context.watch<RequestProvider>().activeStay(session.deviceId);
    final regs = context.watch<RegistrationProvider>();
    final to = regs.byId(widget.toShelterId);
    final from = regs.byId(stay?.targetId);
    return Scaffold(
      appBar: AppBar(title: const Text('Change shelter')),
      body: SafeArea(
        child: stay == null || to == null || from == null
            ? const EmptyState(
                icon: Icons.home_work_outlined,
                title: 'Nothing to change',
                message: 'You are not registered at a shelter right now.',
              )
            : Column(
                children: [
                  Expanded(
                    child: PageBody(
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FormHeader(
                              icon: Icons.swap_horiz_rounded,
                              title: '${from.displayName} → ${to.displayName}',
                              text:
                                  'Your current shelter reviews first (24 hours). The new shelter then verifies.',
                            ),
                            FormSection(
                              step: 1,
                              title: 'Why do you want to move?',
                              subtitle: 'A valid reason is required.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 4.h,
                                    children: [
                                      for (final r in _reasons)
                                        ChoiceChip(
                                          label: Text(r),
                                          selected: _quick == r,
                                          onSelected: (on) => setState(
                                            () => _quick = on ? r : '',
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 14.h),
                                  AppTextField(
                                    controller: _reason,
                                    label: 'Explain in your own words',
                                    icon: Icons.notes_rounded,
                                    maxLines: 4,
                                    maxLength: 400,
                                    validator: (v) =>
                                        (v ?? '').trim().length < 15
                                        ? 'Please give a valid reason (min 15 characters)'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SubmitBar(
                    summary:
                        'Sent to ${from.displayName} only. Reply within 24 hours.',
                    label: 'Send change request',
                    loading: _busy,
                    onPressed: _submit,
                  ),
                ],
              ),
      ),
    );
  }
}

Color transferColor(TransferStatus s) => switch (s) {
  TransferStatus.pendingCurrent => AppColors.pending,
  TransferStatus.pendingAdmin => const Color(0xFF7C3AED),
  TransferStatus.pendingNew => const Color(0xFF2563EB),
  TransferStatus.confirmed => AppColors.accent,
  TransferStatus.completed => AppColors.approved,
  TransferStatus.rejected => AppColors.rejected,
  TransferStatus.cancelled => AppColors.neutral,
};

/// Report text ("Label: value" lines) laid out as rows.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    this.title = 'Resident report',
  });

  final String report;
  final String title;

  @override
  Widget build(BuildContext context) {
    final rows = report.split('\n').where((l) => l.trim().isNotEmpty);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            for (final l in rows)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 3.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 118.w,
                      child: Text(
                        l.contains(': ') ? l.substring(0, l.indexOf(': ')) : '',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: AppColors.neutral,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l.contains(': ') ? l.substring(l.indexOf(': ') + 2) : l,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One screen for everyone involved in a shelter change. What you can do
/// depends on who you are:
///  * current shelter: only "Notify admin" (it cannot approve or decline)
///  * admin: cross-check beds, approve / recommend another shelter / reject
///  * chosen shelter: confirm the bed is now occupied for the user
///  * user: follow progress and submit the final form
class TransferDetailScreen extends StatelessWidget {
  const TransferDetailScreen({super.key, required this.transferId});

  final String transferId;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TransferProvider>().byId(transferId);
    final session = context.watch<SessionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Shelter change')),
      body: SafeArea(
        child: t == null
            ? const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Not found',
              )
            : PageBody(
                child: _Body(t: t, session: session),
              ),
      ),
    );
  }
}

Future<String?> _askText(
  BuildContext context,
  String title, {
  String hint = '',
  bool required = true,
  String action = 'Send',
}) {
  final ctl = TextEditingController();
  String? err;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint, errorText: err),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctl.text.trim();
              if (required && v.length < 3) {
                set(() => err = 'Please write a short note');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}

class _Body extends StatefulWidget {
  const _Body({required this.t, required this.session});

  final ShelterTransfer t;
  final SessionProvider session;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  String? _pick; // admin: shelter chosen for the move

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final session = widget.session;
    final tp = context.read<TransferProvider>();
    final regs = context.watch<RegistrationProvider>();
    final partnerId = session.persona == Persona.partner
        ? session.activePartnerId
        : null;
    final isCurrent = partnerId == t.fromShelterId;
    final isTarget = partnerId == t.toShelterId;
    final isAdmin = session.persona == Persona.admin;
    final isUser =
        session.persona == Persona.needy && session.deviceId == t.userId;
    final c = transferColor(t.status);
    final sees = isAdmin || isCurrent || isTarget || isUser;
    if (!sees) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Private case',
      );
    }
    final showReport = t.report != null && (isAdmin || isCurrent || isTarget);

    Widget step(String title, String? sub, bool done) => Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18.sp,
            color: done ? AppColors.approved : AppColors.neutral,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    '"$sub"',
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
    );

    final hasReport = t.report != null;
    final adminDone = const [
      TransferStatus.pendingNew,
      TransferStatus.confirmed,
      TransferStatus.completed,
    ].contains(t.status);
    final bedDone =
        t.status == TransferStatus.confirmed ||
        t.status == TransferStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${t.fromName} → ${t.toName}',
                style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t.status.label,
                style: TextStyle(
                  color: c,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (t.recommended)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              'Admin recommended ${t.toName} (it has a free bed).',
              style: TextStyle(
                fontSize: 12.5.sp,
                color: const Color(0xFF7C3AED),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        SizedBox(height: 12.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                InfoRow(Icons.person_outline_rounded, 'Resident', t.userName),
                InfoRow(Icons.home_work_outlined, 'Current', t.fromName),
                InfoRow(Icons.home_work_rounded, 'Moving to', t.toName),
                InfoRow(Icons.notes_rounded, 'Reason', t.reason),
                InfoRow(
                  Icons.schedule_rounded,
                  'Sent',
                  fmtDateTime(t.createdAt),
                ),
                if (t.reservedBed != null)
                  InfoRow(Icons.bed_rounded, 'Reserved bed', t.reservedBed!),
              ],
            ),
          ),
        ),
        if (showReport) ...[
          const SectionTitle('Full report'),
          ReportCard(report: t.report!),
          if ((t.currentRemarks ?? '').isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: Callout(
                icon: Icons.comment_rounded,
                color: AppColors.primary,
                title: 'Remarks from ${t.fromName}',
                text: t.currentRemarks!,
              ),
            ),
        ],
        if ((t.adminNote ?? '').isNotEmpty && !isUser) ...[
          SizedBox(height: 10.h),
          Callout(
            icon: Icons.admin_panel_settings_rounded,
            color: const Color(0xFF7C3AED),
            title: 'Admin note',
            text: t.adminNote!,
          ),
        ],
        const SectionTitle('Progress'),
        Card(
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              children: [
                step('Request sent to ${t.fromName}', null, true),
                step('${t.fromName} sends report to admin', null, hasReport),
                step(
                  'Admin cross-checks beds and decides',
                  t.adminNote,
                  adminDone,
                ),
                step('${t.toName} confirms a bed', t.newReply, bedDone),
                step(
                  'You submit the new form · moved',
                  null,
                  t.status == TransferStatus.completed,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // --- current shelter: notify only
        if (isCurrent && t.status == TransferStatus.pendingCurrent) ...[
          const Callout(
            icon: Icons.info_outline_rounded,
            text:
                'You cannot approve or decline this change. Send the full resident report to the admin, who decides.',
          ),
          SizedBox(height: 12.h),
          AppButton(
            label: 'Notify admin with full report',
            icon: Icons.campaign_rounded,
            onPressed: () async {
              final r = await _askText(
                context,
                'Notify admin',
                hint: 'Remarks about this resident (optional)',
                required: false,
                action: 'Send report',
              );
              if (r != null) await tp.notifyAdmin(t.id, remarks: r);
            },
          ),
        ],

        // --- admin: cross-check and decide
        if (isAdmin && t.status == TransferStatus.pendingAdmin) ...[
          const SectionTitle('Cross-check beds'),
          for (final s in regs.approvedShelters.where(
            (s) => s.id != t.fromShelterId,
          ))
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Card(
                child: RadioListTile<String>(
                  value: s.id,
                  groupValue: _pick ?? t.toShelterId,
                  onChanged: s.availableBeds < 1
                      ? null
                      : (v) => setState(() => _pick = v),
                  title: Text(
                    '${s.displayName}${s.id == t.toShelterId ? '  (requested)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    s.availableBeds < 1
                        ? '${s.city} · FULL — no free bed'
                        : '${s.city} · ${s.totalBeds - s.availableBeds}/${s.totalBeds} beds occupied',
                    style: TextStyle(
                      color: s.availableBeds < 1
                          ? AppColors.rejected
                          : AppColors.approved,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Reject',
                  outlined: true,
                  color: AppColors.rejected,
                  onPressed: () async {
                    final r = await _askText(
                      context,
                      'Reject the change',
                      hint: 'Reason (sent to resident and shelter)',
                    );
                    if (r != null)
                      await tp.adminDecision(t.id, approve: false, note: r);
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppButton(
                  label: (_pick ?? t.toShelterId) == t.toShelterId
                      ? 'Approve'
                      : 'Recommend',
                  color: AppColors.approved,
                  onPressed: () async {
                    final r = await _askText(
                      context,
                      'Notify the shelter',
                      hint: 'Note for the shelter (optional)',
                      required: false,
                      action: 'Notify',
                    );
                    if (r == null || !context.mounted) return;
                    final err = await tp.adminDecision(
                      t.id,
                      approve: true,
                      toShelterId: _pick ?? t.toShelterId,
                      note: r,
                    );
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                ),
              ),
            ],
          ),
        ],

        // --- chosen shelter: confirm the bed
        if (isTarget && t.status == TransferStatus.pendingNew) ...[
          Callout(
            icon: Icons.bed_rounded,
            color: const Color(0xFF2563EB),
            title: 'Confirm a bed',
            text:
                'Admin approved ${t.userName} for your shelter. Confirming marks one of your beds as occupied for them and tells the resident to submit their form.',
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cannot take',
                  outlined: true,
                  color: AppColors.rejected,
                  onPressed: () async {
                    final r = await _askText(
                      context,
                      'Why can you not take them?',
                      hint: 'Reason (sent to admin)',
                    );
                    if (r != null) await tp.newDecline(t.id, r);
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppButton(
                  label: 'Bed occupied ✓',
                  color: AppColors.approved,
                  onPressed: () async {
                    final err = await tp.newConfirm(t.id);
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                ),
              ),
            ],
          ),
        ],

        // --- user: final form
        if (isUser && t.status == TransferStatus.confirmed) ...[
          Callout(
            icon: Icons.bed_rounded,
            color: AppColors.approved,
            title: '${t.reservedBed ?? 'Your bed'} is ready at ${t.toName}',
            text:
                'Submit the new form to complete your move. ${t.fromName} will then free your old bed.',
          ),
          SizedBox(height: 12.h),
          AppButton(
            label: 'Fill the new form',
            icon: Icons.assignment_rounded,
            onPressed: () =>
                AppRouter.push(context, AppRoutes.transferForm, t.id),
          ),
        ],
        if (isUser && t.status.isOpen) ...[
          SizedBox(height: 10.h),
          AppButton(
            label: 'Cancel change',
            outlined: true,
            color: AppColors.rejected,
            onPressed: () => tp.userCancel(t.id),
          ),
        ],
        if (isAdmin && t.status != TransferStatus.pendingAdmin)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Callout(
              icon: Icons.visibility_rounded,
              text: 'Admin view: you are notified at every step.',
            ),
          ),
      ],
    );
  }
}

/// The new form the user submits once the chosen shelter confirmed a bed.
class TransferFormScreen extends StatefulWidget {
  const TransferFormScreen({super.key, required this.transferId});

  final String transferId;

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final _note = TextEditingController();
  int? _people;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(int people) async {
    setState(() => _busy = true);
    final err = await context.read<TransferProvider>().userComplete(
      widget.transferId,
      people: people,
      message: _note.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await showSuccessDialog(
      context,
      title: 'You have moved',
      message:
          'You are now registered at the new shelter. Your old bed was released for another person.',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TransferProvider>().byId(widget.transferId);
    final session = context.watch<SessionProvider>();
    final me = context.watch<RegistrationProvider>().individualOf(
      session.deviceId,
    );
    final to = context.watch<RegistrationProvider>().byId(t?.toShelterId);
    return Scaffold(
      appBar: AppBar(title: const Text('Move to new shelter')),
      body: SafeArea(
        child:
            t == null ||
                me == null ||
                to == null ||
                t.status != TransferStatus.confirmed
            ? const EmptyState(
                icon: Icons.assignment_late_outlined,
                title: 'Form not available',
                message:
                    'This form opens once the new shelter has confirmed your bed.',
              )
            : Column(
                children: [
                  Expanded(
                    child: PageBody(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormHeader(
                            icon: Icons.assignment_rounded,
                            title: 'Join ${to.displayName}',
                            text:
                                '${t.reservedBed ?? 'A bed'} is reserved for you. Check your details and submit.',
                          ),
                          FormSection(
                            step: 1,
                            title: 'Your new shelter',
                            child: Column(
                              children: [
                                InfoRow(
                                  Icons.home_work_rounded,
                                  'Shelter',
                                  to.displayName,
                                ),
                                InfoRow(
                                  Icons.place_outlined,
                                  'Location',
                                  '${to.city} · ${to.address}',
                                ),
                                InfoRow(
                                  Icons.bed_rounded,
                                  'Your bed',
                                  t.reservedBed ?? '—',
                                ),
                                InfoRow(
                                  Icons.phone_outlined,
                                  'Contact',
                                  '${to.name} · ${to.phone}',
                                ),
                              ],
                            ),
                          ),
                          FormSection(
                            step: 2,
                            title: 'Your details',
                            child: Column(
                              children: [
                                InfoRow(
                                  Icons.person_outline_rounded,
                                  'Name',
                                  me.name,
                                ),
                                InfoRow(
                                  Icons.phone_outlined,
                                  'Phone',
                                  me.phone,
                                ),
                                if (me.age != null)
                                  InfoRow(
                                    Icons.cake_outlined,
                                    'Age',
                                    '${me.age}',
                                  ),
                                SizedBox(height: 8.h),
                                CountStepper(
                                  label: 'People moving with you',
                                  value: _people ?? me.familyMembers,
                                  max: 20,
                                  onChanged: (v) => setState(() => _people = v),
                                ),
                              ],
                            ),
                          ),
                          FormSection(
                            step: 3,
                            title: 'Message to the new shelter',
                            child: AppTextField(
                              controller: _note,
                              label: 'Message (optional)',
                              icon: Icons.notes_rounded,
                              maxLines: 3,
                              maxLength: 300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SubmitBar(
                    summary: 'Your old bed at ${t.fromName} becomes free',
                    label: 'Submit and move',
                    loading: _busy,
                    onPressed: () => _submit(_people ?? me.familyMembers),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Admin tab: shelter changes waiting for / under review.
class AdminTransfersTab extends StatelessWidget {
  const AdminTransfersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<TransferProvider>().all;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_horiz_rounded,
        title: 'No shelter changes',
        message: 'Residents asking to move to another shelter appear here.',
      );
    }
    return PageBody(
      child: Column(
        children: [
          for (final t in items) ...[
            Card(
              child: ListTile(
                onTap: () => AppRouter.push(context, AppRoutes.transfer, t.id),
                leading: CircleAvatar(
                  backgroundColor: transferColor(
                    t.status,
                  ).withValues(alpha: 0.12),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: transferColor(t.status),
                  ),
                ),
                title: Text(
                  t.userName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${t.fromName} → ${t.toName}\n${t.status.label}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
            SizedBox(height: 10.h),
          ],
        ],
      ),
    );
  }
}

/// Shelter "Cases" tab: shelter-change requests and admin verifications.
class ShelterCasesTab extends StatelessWidget {
  const ShelterCasesTab({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final transfers = context.watch<TransferProvider>().forShelter(shelterId);
    final verifications = context.watch<ComplaintProvider>().forShelter(
      shelterId,
    );
    if (transfers.isEmpty && verifications.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No open cases',
        message: 'Shelter-change requests and admin verifications appear here.',
      );
    }
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transfers.isNotEmpty) ...[
            const SectionTitle('Shelter changes'),
            for (final t in transfers) ...[
              Card(
                child: ListTile(
                  onTap: () =>
                      AppRouter.push(context, AppRoutes.transfer, t.id),
                  leading: CircleAvatar(
                    backgroundColor: transferColor(
                      t.status,
                    ).withValues(alpha: 0.12),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: transferColor(t.status),
                    ),
                  ),
                  title: Text(
                    t.fromShelterId == shelterId
                        ? '${t.userName} wants to leave'
                        : '${t.userName} wants to join',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${t.fromName} → ${t.toName}\n${t.status.label}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ],
          if (verifications.isNotEmpty) ...[
            const SectionTitle('Admin verifications'),
            for (final c in verifications) ...[
              ComplaintCard(
                complaint: c,
                neutral: true,
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
