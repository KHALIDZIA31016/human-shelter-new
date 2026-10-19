import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../providers/registration_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';

/// True when the active person-in-need user may not enter the app yet:
/// their registration is waiting for / was refused by the admin, or they
/// have not registered at all (users made with "Register myself").
bool isBlockedUser(SessionProvider session, RegistrationProvider regs) {
  final reg = regs.individualOf(session.deviceId);
  if (reg != null) return !reg.isApproved;
  return session.activeUser.needsRegistration;
}

/// Shown instead of the app until the admin approves the user.
/// The close button on top returns to the Switch mode screen.
class ApprovalGateScreen extends StatelessWidget {
  const ApprovalGateScreen({super.key});

  void _close(BuildContext context) => Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(AppRoutes.modes, (_) => false);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final reg = context.watch<RegistrationProvider>().individualOf(
      session.deviceId,
    );
    final status = reg?.status;

    final (
      IconData icon,
      Color color,
      String title,
      String text,
    ) = switch (status) {
      ReviewStatus.pending => (
        Icons.hourglass_top_rounded,
        AppColors.pending,
        'Waiting for admin approval',
        'Your request was sent to the admin. We will update you within 24 hours.',
      ),
      ReviewStatus.rejected => (
        Icons.cancel_rounded,
        AppColors.rejected,
        'Registration not approved',
        'The admin could not approve your registration.'
            '${(reg?.rejectReason ?? '').isEmpty ? '' : '\n\nReason: ${reg!.rejectReason}'}'
            '\n\nYou can register again with correct details.',
      ),
      _ => (
        Icons.hourglass_top_rounded,
        AppColors.pending,
        'Waiting for admin approval',
        'Your request was sent to the admin. We will update you within 24 hours.',
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageBody(
                child: Column(
                  children: [
                    SizedBox(height: 48.h),
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.08),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      child: Container(
                        width: 104.r,
                        height: 104.r,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 52.sp),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        height: 1.45,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: 22.h),
                    if (status == ReviewStatus.rejected)
                      AppButton(
                        label: 'Register again',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () =>
                            AppRouter.push(context, AppRoutes.register),
                      ),
                    if (status != ReviewStatus.rejected)
                      AppButton(
                        label: 'Back',
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => _close(context),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
