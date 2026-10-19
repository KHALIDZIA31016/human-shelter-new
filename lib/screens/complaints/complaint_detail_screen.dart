import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/complaint.dart';
import '../../data/models/enums.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';

Color complaintColor(ComplaintStatus s) => switch (s) {
  ComplaintStatus.open => AppColors.pending,
  ComplaintStatus.verifying => const Color(0xFF2563EB),
  ComplaintStatus.shelterReplied => const Color(0xFF7C3AED),
  ComplaintStatus.upheld => AppColors.rejected,
  ComplaintStatus.dismissed => AppColors.neutral,
};

class ComplaintStatusChip extends StatelessWidget {
  const ComplaintStatusChip(this.status, {super.key});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final c = complaintColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: c,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One screen, three audiences:
///  * admin: full details + actions (ask shelter / uphold / dismiss)
///  * shelter: only a neutral verification question (no complainant info)
///  * complainant: progress and outcome
class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ComplaintProvider>().byId(complaintId);
    final session = context.watch<SessionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Case details')),
      body: SafeArea(
        child: c == null
            ? const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Case not found',
              )
            : PageBody(
                child: switch (session.persona) {
                  Persona.admin => _AdminView(c: c),
                  Persona.partner when session.activePartnerId == c.shelterId =>
                    _ShelterView(c: c),
                  _ => _UserView(c: c),
                },
              ),
      ),
    );
  }
}

Widget _timeline(Complaint c) {
  Widget step(String t, DateTime? at, {bool done = true}) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Row(
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
          child: Text(
            t,
            style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600),
          ),
        ),
        if (at != null)
          Text(
            timeAgo(at),
            style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
          ),
      ],
    ),
  );
  return Column(
    children: [
      step('Complaint submitted', c.createdAt),
      step('Admin asked shelter to verify', c.askedAt, done: c.askedAt != null),
      step('Shelter replied', c.repliedAt, done: c.repliedAt != null),
      step('Admin decision', c.resolvedAt, done: c.resolvedAt != null),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header(this.c, {this.title});

  final Complaint c;
  final String? title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title ?? c.reason.label,
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800),
        ),
      ),
      ComplaintStatusChip(c.status),
    ],
  );
}

class _UserView extends StatelessWidget {
  const _UserView({required this.c});

  final Complaint c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(c),
        SizedBox(height: 12.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                InfoRow(Icons.home_work_outlined, 'Shelter', c.shelterName),
                if (c.requestSummary.isNotEmpty)
                  InfoRow(
                    Icons.receipt_long_rounded,
                    'Request',
                    c.requestSummary,
                  ),
                InfoRow(Icons.notes_rounded, 'Your message', c.message),
                InfoRow(
                  Icons.schedule_rounded,
                  'Sent',
                  fmtDateTime(c.createdAt),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Progress'),
        Card(
          child: Padding(padding: EdgeInsets.all(14.r), child: _timeline(c)),
        ),
        if (c.status.isClosed) ...[
          SizedBox(height: 14.h),
          Callout(
            icon: c.status == ComplaintStatus.upheld
                ? Icons.gavel_rounded
                : Icons.info_outline_rounded,
            color: complaintColor(c.status),
            title: c.status == ComplaintStatus.upheld
                ? 'Complaint upheld'
                : 'Complaint closed',
            text: c.adminNote ?? '',
          ),
        ],
      ],
    );
  }
}

class _ShelterView extends StatefulWidget {
  const _ShelterView({required this.c});

  final Complaint c;

  @override
  State<_ShelterView> createState() => _ShelterViewState();
}

class _ShelterViewState extends State<_ShelterView> {
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _reply(bool confirmed) async {
    if (_note.text.trim().length < 5) {
      setState(
        () => _error = 'Please add a short explanation (min 5 characters)',
      );
      return;
    }
    setState(() => _busy = true);
    await context.read<ComplaintProvider>().shelterReply(
      widget.c.id,
      confirmed: confirmed,
      note: _note.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your answer was sent to the admin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    // Deliberately neutral: no complainant name, phone or complaint text.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(c, title: 'Admin verification'),
        SizedBox(height: 12.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                if (c.requestSummary.isNotEmpty)
                  InfoRow(
                    Icons.receipt_long_rounded,
                    'Service record',
                    c.requestSummary,
                  ),
                if ((c.question ?? '').isNotEmpty)
                  InfoRow(
                    Icons.help_outline_rounded,
                    'Admin asks',
                    c.question!,
                  ),
                InfoRow(
                  Icons.schedule_rounded,
                  'Asked',
                  fmtDateTime(c.askedAt ?? c.createdAt),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14.h),
        if (c.status == ComplaintStatus.verifying) ...[
          Text(
            'Was this service provided by your shelter?',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Explain / evidence',
              errorText: _error,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Not provided',
                  outlined: true,
                  color: AppColors.rejected,
                  onPressed: _busy ? null : () => _reply(false),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppButton(
                  label: 'Yes, provided',
                  color: AppColors.approved,
                  onPressed: _busy ? null : () => _reply(true),
                ),
              ),
            ],
          ),
        ] else ...[
          if (c.shelterNote != null)
            Callout(
              icon: Icons.reply_rounded,
              title: c.shelterConfirmed == true
                  ? 'You confirmed: provided'
                  : 'You answered: not provided',
              text: c.shelterNote!,
              color: AppColors.primary,
            ),
          if (c.status == ComplaintStatus.upheld) ...[
            SizedBox(height: 12.h),
            Callout(
              icon: Icons.gavel_rounded,
              color: AppColors.rejected,
              title: 'Notice from admin',
              text: c.adminNote ?? '',
            ),
          ],
          if (c.status == ComplaintStatus.dismissed) ...[
            SizedBox(height: 12.h),
            const Callout(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.approved,
              title: 'Verification closed',
              text: 'No action is needed from your side.',
            ),
          ],
        ],
      ],
    );
  }
}

class _AdminView extends StatefulWidget {
  const _AdminView({required this.c});

  final Complaint c;

  @override
  State<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<_AdminView> {
  Future<void> _ask() async {
    final q = await _prompt(
      title: 'Ask shelter to verify',
      hint: 'What should the shelter confirm? (optional)',
      required: false,
      action: 'Send to shelter',
    );
    if (q == null || !mounted) return;
    await context.read<ComplaintProvider>().askShelter(widget.c.id, q);
  }

  Future<void> _resolve(bool upheld) async {
    final note = await _prompt(
      title: upheld ? 'Issue notice to shelter' : 'Dismiss complaint',
      hint: upheld
          ? 'Notice text (sent to shelter and user)'
          : 'Reason for dismissal (sent to user)',
      required: true,
      action: upheld ? 'Issue notice' : 'Dismiss',
    );
    if (note == null || !mounted) return;
    await context.read<ComplaintProvider>().resolve(
      widget.c.id,
      upheld: upheld,
      note: note,
    );
  }

  Future<String?> _prompt({
    required String title,
    required String hint,
    required bool required,
    required String action,
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
                final t = ctl.text.trim();
                if (required && t.length < 5) {
                  set(() => err = 'Please write at least 5 characters');
                  return;
                }
                Navigator.pop(ctx, t);
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ComplaintProvider>().byId(widget.c.id) ?? widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(c),
        SizedBox(height: 12.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                InfoRow(
                  Icons.person_outline_rounded,
                  'Complainant',
                  c.complainantName,
                ),
                InfoRow(Icons.phone_outlined, 'Phone', c.phone),
                InfoRow(Icons.home_work_outlined, 'Shelter', c.shelterName),
                if (c.requestSummary.isNotEmpty)
                  InfoRow(
                    Icons.receipt_long_rounded,
                    'Request',
                    c.requestSummary,
                  ),
                InfoRow(Icons.notes_rounded, 'Message', c.message),
                InfoRow(
                  Icons.schedule_rounded,
                  'Sent',
                  fmtDateTime(c.createdAt),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Progress'),
        Card(
          child: Padding(padding: EdgeInsets.all(14.r), child: _timeline(c)),
        ),
        if (c.shelterNote != null) ...[
          SizedBox(height: 12.h),
          Callout(
            icon: Icons.reply_rounded,
            color: c.shelterConfirmed == true
                ? AppColors.approved
                : AppColors.rejected,
            title: c.shelterConfirmed == true
                ? 'Shelter says: service was provided'
                : 'Shelter says: NOT provided',
            text: c.shelterNote!,
          ),
        ],
        if (c.status.isClosed) ...[
          SizedBox(height: 12.h),
          Callout(
            icon: Icons.gavel_rounded,
            color: complaintColor(c.status),
            title: c.status == ComplaintStatus.upheld
                ? 'Upheld · notice issued'
                : 'Dismissed',
            text: c.adminNote ?? '',
          ),
        ] else ...[
          SizedBox(height: 16.h),
          if (c.status == ComplaintStatus.open)
            AppButton(
              label: 'Ask shelter to verify',
              icon: Icons.fact_check_rounded,
              onPressed: _ask,
            ),
          if (c.status == ComplaintStatus.verifying)
            const Callout(
              icon: Icons.hourglass_top_rounded,
              color: AppColors.pending,
              text:
                  'Waiting for the shelter to answer. You can still close the case below.',
            ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Dismiss',
                  outlined: true,
                  color: AppColors.neutral,
                  onPressed: () => _resolve(false),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppButton(
                  label: 'Issue notice',
                  color: AppColors.rejected,
                  icon: Icons.gavel_rounded,
                  onPressed: () => _resolve(true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Compact list row used by the user's profile, admin and shelter lists.
class ComplaintCard extends StatelessWidget {
  const ComplaintCard({
    super.key,
    required this.complaint,
    this.forAdmin = false,
    this.neutral = false,
    required this.onTap,
  });

  final Complaint complaint;
  final bool forAdmin;

  /// Shelter view: hide complaint wording and complainant.
  final bool neutral;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: complaintColor(
                      c.status,
                    ).withValues(alpha: 0.12),
                    child: Icon(
                      neutral
                          ? Icons.fact_check_rounded
                          : Icons.report_gmailerrorred_rounded,
                      color: complaintColor(c.status),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          neutral ? 'Verification request' : c.reason.label,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          neutral
                              ? (c.requestSummary.isEmpty
                                    ? 'Service record'
                                    : c.requestSummary)
                              : forAdmin
                              ? '${c.complainantName} → ${c.shelterName}'
                              : c.shelterName,
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
                  ComplaintStatusChip(c.status),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                timeAgo(neutral ? (c.askedAt ?? c.createdAt) : c.createdAt),
                style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
