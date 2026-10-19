import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../providers/session_provider.dart';
import '../auth/auth_flow.dart';

/// Switch mode: every mode (user, partner, admin) has its own Sign in and
/// Sign up, so anyone can move to another account from here.
class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key});

  static const _ink = Color(0xFF0F172A);

  static AuthRole? _current(Persona p) => switch (p) {
    Persona.needy => AuthRole.user,
    Persona.partner => AuthRole.partner,
    Persona.admin => AuthRole.admin,
  };

  @override
  Widget build(BuildContext context) {
    final current = _current(context.watch<SessionProvider>().persona);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 78,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Shelter Home',
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Choose a mode to continue',
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.2,
                color: AppColors.neutral,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  for (final role in AuthRole.values) ...[
                    _ModeCard(role: role, current: role == current),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extra detail shown on each mode card.
class _ModeDetail {
  const _ModeDetail(this.about, this.points);
  final String about;
  final List<String> points;
}

const _details = <AuthRole, _ModeDetail>{
  AuthRole.user: _ModeDetail(
    'For people who need support. Register once, then ask for what you need '
    'and track every request in one place.',
    [
      'Request a bed at a nearby shelter',
      'Ask for meals and daily essentials',
      'Chat with shelters and follow your alerts',
    ],
  ),
  AuthRole.partner: _ModeDetail(
    'For shelters, restaurants and companies. Your organisation is reviewed '
    'by the admin before it goes live.',
    [
      'Manage beds, residents and staff',
      'Offer meals and donations',
      'Approve requests and keep reports',
    ],
  ),
  AuthRole.admin: _ModeDetail(
    'For the team that keeps the community safe. Admin accounts are created '
    'by the organisation, so there is no sign up.',
    [
      'Review and approve registrations',
      'Handle complaints and transfers',
      'Monitor activity across all shelters',
    ],
  ),
};

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.role, required this.current});

  final AuthRole role;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final info = authRoles[role]!;
    final c = info.color;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => AuthFlow.signIn(context, role),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: current ? c : const Color(0xFFE2E8F0),
              width: current ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(info.icon, color: c, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                info.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ModeScreen._ink,
                                ),
                              ),
                            ),
                            if (current) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Current',
                                  style: GoogleFonts.poppins(
                                    color: c,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          info.tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: AppColors.neutral,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _details[role]!.about,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.5,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              for (final point in _details[role]!.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: c,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            height: 1.35,
                            color: ModeScreen._ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => AuthFlow.signIn(context, role),
                      child: const Text('Sign in'),
                    ),
                  ),
                  if (AuthFlow.canSignUp(role)) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c,
                          side: BorderSide(color: c.withValues(alpha: 0.5)),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => AuthFlow.signUp(context, role),
                        child: const Text('Sign up'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
