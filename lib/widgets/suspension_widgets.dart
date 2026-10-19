import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/screen_utils.dart';
import '../data/models/registration.dart';
import '../providers/registration_provider.dart';

const _violations = [
  'Privacy rules violation',
  'Fake or misleading information',
  'Abusive or harmful behaviour',
  'Misuse of services',
];

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

// ---------------------------------------------------------------------------
// Admin side
// ---------------------------------------------------------------------------

/// Three-dot menu on account cards: suspend, lift or review an appeal.
class AccountActionsMenu extends StatelessWidget {
  const AccountActionsMenu({super.key, required this.account});

  final Registration account;

  @override
  Widget build(BuildContext context) {
    final r = account;
    return PopupMenuButton<String>(
      tooltip: 'Account actions',
      icon: Badge(
        isLabelVisible: r.appealPending,
        smallSize: 9,
        child: const Icon(Icons.more_vert_rounded),
      ),
      onSelected: (v) {
        switch (v) {
          case 'suspend':
            showSuspendDialog(context, r);
          case 'lift':
            _confirmLift(context, r);
          case 'appeal':
            showAppealReview(context, r);
        }
      },
      itemBuilder: (_) => [
        if (!r.suspended)
          const PopupMenuItem(
            value: 'suspend',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.block_rounded, color: AppColors.rejected),
              title: Text('Suspend account'),
            ),
          ),
        if (r.appealPending)
          const PopupMenuItem(
            value: 'appeal',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.gavel_rounded, color: AppColors.pending),
              title: Text('Review appeal'),
            ),
          ),
        if (r.suspended)
          const PopupMenuItem(
            value: 'lift',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_open_rounded, color: AppColors.approved),
              title: Text('Remove suspension'),
            ),
          ),
      ],
    );
  }
}

/// Red "Suspended" / "Appeal" chips for account cards.
class SuspensionChips extends StatelessWidget {
  const SuspensionChips({super.key, required this.account});

  final Registration account;

  @override
  Widget build(BuildContext context) {
    if (!account.suspended) return const SizedBox.shrink();
    Widget chip(IconData i, String t, Color c) => Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 14.sp, color: c),
          SizedBox(width: 4.w),
          Text(
            t,
            style: TextStyle(
              color: c,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 6.w,
      runSpacing: 4.h,
      children: [
        chip(Icons.block_rounded, 'Suspended', AppColors.rejected),
        if (account.appealPending)
          chip(Icons.gavel_rounded, 'Appeal sent', AppColors.pending),
      ],
    );
  }
}

Future<void> showSuspendDialog(BuildContext context, Registration r) async {
  final reason = TextEditingController();
  String? picked = _violations.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        icon: Icon(Icons.block_rounded, color: AppColors.rejected, size: 40.sp),
        title: Text('Suspend ${r.displayName}?', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'They cannot log in until you remove the suspension. '
                'Their users, services and donations stay untouched.',
              ),
              SizedBox(height: 14.h),
              const Text(
                'Violation',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 6.w,
                children: [
                  for (final v in _violations)
                    ChoiceChip(
                      label: Text(v),
                      selected: picked == v,
                      onSelected: (_) => setState(() => picked = v),
                    ),
                  ChoiceChip(
                    label: const Text('Other'),
                    selected: picked == null,
                    onSelected: (_) => setState(() => picked = null),
                  ),
                ],
              ),
              if (picked == null) ...[
                SizedBox(height: 10.h),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Describe the violation',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rejected),
            onPressed: () {
              if (picked == null && reason.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  await context.read<RegistrationProvider>().suspend(
    r.id,
    picked ?? reason.text.trim(),
  );
  if (context.mounted) _toast(context, '${r.displayName} was suspended.');
}

Future<void> _confirmLift(BuildContext context, Registration r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.lock_open_rounded,
        color: AppColors.approved,
        size: 40.sp,
      ),
      title: const Text('Remove suspension?', textAlign: TextAlign.center),
      content: Text(
        '${r.displayName} will be able to log in again with everything '
        'exactly as it was.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await context.read<RegistrationProvider>().liftSuspension(r.id);
  if (context.mounted) _toast(context, 'Suspension removed.');
}

/// Admin reads the appeal, then removes the suspension or turns it down.
Future<void> showAppealReview(BuildContext context, Registration r) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.gavel_rounded, color: AppColors.pending, size: 40.sp),
      title: Text('Appeal · ${r.displayName}', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledBox(
              'Violation',
              r.suspendReason ?? '—',
              AppColors.rejected,
            ),
            SizedBox(height: 10.h),
            _LabeledBox(
              'Their appeal'
              '${r.appealAt == null ? '' : ' · ${timeAgo(r.appealAt!)}'}',
              r.appealText ?? '—',
              AppColors.pending,
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await _rejectAppeal(context, r);
          },
          child: const Text(
            'Reject appeal',
            style: TextStyle(color: AppColors.rejected),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.approved),
          onPressed: () async {
            Navigator.pop(ctx);
            await context.read<RegistrationProvider>().liftSuspension(r.id);
            if (context.mounted) _toast(context, 'Suspension removed.');
          },
          child: const Text('Remove suspension'),
        ),
      ],
    ),
  );
}

Future<void> _rejectAppeal(BuildContext context, Registration r) async {
  final ctl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reject appeal'),
      content: TextField(
        controller: ctl,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Tell them why (optional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rejected),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Reject'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await context.read<RegistrationProvider>().rejectAppeal(
    r.id,
    ctl.text.trim(),
  );
  if (context.mounted) _toast(context, 'Appeal rejected.');
}

class _LabeledBox extends StatelessWidget {
  const _LabeledBox(this.label, this.text, this.color);

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 4.h),
        Text(text, style: TextStyle(fontSize: 14.sp, height: 1.35)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Owner side (shown at login)
// ---------------------------------------------------------------------------

/// Red alert shown when a suspended partner or user tries to log in. Reads the
/// account live, so it switches to "Appeal sent" the moment they appeal.
Future<void> showSuspendedAlert(BuildContext context, String accountId) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Consumer<RegistrationProvider>(
        builder: (ctx, regs, _) {
          final r = regs.byId(accountId);
          if (r == null || !r.suspended) {
            return const SizedBox.shrink();
          }
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420.w),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(20.r, 26.r, 20.r, 20.r),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(14.r),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.gpp_bad_rounded,
                              color: Colors.white,
                              size: 44.sp,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Account suspended',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(20.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your account was suspended by the admin for '
                            'violating our privacy rules.',
                            style: TextStyle(fontSize: 14.5.sp, height: 1.45),
                          ),
                          SizedBox(height: 14.h),
                          _LabeledBox(
                            'Violation',
                            r.suspendReason ?? 'Privacy rules violation',
                            AppColors.rejected,
                          ),
                          if (r.suspendedAt != null) ...[
                            SizedBox(height: 8.h),
                            Text(
                              'Suspended ${timeAgo(r.suspendedAt!)}',
                              style: TextStyle(
                                color: AppColors.neutral,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                          if ((r.appealResponse ?? '').isNotEmpty &&
                              !r.appealPending) ...[
                            SizedBox(height: 12.h),
                            _LabeledBox(
                              'Admin reply to your last appeal',
                              r.appealResponse!,
                              AppColors.pending,
                            ),
                          ],
                          SizedBox(height: 16.h),
                          if (r.appealPending)
                            _LabeledBox(
                              'Appeal sent · under review',
                              'The admin will review your appeal. You cannot '
                                  'send another until it is reviewed.',
                              AppColors.approved,
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.rejected,
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                ),
                                onPressed: () => _writeAppeal(ctx, r),
                                icon: const Icon(Icons.gavel_rounded),
                                label: const Text('Appeal'),
                              ),
                            ),
                          SizedBox(height: 8.h),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
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
        },
      ),
    ),
  );
}

Future<void> _writeAppeal(BuildContext context, Registration r) async {
  final ctl = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Write your appeal'),
      content: TextField(
        controller: ctl,
        maxLines: 4,
        maxLength: 400,
        decoration: const InputDecoration(
          hintText: 'Explain why the suspension should be removed',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rejected),
          onPressed: () {
            if (ctl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ctl.text.trim());
          },
          child: const Text('Send appeal'),
        ),
      ],
    ),
  );
  if (text == null || !context.mounted) return;
  final err = await context.read<RegistrationProvider>().submitAppeal(
    r.id,
    text,
  );
  if (err != null && context.mounted) _toast(context, err);
}
