import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/registration.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';

/// A person can be registered at one shelter at a time. Returns true when
/// [target] may be applied to. Otherwise warns the user, tells the admin and
/// their current shelter (nobody else), and offers a change request.
Future<bool> ensureCanApply(BuildContext context, Registration target) async {
  final session = context.read<SessionProvider>();
  final reqs = context.read<RequestProvider>();
  final current = reqs.commitmentBlock(session.deviceId, target.id);
  if (current == null) return true;

  final me = context.read<RegistrationProvider>().individualOf(
    session.deviceId,
  );
  await reqs.reportCommitmentConflict(
    current: current,
    userName: me?.name ?? current.requesterName,
    attemptedShelterName: target.displayName,
  );
  if (!context.mounted) return false;

  final change = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Icon(
        Icons.warning_amber_rounded,
        color: AppColors.pending,
        size: 52.sp,
      ),
      title: const Text(
        'You are already committed',
        textAlign: TextAlign.center,
      ),
      content: Text(
        'You are registered at ${current.targetName}. You can be committed to '
        'only one shelter at a time.\n\nTo move to ${target.displayName}, send '
        '${current.targetName} a change request with a valid reason. They will '
        'reply within 24 hours.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stay here'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Request change'),
        ),
      ],
    ),
  );
  if (change == true && context.mounted) {
    AppRouter.push(context, AppRoutes.shelterChange, target.id);
  }
  return false;
}
