import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';

/// Opened by the middle chat button when the user is not registered at a
/// shelter yet: one tall card explaining why, with the way to register.
class ChatRegisterScreen extends StatelessWidget {
  const ChatRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final regs = context.watch<RegistrationProvider>();
    final reqs = context.watch<RequestProvider>();
    final me = regs.individualOf(session.deviceId);
    final stay = reqs.chatStay(session.deviceId);
    final pending = reqs.pendingStay(session.deviceId);

    // Registered meanwhile (e.g. shelter approved): go straight to the chat.
    if (stay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.chat,
            arguments: '${session.deviceId}|${stay.targetId}',
          );
        }
      });
    }

    final needsAdmin = me == null || me.status != ReviewStatus.approved;
    final (
      String title,
      String text,
      String cta,
      VoidCallback? onTap,
    ) = pending != null
        ? (
            'Waiting for ${pending.targetName}',
            'Your application was sent ${timeAgo(pending.createdAt)}. Chat opens as soon as the shelter registers you.',
            'View my request',
            () => AppRouter.push(context, AppRoutes.request, pending.id),
          )
        : needsAdmin
        ? (
            'Register to start chatting',
            'First register with the admin. After approval you can apply to a shelter and chat with it.',
            'Register now',
            () => AppRouter.push(context, AppRoutes.register),
          )
        : (
            'Register at a shelter',
            'You are approved. Pick a shelter with a free bed and send your application. Once the shelter accepts you, chat opens here.',
            'Register at a shelter',
            () => AppRouter.push(context, AppRoutes.stay),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ScreenUtils.maxContentWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
              child: SizedBox.expand(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 190.h,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF59E0B),
                              Color(0xFFDB2777),
                              Color(0xFF7C3AED),
                            ],
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              right: -24,
                              top: -20,
                              child: Icon(
                                Icons.forum_rounded,
                                size: 150.sp,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(22.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: 48.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(22.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                text,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  height: 1.45,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              SizedBox(height: 18.h),
                              for (final (icon, t) in const [
                                (
                                  Icons.forum_rounded,
                                  'Talk directly with your shelter team',
                                ),
                                (
                                  Icons.bed_rounded,
                                  'Ask about your bed, rules and timings',
                                ),
                                (
                                  Icons.notifications_active_rounded,
                                  'Get replies as instant notifications',
                                ),
                                (
                                  Icons.lock_rounded,
                                  'Private: only you and your shelter see it',
                                ),
                              ])
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 5.h),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(7.r),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          size: 16.sp,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Text(
                                          t,
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
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(22.w, 0, 22.w, 22.h),
                        child: AppButton(
                          label: cta,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: onTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
