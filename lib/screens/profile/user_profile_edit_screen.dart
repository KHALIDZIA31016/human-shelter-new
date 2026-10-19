import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/models/profile_change.dart';
import '../../data/models/registration.dart';
import '../../providers/profile_change_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_picker_field.dart';

/// The person edits their own profile. While approved at a shelter only the
/// photo can change; every other detail has to be changed through the shelter.
class UserProfileEditScreen extends StatefulWidget {
  const UserProfileEditScreen({super.key});

  @override
  State<UserProfileEditScreen> createState() => _UserProfileEditScreenState();
}

class _UserProfileEditScreenState extends State<UserProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _age,
      _phone,
      _email,
      _city,
      _address,
      _image;
  late final String _id;

  @override
  void initState() {
    super.initState();
    final me = context.read<RegistrationProvider>().individualOf(
      context.read<SessionProvider>().deviceId,
    )!;
    _id = me.id;
    _name = TextEditingController(text: me.name);
    _age = TextEditingController(text: me.age?.toString() ?? '');
    _phone = TextEditingController(text: me.phone);
    _email = TextEditingController(text: me.email);
    _city = TextEditingController(text: me.city);
    _address = TextEditingController(text: me.address);
    _image = TextEditingController(text: me.imageUrl ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _phone, _email, _city, _address, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(bool locked) async {
    if (!locked && !_form.currentState!.validate()) return;
    final regs = context.read<RegistrationProvider>();
    if (locked) {
      await regs.updateProfile(_id, imageUrl: _image.text.trim());
    } else {
      await regs.updateProfile(
        _id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        city: _city.text.trim(),
        address: _address.text.trim(),
        age: int.tryParse(_age.text.trim()),
        imageUrl: _image.text.trim(),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = context.watch<SessionProvider>().deviceId;
    final reqs = context.watch<RequestProvider>();
    // Approved at a shelter (checked in or on the way) = details are locked.
    final stay = reqs.activeStay(deviceId) ?? reqs.awaitingStay(deviceId);
    final locked = stay != null;
    final me = context.watch<RegistrationProvider>().byId(_id)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageBody(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ImagePickerField(
                          controller: _image,
                          label: 'Profile photo',
                          round: true,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      if (locked) ...[
                        _LockedCard(shelterName: stay.targetName),
                        SizedBox(height: 14.h),
                        _LockedRows(me: me),
                      ] else ...[
                        AppTextField(
                          controller: _name,
                          label: 'Full name',
                          icon: Icons.person_outline_rounded,
                          validator: Validators.name,
                        ),
                        AppTextField(
                          controller: _age,
                          label: 'Age (optional)',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          digitsOnly: true,
                          maxLength: 3,
                        ),
                        AppTextField(
                          controller: _phone,
                          label: 'Phone',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 16,
                          validator: Validators.phone,
                        ),
                        AppTextField(
                          controller: _email,
                          label: 'Email (optional)',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.optionalEmail,
                        ),
                        AppTextField(
                          controller: _city,
                          label: 'City',
                          icon: Icons.location_city_rounded,
                          validator: (v) => Validators.required(v, 'City'),
                        ),
                        AppTextField(
                          controller: _address,
                          label: 'Location / address',
                          icon: Icons.place_outlined,
                          maxLines: 2,
                          validator: (v) => Validators.required(v, 'Address'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: AppButton(
                label: locked ? 'Save photo' : 'Save changes',
                icon: Icons.check_rounded,
                onPressed: () => _save(locked),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _valueOf(Registration me, String key) => switch (key) {
  'name' => me.name,
  'age' => me.age?.toString() ?? '',
  'phone' => me.phone,
  'email' => me.email,
  'city' => me.city,
  _ => me.address,
};

/// Info card shown while details are locked, with the "Ask changes" button.
class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.shelterName});

  final String shelterName;

  @override
  Widget build(BuildContext context) {
    final id = context.watch<SessionProvider>().deviceId;
    final changes = context.watch<ProfileChangeProvider>();
    final pending = changes.pendingOf(id);
    final latest = changes.latestOf(id);
    final (sColor, sIcon) = switch (latest?.status) {
      ReviewStatus.approved => (AppColors.approved, Icons.check_circle_rounded),
      ReviewStatus.rejected => (AppColors.rejected, Icons.cancel_rounded),
      _ => (AppColors.pending, Icons.hourglass_top_rounded),
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.pending.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pending.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppColors.pending,
                size: 22.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details are locked',
                      style: TextStyle(
                        color: AppColors.pending,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                      ),
                    ),
                    Text(
                      'You are registered at $shelterName. You can change '
                      'your photo here. To change anything else, ask the '
                      'shelter.',
                      style: TextStyle(fontSize: 13.5.sp, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (latest != null) ...[
                SizedBox(width: 8.w),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => _PreviewDialog(change: latest),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: sColor.withValues(alpha: 0.5)),
                    ),
                    child: Icon(sIcon, color: sColor, size: 20.sp),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pending,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              ),
              onPressed: pending != null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => const _AskChangesDialog(),
                    ),
              icon: Icon(
                pending != null
                    ? Icons.hourglass_top_rounded
                    : Icons.edit_note_rounded,
                size: 18.sp,
              ),
              label: Text(pending != null ? 'Request sent' : 'Ask changes'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The current (locked) profile details, read straight from the profile.
class _LockedRows extends StatelessWidget {
  const _LockedRows({required this.me});

  final Registration me;

  @override
  Widget build(BuildContext context) {
    const icons = {
      'name': Icons.person_outline_rounded,
      'age': Icons.cake_outlined,
      'phone': Icons.phone_outlined,
      'email': Icons.email_outlined,
      'city': Icons.location_city_rounded,
      'address': Icons.place_outlined,
    };
    final keys = kProfileFields.keys.toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(9.r),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icons[keys[i]],
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kProfileFields[keys[i]]!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _valueOf(me, keys[i]).trim().isEmpty
                              ? '—'
                              : _valueOf(me, keys[i]),
                          style: TextStyle(
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15.sp,
                    color: AppColors.neutral,
                  ),
                ],
              ),
            ),
            if (i < keys.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

/// Popup form: every profile detail, prefilled. Sends what changed to the
/// shelter for approval.
class _AskChangesDialog extends StatefulWidget {
  const _AskChangesDialog();

  @override
  State<_AskChangesDialog> createState() => _AskChangesDialogState();
}

class _AskChangesDialogState extends State<_AskChangesDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late final Registration _me;
  late final String _shelterId, _shelterName;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final id = context.read<SessionProvider>().deviceId;
    _me = context.read<RegistrationProvider>().individualOf(id)!;
    final reqs = context.read<RequestProvider>();
    final stay = reqs.activeStay(id) ?? reqs.awaitingStay(id)!;
    _shelterId = stay.targetId;
    _shelterName = stay.targetName;
    _c = {
      for (final k in kProfileFields.keys)
        k: TextEditingController(text: _valueOf(_me, k)),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await context.read<ProfileChangeProvider>().submit(
      ProfileChange(
        id: newId(),
        registrationId: _me.id,
        userId: _me.ownerId,
        userName: _me.name,
        shelterId: _shelterId,
        shelterName: _shelterName,
        before: {for (final k in kProfileFields.keys) k: _valueOf(_me, k)},
        after: {for (final e in _c.entries) e.key: e.value.text.trim()},
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(err ?? 'Request sent to $_shelterName for approval.'),
        backgroundColor: err == null ? AppColors.approved : AppColors.rejected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 8.w, 6.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask for changes',
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Edit what you need. $_shelterName will approve or '
                          'reject. Nothing changes until it approves.',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 0),
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _c['name']!,
                        label: 'Full name',
                        icon: Icons.person_outline_rounded,
                        validator: Validators.name,
                      ),
                      AppTextField(
                        controller: _c['age']!,
                        label: 'Age (optional)',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        digitsOnly: true,
                        maxLength: 3,
                      ),
                      AppTextField(
                        controller: _c['phone']!,
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        maxLength: 16,
                        validator: Validators.phone,
                      ),
                      AppTextField(
                        controller: _c['email']!,
                        label: 'Email (optional)',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.optionalEmail,
                      ),
                      AppTextField(
                        controller: _c['city']!,
                        label: 'City',
                        icon: Icons.location_city_rounded,
                        validator: (v) => Validators.required(v, 'City'),
                      ),
                      AppTextField(
                        controller: _c['address']!,
                        label: 'Location / address',
                        icon: Icons.place_outlined,
                        maxLines: 2,
                        validator: (v) => Validators.required(v, 'Address'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 18.h),
              child: AppButton(
                label: 'Send to shelter',
                icon: Icons.send_rounded,
                loading: _busy,
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only preview of a change request the person sent.
class _PreviewDialog extends StatelessWidget {
  const _PreviewDialog({required this.change});

  final ProfileChange change;

  @override
  Widget build(BuildContext context) {
    final c = change;
    final (color, icon, title) = switch (c.status) {
      ReviewStatus.pending => (
        AppColors.pending,
        Icons.hourglass_top_rounded,
        'Waiting for ${c.shelterName}',
      ),
      ReviewStatus.approved => (
        AppColors.approved,
        Icons.check_circle_rounded,
        'Approved · profile updated',
      ),
      _ => (
        AppColors.rejected,
        Icons.cancel_rounded,
        'Rejected · profile not changed',
      ),
    };
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 26.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'Sent ${fmtDateTime(c.createdAt)}',
                style: TextStyle(fontSize: 12.sp, color: AppColors.neutral),
              ),
              SizedBox(height: 12.h),
              Text(
                'WHAT YOU ASKED FOR',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutral,
                ),
              ),
              for (final k in kProfileFields.keys)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kProfileFields[k]!,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.neutral,
                        ),
                      ),
                      if (c.changed.containsKey(k))
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: (c.before[k] ?? '').isEmpty
                                    ? '—'
                                    : c.before[k],
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.neutral,
                                ),
                              ),
                              const TextSpan(text: '  →  '),
                              TextSpan(
                                text: (c.after[k] ?? '').isEmpty
                                    ? '—'
                                    : c.after[k],
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(fontSize: 14.sp),
                        )
                      else
                        Text(
                          (c.after[k] ?? '').isEmpty ? '—' : c.after[k]!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              if (c.status == ReviewStatus.rejected &&
                  (c.rejectReason ?? '').isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  'Reason: ${c.rejectReason}',
                  style: TextStyle(
                    color: AppColors.rejected,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (c.status == ReviewStatus.pending) ...[
                SizedBox(height: 8.h),
                Text(
                  'You can ask again once the shelter has answered.',
                  style: TextStyle(fontSize: 12.5.sp, color: AppColors.neutral),
                ),
              ],
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
