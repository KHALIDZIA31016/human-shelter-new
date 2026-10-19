import 'package:flutter/material.dart';

import '../../core/routes/app_router.dart';
import 'auth_flow.dart';
import 'auth_screen.dart';

/// First screen after the splash: always the User sign-in form. The mode
/// button in the top right corner opens the Switch mode screen, where tapping
/// a mode lands on that mode's sign-in.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const _role = AuthRole.user;

  @override
  Widget build(BuildContext context) {
    final info = authRoles[_role]!;
    return AuthScreen(
      roleLabel: info.label,
      color: info.color,
      icon: info.icon,
      onSignedIn: () => AuthFlow.completeSignIn(context, _role),
      onModeChange: () => AppRouter.push(context, AppRoutes.modes),
    );
  }
}
