import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../data/models/enums.dart';
import '../../providers/registration_provider.dart';
import '../../providers/session_provider.dart';
import '../registration/register_screen.dart';
import '../../widgets/suspension_widgets.dart';
import 'auth_screen.dart';

enum AuthRole { user, partner, admin }

class AuthRoleInfo {
  const AuthRoleInfo({
    required this.label,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
  });

  final String label;
  final String title;
  final String tagline;
  final IconData icon;
  final Color color;
}

const authRoles = <AuthRole, AuthRoleInfo>{
  AuthRole.user: AuthRoleInfo(
    label: 'User',
    title: 'Find help',
    tagline: 'A safe bed, a warm meal, support when you need it.',
    icon: Icons.person_rounded,
    color: Color(0xFF14B8A6),
  ),
  AuthRole.partner: AuthRoleInfo(
    label: 'Partner',
    title: 'Offer help',
    tagline: 'Shelters, restaurants and companies making a difference.',
    icon: Icons.handshake_rounded,
    color: Color(0xFFF59E0B),
  ),
  AuthRole.admin: AuthRoleInfo(
    label: 'Admin',
    title: 'Manage',
    tagline: 'Review requests and keep the community safe.',
    icon: Icons.admin_panel_settings_rounded,
    color: Color(0xFF8B5CF6),
  ),
};

/// Sign in / sign up for every mode (user, partner, admin), shared by the
/// login screen and the Switch mode screen.
class AuthFlow {
  AuthFlow._();

  /// Admin accounts cannot be self-created.
  static bool canSignUp(AuthRole role) => role != AuthRole.admin;

  /// Opens the account creation form for [role]. New accounts are signed out
  /// afterwards and must sign in (partners also wait for admin approval).
  static Future<void> signUp(BuildContext context, AuthRole role) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          startAsPartner: role == AuthRole.partner,
          createAccount: true,
        ),
      ),
    );
  }

  /// Firebase sign-in first, then hand the signed-in person to the app.
  static Future<void> signIn(BuildContext context, AuthRole role) async {
    final info = authRoles[role]!;
    final nav = Navigator.of(context);
    final ok = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          roleLabel: info.label,
          color: info.color,
          icon: info.icon,
          canRegister: canSignUp(role),
          partner: role == AuthRole.partner,
          admin: role == AuthRole.admin,
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await completeSignIn(context, role);
  }

  /// After Firebase sign-in succeeded: pick the account for [role] and enter
  /// the app.
  static Future<void> completeSignIn(
    BuildContext context,
    AuthRole role,
  ) async {
    final info = authRoles[role]!;
    final nav = Navigator.of(context);
    final session = context.read<SessionProvider>();
    final regs = context.read<RegistrationProvider>();
    final messenger = ScaffoldMessenger.of(context);

    void enterHome() =>
        nav.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);

    switch (role) {
      case AuthRole.admin:
        await session.useAdmin();
        enterHome();
      case AuthRole.partner:
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final mine = regs.ownedApprovedPartners(uid);
        if (mine.isEmpty) {
          await FirebaseAuth.instance.signOut();
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No approved organisation on this account yet. '
                'The admin is still reviewing it.',
              ),
            ),
          );
          return;
        }
        final id = mine.length == 1
            ? mine.first.id
            : await _choose(
                nav.context,
                title: 'Choose your organisation',
                color: info.color,
                accounts: [
                  for (final p in mine)
                    _Account(
                      p.id,
                      p.displayName,
                      '${p.kind.label} · ${p.city}',
                    ),
                ],
              );
        if (id == null || !nav.mounted) return;
        if (regs.byId(id)?.suspended ?? false) {
          await showSuspendedAlert(nav.context, id);
          await FirebaseAuth.instance.signOut();
          return;
        }
        await session.usePartner(id);
        enterHome();
      case AuthRole.user:
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final mine = regs.individualOf(uid);
        if (mine != null && mine.suspended) {
          await showSuspendedAlert(nav.context, mine.id);
          await FirebaseAuth.instance.signOut();
          return;
        }
        final known = session.users.any((u) => u.id == uid);
        if (known) {
          await session.useNeedy(userId: uid);
        } else {
          await session.addUser(id: uid);
        }
        if (!nav.mounted) return;
        if (!known || regs.individualOf(uid) == null) {
          nav.pushNamedAndRemoveUntil(AppRoutes.register, (_) => false);
        } else {
          enterHome();
        }
    }
  }

  /// Bottom sheet listing accounts; returns the chosen id.
  static Future<String?> _choose(
    BuildContext context, {
    required String title,
    required Color color,
    required List<_Account> accounts,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in accounts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.pop(ctx, a.id),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Text(
                            a.title.isEmpty ? '?' : a.title[0].toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(a.subtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
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

class _Account {
  const _Account(this.id, this.title, this.subtitle);
  final String id;
  final String title;
  final String subtitle;
}
