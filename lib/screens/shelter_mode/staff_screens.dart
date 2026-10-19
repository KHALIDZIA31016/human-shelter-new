import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../core/utils/validators.dart';
import '../../data/models/staff_member.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_picker_field.dart';
import 'shelter_common.dart';

Color staffColor(StaffState s) => switch (s) {
  StaffState.current => AppColors.approved,
  StaffState.upcoming => AppColors.accent,
  StaffState.former => AppColors.neutral,
};

/// Staff grouped as working / joining soon / left. Used inside the shelter
/// profile and on the full Staff screen.
class StaffSection extends StatelessWidget {
  const StaffSection({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>();
    final all = staff.of(shelterId);
    final payroll = staff.monthlyPayroll(shelterId);

    Widget group(String title, StaffState s) {
      final list = all.where((m) => m.state == s).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 6.h),
            child: Text(
              '$title · ${list.length}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: staffColor(s),
              ),
            ),
          ),
          for (final m in list) ...[
            StaffCard(member: m),
            SizedBox(height: 8.h),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatGrid(
          children: [
            StatTile(
              value:
                  '${all.where((m) => m.state == StaffState.current).length}',
              label: 'Working now',
              color: AppColors.approved,
            ),
            StatTile(
              value:
                  '${all.where((m) => m.state == StaffState.upcoming).length}',
              label: 'Joining soon',
              color: AppColors.accent,
            ),
            StatTile(
              value: '${all.where((m) => m.state == StaffState.former).length}',
              label: 'Left',
              color: AppColors.neutral,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.payments_rounded, color: AppColors.primary),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Monthly salary bill (working staff)',
                  style: TextStyle(fontSize: 13.sp),
                ),
              ),
              Text(
                rs(payroll),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (all.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Text(
              'No staff added yet. Tap "Add staff" to create the first profile.',
              style: TextStyle(color: AppColors.neutral, fontSize: 13.sp),
            ),
          )
        else ...[
          group('Working now', StaffState.current),
          group('New hires · joining soon', StaffState.upcoming),
          group('Left the shelter', StaffState.former),
        ],
        SizedBox(height: 8.h),
        AppButton(
          label: 'Add staff',
          icon: Icons.person_add_alt_1_rounded,
          outlined: true,
          onPressed: () =>
              AppRouter.push(context, AppRoutes.staffForm, '$shelterId|'),
        ),
      ],
    );
  }
}

class StaffCard extends StatelessWidget {
  const StaffCard({super.key, required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final color = staffColor(m.state);
    final dates = switch (m.state) {
      StaffState.upcoming => 'Joins ${fmtFullDate(m.joinedAt)}',
      StaffState.current =>
        m.leftAt != null
            ? '${fmtFullDate(m.joinedAt)} → leaving ${fmtFullDate(m.leftAt!)}'
            : 'Since ${fmtFullDate(m.joinedAt)}',
      StaffState.former =>
        '${fmtFullDate(m.joinedAt)} → ${fmtFullDate(m.leftAt!)}',
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRouter.push(context, AppRoutes.staffDetail, m.id),
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Row(
            children: [
              PersonAvatar(name: m.name, imageUrl: m.imageUrl, color: color),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${m.role} · ${rs(m.salary)}/mo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                    Text(
                      dates,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Pill(m.state.label, color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings -> Staff.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: SafeArea(
        child: PageBody(child: StaffSection(shelterId: shelterId)),
      ),
    );
  }
}

class StaffDetailScreen extends StatelessWidget {
  const StaffDetailScreen({super.key, required this.staffId});

  final String staffId;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<StaffProvider>().byId(staffId);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Staff profile not found',
        ),
      );
    }
    final color = staffColor(m.state);
    final end = m.leftAt != null && !m.leftAt!.isAfter(DateTime.now())
        ? m.leftAt!
        : DateTime.now();
    final started = !m.joinedAt.isAfter(DateTime.now());
    final months = started ? (end.difference(m.joinedAt).inDays / 30.0) : 0.0;

    String or(String v) => v.trim().isEmpty ? '—' : v;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff profile'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => AppRouter.push(
              context,
              AppRoutes.staffForm,
              '${m.shelterId}|${m.id}',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: PersonAvatar(
                        name: m.name,
                        imageUrl: m.imageUrl,
                        radius: 34,
                        color: color,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            m.role,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              m.state.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Job'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      InfoRow(Icons.badge_outlined, 'Role', m.role),
                      InfoRow(
                        Icons.assignment_outlined,
                        'Duties',
                        or(m.duties),
                      ),
                      InfoRow(Icons.schedule_rounded, 'Shift', or(m.shift)),
                      InfoRow(
                        Icons.payments_outlined,
                        'Salary',
                        '${rs(m.salary)} / month',
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Time at the shelter'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      InfoRow(
                        Icons.login_rounded,
                        started ? 'Joined' : 'Joins on',
                        fmtFullDate(m.joinedAt),
                      ),
                      InfoRow(
                        Icons.logout_rounded,
                        m.state == StaffState.former ? 'Left on' : 'Leaving on',
                        m.leftAt == null ? '—' : fmtFullDate(m.leftAt!),
                      ),
                      if (started)
                        InfoRow(
                          Icons.timelapse_rounded,
                          m.state == StaffState.former
                              ? 'Worked for'
                              : 'Working for',
                          spanLabel(m.joinedAt, end),
                        ),
                      if (started)
                        InfoRow(
                          Icons.account_balance_wallet_outlined,
                          'Approx. paid',
                          rs(months * m.salary),
                        ),
                      if (m.leaveReason.isNotEmpty)
                        InfoRow(
                          Icons.info_outline_rounded,
                          'Reason',
                          m.leaveReason,
                        ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Contact'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      InfoRow(Icons.phone_outlined, 'Phone', or(m.phone)),
                      InfoRow(Icons.email_outlined, 'Email', or(m.email)),
                      InfoRow(Icons.place_outlined, 'Address', or(m.address)),
                      InfoRow(
                        Icons.contact_phone_outlined,
                        'Emergency',
                        or(m.emergencyContact),
                      ),
                    ],
                  ),
                ),
              ),
              if (m.notes.isNotEmpty) ...[
                const SectionTitle('Notes'),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Text(
                      m.notes,
                      style: TextStyle(fontSize: 14.sp, height: 1.45),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 18.h),
              if (m.state != StaffState.former)
                AppButton(
                  label: 'Mark as left',
                  icon: Icons.logout_rounded,
                  onPressed: () => _markLeft(context, m),
                )
              else
                AppButton(
                  label: 'Re-hire (clear leaving date)',
                  icon: Icons.restore_rounded,
                  onPressed: () => context.read<StaffProvider>().save(
                    m.copyWith(clearLeft: true),
                  ),
                ),
              SizedBox(height: 10.h),
              AppButton(
                label: 'Delete profile',
                icon: Icons.delete_outline_rounded,
                outlined: true,
                onPressed: () => _delete(context, m),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markLeft(BuildContext context, StaffMember m) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateUtils.dateOnly(m.joinedAt);
    final picked = await showDatePicker(
      context: context,
      initialDate: today.isBefore(first) ? first : today,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Last working day',
    );
    if (picked == null || !context.mounted) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason for leaving'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. Resigned, contract ended (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok != true || !context.mounted) return;
    await context.read<StaffProvider>().save(
      m.copyWith(leftAt: picked, leaveReason: text),
    );
  }

  Future<void> _delete(BuildContext context, StaffMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this profile?'),
        content: Text(
          '${m.name} and all their details will be removed. '
          'Use "Mark as left" instead to keep the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rejected),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final nav = Navigator.of(context);
    await context.read<StaffProvider>().remove(m.id);
    nav.pop();
  }
}

/// Add or edit a staff profile.
class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key, required this.shelterId, this.staffId});

  final String shelterId;
  final String? staffId;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _duties = TextEditingController();
  final _salary = TextEditingController();
  final _shift = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _emergency = TextEditingController();
  final _image = TextEditingController();
  final _notes = TextEditingController();
  final _reason = TextEditingController();
  late DateTime _joined = DateUtils.dateOnly(DateTime.now());
  DateTime? _left;
  String? _dateError;
  StaffMember? _existing;

  List<TextEditingController> get _all => [
    _name,
    _role,
    _duties,
    _salary,
    _shift,
    _phone,
    _email,
    _address,
    _emergency,
    _image,
    _notes,
    _reason,
  ];

  @override
  void initState() {
    super.initState();
    final m = context.read<StaffProvider>().byId(widget.staffId);
    _existing = m;
    if (m != null) {
      _name.text = m.name;
      _role.text = m.role;
      _duties.text = m.duties;
      _salary.text = m.salary.toString();
      _shift.text = m.shift;
      _phone.text = m.phone;
      _email.text = m.email;
      _address.text = m.address;
      _emergency.text = m.emergencyContact;
      _image.text = m.imageUrl ?? '';
      _notes.text = m.notes;
      _reason.text = m.leaveReason;
      _joined = DateUtils.dateOnly(m.joinedAt);
      _left = m.leftAt == null ? null : DateUtils.dateOnly(m.leftAt!);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickJoined() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _joined,
      firstDate: DateTime(now.year - 40),
      lastDate: DateTime(now.year + 2),
      helpText: 'Joining date',
    );
    if (d != null) {
      setState(() {
        _joined = d;
        _dateError = null;
      });
    }
  }

  Future<void> _pickLeft() async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          _left ?? (_joined.isAfter(DateTime.now()) ? _joined : DateTime.now()),
      firstDate: _joined,
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: 'Last working day',
    );
    if (d != null) {
      setState(() {
        _left = d;
        _dateError = null;
      });
    }
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    if (_left != null && _left!.isBefore(_joined)) {
      setState(() => _dateError = 'Leaving date cannot be before joining date');
      return;
    }
    if (!valid) return;
    final salary = int.parse(_salary.text.trim());
    final base = _existing;
    final member = StaffMember(
      id: base?.id ?? newId(),
      shelterId: widget.shelterId,
      name: _name.text.trim(),
      role: _role.text.trim(),
      duties: _duties.text.trim(),
      salary: salary,
      shift: _shift.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      emergencyContact: _emergency.text.trim(),
      imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
      notes: _notes.text.trim(),
      joinedAt: _joined,
      leftAt: _left,
      leaveReason: _left == null ? '' : _reason.text.trim(),
      createdAt: base?.createdAt,
    );
    await context.read<StaffProvider>().save(member);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = _existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit staff' : 'Add staff')),
      body: SafeArea(
        child: PageBody(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                  validator: Validators.name,
                ),
                AppTextField(
                  controller: _role,
                  label: 'Job title',
                  hint: 'e.g. Cook, Night warden, Nurse',
                  icon: Icons.badge_outlined,
                  validator: (v) => Validators.required(v, 'Job title'),
                ),
                AppTextField(
                  controller: _duties,
                  label: 'What does / did this person do?',
                  icon: Icons.assignment_outlined,
                  maxLines: 3,
                  maxLength: 400,
                  validator: (v) => Validators.required(v, 'Duties'),
                ),
                AppTextField(
                  controller: _salary,
                  label: 'Monthly salary (Rs)',
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  digitsOnly: true,
                  maxLength: 9,
                  validator: (v) => Validators.positiveInt(v, 'Salary'),
                ),
                AppTextField(
                  controller: _shift,
                  label: 'Shift / timings (optional)',
                  hint: 'e.g. 8 AM - 4 PM',
                  icon: Icons.schedule_rounded,
                ),
                _DateField(
                  label: 'Joining date',
                  value: _joined,
                  onTap: _pickJoined,
                ),
                SizedBox(height: 14.h),
                _DateField(
                  label: 'Leaving date (leave empty if still working)',
                  value: _left,
                  onTap: _pickLeft,
                  onClear: _left == null
                      ? null
                      : () => setState(() => _left = null),
                ),
                if (_dateError != null)
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Text(
                      _dateError!,
                      style: TextStyle(
                        color: AppColors.rejected,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                SizedBox(height: 14.h),
                if (_left != null)
                  AppTextField(
                    controller: _reason,
                    label: 'Reason for leaving (optional)',
                    icon: Icons.info_outline_rounded,
                    maxLines: 2,
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
                  controller: _address,
                  label: 'Home address (optional)',
                  icon: Icons.place_outlined,
                ),
                AppTextField(
                  controller: _emergency,
                  label: 'Emergency contact (optional)',
                  icon: Icons.contact_phone_outlined,
                ),
                ImagePickerField(
                  controller: _image,
                  label: 'Staff photo (optional)',
                  round: true,
                ),
                AppTextField(
                  controller: _notes,
                  label: 'Notes (optional)',
                  icon: Icons.sticky_note_2_outlined,
                  maxLines: 3,
                ),
                AppButton(
                  label: editing ? 'Save changes' : 'Add staff',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_rounded),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
        ),
        child: Text(value == null ? 'Not set' : fmtFullDate(value!)),
      ),
    );
  }
}
