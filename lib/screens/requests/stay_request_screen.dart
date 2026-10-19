import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/service_request.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../shelter_mode/shelter_common.dart';
import '../shelters/commitment.dart';
import '../../widgets/form_widgets.dart';

/// Apply for a bed. Requires an approved individual registration; the
/// request goes to the shelter (not admin).
class StayRequestScreen extends StatefulWidget {
  const StayRequestScreen({super.key, this.shelterId});

  /// Pre-selected shelter; null lets the user pick from the cards.
  final String? shelterId;

  @override
  State<StayRequestScreen> createState() => _StayRequestScreenState();
}

class _StayRequestScreenState extends State<StayRequestScreen> {
  final _note = TextEditingController();
  int? _people;
  late String? _shelterId = widget.shelterId;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionProvider>();
    final regs = context.read<RegistrationProvider>();
    final picked = regs.byId(_shelterId);
    if (picked == null) return;
    if (_note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please write a message to the shelter first.'),
            backgroundColor: AppColors.rejected,
          ),
        );
      return;
    }
    if (!await ensureCanApply(context, picked)) return;
    if (!mounted) return;
    final me = regs.individualOf(session.deviceId)!;
    final shelter = picked;
    setState(() => _busy = true);
    final err = await context.read<RequestProvider>().create(
      ServiceRequest(
        id: newId(),
        type: RequestType.stay,
        requesterId: session.deviceId,
        requesterName: me.name,
        phone: me.phone,
        targetId: shelter.id,
        targetName: shelter.displayName,
        people: (_people ?? me.familyMembers).clamp(
          1,
          shelter.availableBeds.clamp(1, 20),
        ),
        message: _note.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showSuccessDialog(
      context,
      title: 'Application sent',
      message:
          '${shelter.displayName} will review your application. If a bed '
          'is available you will be told when to arrive and whom to meet.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final regs = context.watch<RegistrationProvider>();
    final session = context.watch<SessionProvider>();
    final me = regs.individualOf(session.deviceId);
    final shelters = regs.approvedShelters;
    final shelter = regs.byId(_shelterId);

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for a stay')),
      body: SafeArea(child: _body(context, shelters, shelter, me)),
    );
  }

  Widget _body(
    BuildContext context,
    List<Registration> shelters,
    Registration? shelter,
    Registration? me,
  ) {
    if (me == null || me.status == ReviewStatus.rejected) {
      return PageBody(
        child: Column(
          children: [
            Callout(
              icon: Icons.how_to_reg_rounded,
              color: AppColors.accent,
              title: me == null ? 'Register first' : 'Registration rejected',
              text: me == null
                  ? 'To apply for a bed you need an approved registration. '
                        'It only takes a minute.'
                  : 'Reason: ${me.rejectReason}. You can register again with correct details.',
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: 'Register now',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => AppRouter.push(context, AppRoutes.register),
            ),
          ],
        ),
      );
    }
    if (me.status == ReviewStatus.pending) {
      return const PageBody(
        child: Callout(
          icon: Icons.hourglass_top_rounded,
          color: AppColors.pending,
          title: 'Registration under review',
          text:
              'Admin will respond within 24–48 hours. You can apply for a '
              'stay as soon as you are approved.',
        ),
      );
    }
    final beds = shelter?.availableBeds ?? 0;
    final people = (_people ?? me.familyMembers).clamp(
      1,
      beds < 1 ? 1 : beds.clamp(1, 20),
    );
    return Column(
      children: [
        Expanded(
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FormHeader(
                  icon: Icons.bed_rounded,
                  title: 'Apply for a safe bed',
                  text:
                      'Your application goes directly to the shelter, which decides.',
                ),
                FormSection(
                  step: 1,
                  title: 'Choose a shelter',
                  subtitle: 'Shelters with no free beds cannot be selected.',
                  child: ShelterPicker(
                    shelters: shelters,
                    selectedId: _shelterId,
                    requireBeds: true,
                    onChanged: (id) => setState(() => _shelterId = id),
                  ),
                ),
                FormSection(
                  step: 2,
                  title: 'Your details',
                  subtitle: 'From your registration.',
                  child: _ApplicantCard(me),
                ),
                FormSection(
                  step: 3,
                  title: 'Who needs a bed?',
                  child: CountStepper(
                    label: 'People needing a bed',
                    value: people,
                    max: beds < 1 ? 1 : beds.clamp(1, 20),
                    onChanged: (v) => setState(() => _people = v),
                  ),
                ),
                FormSection(
                  step: 4,
                  title: 'Message to the shelter',
                  child: AppTextField(
                    controller: _note,
                    label: 'Message',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                    maxLength: 300,
                  ),
                ),
              ],
            ),
          ),
        ),
        SubmitBar(
          summary: shelter == null
              ? 'Select a shelter to continue'
              : beds > 0
              ? '$people ${people == 1 ? 'person' : 'people'} · ${shelter.displayName}'
              : '${shelter.displayName} is full',
          label: shelter == null
              ? 'Choose a shelter'
              : beds > 0
              ? 'Send application'
              : 'Shelter is full',
          loading: _busy,
          onPressed: shelter != null && beds > 0 ? _submit : null,
        ),
      ],
    );
  }
}

/// Clean read-only summary of the applicant taken from their registration.
class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard(this.me);

  final Registration me;

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 8.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16.sp, color: AppColors.primary),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5.sp,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    const divider = Divider(height: 1, color: Color(0xFFE2E8F0));
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PersonAvatar(
                      name: me.name,
                      imageUrl: me.imageUrl,
                      radius: 26,
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 18.sp,
                          color: const Color(0xFF1D9BF0),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Verified applicant',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: AppColors.approved,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Column(
              children: [
                _row(Icons.phone_outlined, 'Phone', me.phone),
                if (me.email.isNotEmpty) ...[
                  divider,
                  _row(Icons.email_outlined, 'Email', me.email),
                ],
                divider,
                _row(
                  Icons.place_outlined,
                  'Location',
                  '${me.city} · ${me.address}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
