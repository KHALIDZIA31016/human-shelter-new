import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../registration/register_screen.dart';

/// Email + password sign in / sign up backed by Firebase Auth.
///
/// Pops with `true` once the user is signed in.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.roleLabel,
    required this.color,
    required this.icon,
    this.canRegister = true,
    this.partner = false,
    this.admin = false,
    this.onSignedIn,
    this.onModeChange,
  });

  final String roleLabel;
  final Color color;
  final IconData icon;

  /// Admin accounts cannot be self-created.
  final bool canRegister;
  final bool partner;

  /// Admin signs in with the fixed credentials below, not Firebase.
  final bool admin;

  static const adminEmail = 'admin@gmail.com';
  static const adminPassword = 'admin1122';

  /// Called after sign-in instead of popping (used when this form is the
  /// login screen itself).
  final VoidCallback? onSignedIn;

  /// Taps on the top right mode button. Defaults to going back to the Switch
  /// mode screen this form was opened from.
  final VoidCallback? onModeChange;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (widget.admin) {
      final ok =
          _email.text.trim().toLowerCase() == AuthScreen.adminEmail &&
          _password.text == AuthScreen.adminPassword;
      setState(() {
        _busy = false;
        _error = ok ? null : 'Incorrect email or password.';
      });
      if (ok) _done();
      return;
    }
    final auth = FirebaseAuth.instance;
    try {
      final email = _email.text.trim();
      await auth.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      _done();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done() {
    if (!mounted) return;
    if (widget.onSignedIn != null) {
      widget.onSignedIn!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _createAccount() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            RegisterScreen(startAsPartner: widget.partner, createAccount: true),
      ),
    );
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset link sent to $email')));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  String _message(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => 'That email address looks wrong.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Incorrect email or password.',
    'email-already-in-use' => 'An account with this email already exists.',
    'weak-password' => 'Use a password of at least 6 characters.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No internet connection.',
    _ => e.message ?? 'Could not sign in.',
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // The login screen is the root: no back button there.
        automaticallyImplyLeading: widget.onSignedIn == null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              onPressed:
                  widget.onModeChange ?? () => Navigator.of(context).maybePop(),
              backgroundColor: c.withValues(alpha: 0.14),
              side: BorderSide(color: c.withValues(alpha: 0.4)),
              avatar: Icon(Icons.swap_horiz_rounded, size: 18, color: c),
              label: Text(
                'Switch mode',
                style: TextStyle(color: c, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.withValues(alpha: 0.18), Colors.white],
            stops: const [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: c, size: 28),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome back',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.roleLabel} · sign in with your email',
                        style: const TextStyle(color: AppColors.neutral),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) => (v == null || !v.trim().contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidden,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _busy ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'At least 6 characters'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _reset,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.rejected,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: c),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('Sign in'),
                        ),
                      ),
                      if (widget.canRegister)
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : _createAccount,
                            child: Text(
                              'New here? Create an account',
                              style: TextStyle(
                                color: c,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
