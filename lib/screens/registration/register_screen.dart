import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/remote/registration_remote.dart';
import '../../providers/registration_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/image_picker_field.dart';

/// Single registration screen for both "for myself" and partner programs.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.startAsPartner = false,
    this.createAccount = false,
  });

  final bool startAsPartner;

  /// Also creates the Firebase Auth account (email from the form + password).
  final bool createAccount;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _org = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _beds = TextEditingController();
  final _image = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidden = true;

  bool get _partner => widget.startAsPartner;
  RegistrationKind _kind = RegistrationKind.shelter;
  final Set<String> _needs = {'Shelter / bed'};
  final Set<HelpCategory> _services = {};
  final int _family = 1;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _org,
      _phone,
      _email,
      _age,
      _city,
      _address,
      _notes,
      _beds,
      _image,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  RegistrationKind get _effectiveKind =>
      _partner ? _kind : RegistrationKind.individual;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_partner && _image.text.trim().isEmpty) {
      _snack('Please pick your photo to continue.');
      return;
    }
    if (_partner && _services.isEmpty) {
      _snack('Please pick at least one service you provide.');
      return;
    }
    setState(() => _busy = true);
    final session = context.read<SessionProvider>();
    final regs = context.read<RegistrationProvider>();
    var ownerId = session.deviceId;
    if (widget.createAccount) {
      try {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        ownerId = cred.user!.uid;
        if (!_partner) await session.addUser(id: ownerId);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(_authMessage(e));
        return;
      }
    }
    final beds = _kind == RegistrationKind.shelter && _partner
        ? int.parse(_beds.text.trim())
        : 0;
    final reg = Registration(
      id: RegistrationRemote.newId(_effectiveKind),
      ownerId: ownerId,
      kind: _effectiveKind,
      name: _name.text.trim(),
      orgName: _partner ? _org.text.trim() : null,
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      age: int.tryParse(_age.text.trim()),
      city: _city.text.trim(),
      address: _address.text.trim(),
      needs: _partner ? const [] : _needs.toList(),
      services: _partner ? [for (final c in _services) c.name] : const [],
      notes: _notes.text.trim(),
      imageUrl: _partner || _image.text.trim().isEmpty
          ? null
          : _image.text.trim(),
      familyMembers: _family,
      totalBeds: beds,
      availableBeds: beds,
    );
    final err = await regs.submit(reg);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _snack(err);
      return;
    }
    if (!mounted) return;
    if (widget.createAccount) {
      // Never drop a new account straight into the app: sign out and send
      // them back to the login screen to sign in.
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((r) => r.isFirst);
      // Shown after leaving, since leaving a screen clears pending toasts.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _partner
                ? 'Account created. Admin will review your registration; sign in once approved.'
                : 'Account created. Please sign in.',
          ),
        ),
      );
    } else if (_partner) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
  }

  /// Back from the form when it is the first screen after sign-in: sign out
  /// and return to the login screen.
  Future<void> _backToLogin() async {
    final nav = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  String _authMessage(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => 'That email address looks wrong.',
    'email-already-in-use' => 'An account with this email already exists.',
    'weak-password' => 'Use a password of at least 6 characters.',
    'network-request-failed' => 'No internet connection.',
    _ => e.message ?? 'Could not create the account.',
  };

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    var step = 0;
    final isRoot = !Navigator.of(context).canPop();
    return PopScope(
      canPop: !isRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isRoot) _backToLogin();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: isRoot
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _backToLogin,
                )
              : null,
          title: Text(
            widget.createAccount
                ? 'Create account'
                : _partner
                ? 'Partner registration'
                : 'Register yourself',
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageBody(
                  child: Theme(
                    data: _proFieldTheme(Theme.of(context)),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_partner)
                            const FormHeader(
                              icon: Icons.handshake_rounded,
                              title: 'Join as a partner',
                              text:
                                  'Shelters, restaurants and companies can join to help. Admin reviews every partner within 24–48 hours.',
                            ),
                          if (!_partner) ...[
                            const _TwoSteps(),
                            FormSection(
                              step: ++step,
                              title: 'Your photo',
                              subtitle: 'Pick a clear photo of yourself.',
                              child: ImagePickerField(
                                controller: _image,
                                label: 'Profile photo',
                                round: true,
                              ),
                            ),
                          ],
                          if (_partner)
                            FormSection(
                              step: ++step,
                              title: 'Who are you?',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      OptionTile<RegistrationKind>(
                                        value: RegistrationKind.shelter,
                                        groupValue: _kind,
                                        label: 'Shelter',
                                        icon: Icons.home_work_rounded,
                                        onSelected: (k) =>
                                            setState(() => _kind = k),
                                      ),
                                      SizedBox(width: 10.w),
                                      OptionTile<RegistrationKind>(
                                        value: RegistrationKind.restaurant,
                                        groupValue: _kind,
                                        label: 'Restaurant',
                                        icon: Icons.restaurant_rounded,
                                        onSelected: (k) =>
                                            setState(() => _kind = k),
                                      ),
                                      SizedBox(width: 10.w),
                                      OptionTile<RegistrationKind>(
                                        value: RegistrationKind.company,
                                        groupValue: _kind,
                                        label: 'Company',
                                        icon: Icons.business_rounded,
                                        onSelected: (k) =>
                                            setState(() => _kind = k),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  AppTextField(
                                    controller: _org,
                                    label: '${_kind.label} name',
                                    icon: Icons.business_rounded,
                                    validator: (v) => Validators.name(
                                      v,
                                      '${_kind.label} name',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          FormSection(
                            step: ++step,
                            title: _partner
                                ? 'Contact details'
                                : 'Your details',
                            child: Column(
                              children: [
                                AppTextField(
                                  controller: _name,
                                  label: _partner
                                      ? 'Contact person'
                                      : 'Full name',
                                  icon: Icons.person_outline_rounded,
                                  validator: Validators.name,
                                ),
                                AppTextField(
                                  controller: _phone,
                                  label: 'Phone number',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  validator: Validators.phone,
                                  maxLength: 16,
                                ),
                                if (!_partner)
                                  AppTextField(
                                    controller: _age,
                                    label: 'Age',
                                    icon: Icons.cake_outlined,
                                    keyboardType: TextInputType.number,
                                    digitsOnly: true,
                                    maxLength: 3,
                                    validator: (v) {
                                      final t = (v ?? '').trim();
                                      if (t.isEmpty) return 'Age is required';
                                      final n = int.tryParse(t);
                                      return (n == null || n < 1 || n > 120)
                                          ? 'Enter a valid age'
                                          : null;
                                    },
                                  ),
                                AppTextField(
                                  controller: _email,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'Email is required'
                                      : Validators.optionalEmail(v),
                                ),
                              ],
                            ),
                          ),
                          FormSection(
                            step: ++step,
                            title: 'Location',
                            child: Column(
                              children: [
                                AppTextField(
                                  controller: _city,
                                  label: 'City',
                                  icon: Icons.location_city_rounded,
                                  validator: (v) =>
                                      Validators.required(v, 'City'),
                                ),
                                AppTextField(
                                  controller: _address,
                                  label: _partner
                                      ? 'Full address'
                                      : 'Where are you right now?',
                                  hint: _partner
                                      ? null
                                      : 'Area, street or nearby landmark',
                                  icon: Icons.place_outlined,
                                  maxLines: 2,
                                  validator: (v) =>
                                      Validators.required(v, 'Address'),
                                ),
                                if (_partner &&
                                    _kind == RegistrationKind.shelter)
                                  AppTextField(
                                    controller: _beds,
                                    label: 'Total beds available',
                                    icon: Icons.bed_outlined,
                                    keyboardType: TextInputType.number,
                                    digitsOnly: true,
                                    maxLength: 5,
                                    validator: (v) =>
                                        Validators.positiveInt(v, 'Beds'),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.createAccount)
                            FormSection(
                              step: ++step,
                              title: 'Account password',
                              subtitle:
                                  'You will sign in with your email above.',
                              child: Column(
                                children: [
                                  AppTextField(
                                    controller: _password,
                                    label: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _hidden,
                                    validator: (v) =>
                                        (v == null || v.length < 6)
                                        ? 'At least 6 characters'
                                        : null,
                                  ),
                                  AppTextField(
                                    controller: _confirm,
                                    label: 'Confirm password',
                                    icon: Icons.lock_reset_rounded,
                                    obscureText: _hidden,
                                    validator: (v) => v != _password.text
                                        ? 'Passwords do not match'
                                        : null,
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          setState(() => _hidden = !_hidden),
                                      icon: Icon(
                                        _hidden
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      label: Text(
                                        _hidden
                                            ? 'Show password'
                                            : 'Hide password',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_partner)
                            FormSection(
                              step: ++step,
                              title: 'Your situation',
                              child: AppTextField(
                                controller: _notes,
                                label: 'Tell us your situation (optional)',
                                icon: Icons.notes_rounded,
                                maxLines: 3,
                                maxLength: 300,
                              ),
                            ),
                          if (_partner)
                            FormSection(
                              step: ++step,
                              title: 'We provide services with',
                              subtitle: 'Select everything you can offer.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: [
                                      for (final c in HelpCategory.values)
                                        FilterChip(
                                          label: Text(c.label),
                                          selected: _services.contains(c),
                                          showCheckmark: false,
                                          avatar: _services.contains(c)
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
                                                )
                                              : null,
                                          onSelected: (v) => setState(
                                            () => v
                                                ? _services.add(c)
                                                : _services.remove(c),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  AppTextField(
                                    controller: _notes,
                                    label:
                                        'More about your services (optional)',
                                    icon: Icons.notes_rounded,
                                    maxLines: 3,
                                    maxLength: 300,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SubmitBar(
                summary: 'Admin responds within 24–48 hours',
                label: widget.createAccount
                    ? 'Create account'
                    : 'Submit registration',
                loading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft, borderless fields with tinted icons and crisp inner text.
ThemeData _proFieldTheme(ThemeData base) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );
  const fill = Color(0xFFF1F5F9);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F172A),
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F172A),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fill,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIconColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.focused)
            ? AppColors.primary
            : const Color(0xFF94A3B8),
      ),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.primary, 1.8),
      errorBorder: border(AppColors.rejected.withValues(alpha: 0.6)),
      focusedErrorBorder: border(AppColors.rejected, 1.8),
    ),
  );
}

class _TwoSteps extends StatelessWidget {
  const _TwoSteps();

  @override
  Widget build(BuildContext context) {
    Widget row(int n, String title, String sub) => Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12.r, child: Text('$n')),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(sub),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          row(
            1,
            'Register as a user',
            'Fill in this form and pick your photo.',
          ),
          row(
            2,
            'Register for a shelter',
            'After registering, apply to a shelter from your Profile.',
          ),
        ],
      ),
    );
  }
}
