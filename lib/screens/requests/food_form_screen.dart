import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/service_request.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';

/// Food request (needy user, no registration needed) or food donation offer
/// (restaurant / company). Both are sent to a shelter.
class FoodFormScreen extends StatefulWidget {
  const FoodFormScreen({super.key, required this.args});

  final FoodFormArgs args;

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();

  String? _shelterId;
  MealType _meal = _defaultMeal();
  int _dayOffset = 0;
  int _people = 1;
  bool _busy = false;

  bool get _donation => widget.args.type == RequestType.donation;

  static MealType _defaultMeal() {
    final h = DateTime.now().hour;
    return h < 11
        ? MealType.breakfast
        : (h < 16 ? MealType.lunch : MealType.dinner);
  }

  @override
  void initState() {
    super.initState();
    _shelterId = widget.args.shelterId;
    if (_donation) _people = 10;
    // Prefill from what we already know about this device.
    final session = context.read<SessionProvider>();
    final regs = context.read<RegistrationProvider>();
    final known = _donation
        ? regs.byId(session.activePartnerId)
        : regs.individualOf(session.deviceId);
    if (known != null) {
      _name.text = _donation ? known.displayName : known.name;
      _phone.text = known.phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Registration> shelters) async {
    if (!_form.currentState!.validate()) return;
    final shelter = shelters.where((s) => s.id == _shelterId).firstOrNull;
    if (shelter == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please choose a shelter.')));
      return;
    }
    setState(() => _busy = true);
    final day = DateTime.now().add(Duration(days: _dayOffset));
    final req = ServiceRequest(
      id: newId(),
      type: widget.args.type,
      // Donations belong to the partner (so only that partner is notified);
      // meal requests belong to the person's device.
      requesterId: _donation
          ? (context.read<SessionProvider>().activePartnerId ??
                context.read<SessionProvider>().deviceId)
          : context.read<SessionProvider>().deviceId,
      requesterName: _name.text.trim(),
      phone: _phone.text.trim(),
      targetId: shelter.id,
      targetName: shelter.displayName,
      people: _people,
      meal: _meal,
      neededDate: DateTime(day.year, day.month, day.day),
      message: _note.text.trim(),
    );
    final err = await context.read<RequestProvider>().create(req);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await showSuccessDialog(
      context,
      title: _donation ? 'Offer sent' : 'Request sent',
      message:
          '${shelter.displayName} has been notified. You will get a '
          'notification when they ${_donation ? 'accept' : 'approve'} or '
          'decline — with time and place details.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final shelters = context.watch<RegistrationProvider>().approvedShelters;
    final chosen = shelters.where((s) => s.id == _shelterId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(_donation ? 'Offer food' : 'Request food')),
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
                      FormHeader(
                        icon: _donation
                            ? Icons.volunteer_activism_rounded
                            : Icons.restaurant_rounded,
                        title: _donation
                            ? 'Share surplus meals'
                            : 'Ask for a meal',
                        text: _donation
                            ? 'The shelter you pick will confirm when and where to deliver.'
                            : 'No registration needed. The shelter tells you when to come and whom to meet.',
                      ),
                      FormSection(
                        step: 1,
                        title: 'Choose a shelter',
                        subtitle: 'Tap a card to select it.',
                        child: ShelterPickerField(
                          shelters: shelters,
                          value: _shelterId,
                          onChanged: (id) => setState(() => _shelterId = id),
                        ),
                      ),
                      FormSection(
                        step: 2,
                        title: _donation ? 'Who is offering?' : 'Your details',
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _name,
                              label: _donation
                                  ? 'Restaurant / company name'
                                  : 'Your name',
                              icon: Icons.person_outline_rounded,
                              validator: Validators.name,
                            ),
                            AppTextField(
                              controller: _phone,
                              label: 'Phone number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 16,
                              validator: Validators.phone,
                            ),
                          ],
                        ),
                      ),
                      FormSection(
                        step: 3,
                        title: 'Meal & time',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Which meal?'),
                            Row(
                              children: [
                                OptionTile<MealType>(
                                  value: MealType.breakfast,
                                  groupValue: _meal,
                                  label: 'Breakfast',
                                  icon: Icons.free_breakfast_rounded,
                                  onSelected: (m) => setState(() => _meal = m),
                                ),
                                SizedBox(width: 10.w),
                                OptionTile<MealType>(
                                  value: MealType.lunch,
                                  groupValue: _meal,
                                  label: 'Lunch',
                                  icon: Icons.lunch_dining_rounded,
                                  onSelected: (m) => setState(() => _meal = m),
                                ),
                                SizedBox(width: 10.w),
                                OptionTile<MealType>(
                                  value: MealType.dinner,
                                  groupValue: _meal,
                                  label: 'Dinner',
                                  icon: Icons.dinner_dining_rounded,
                                  onSelected: (m) => setState(() => _meal = m),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            _label(_donation ? 'Available on' : 'Needed on'),
                            DayStrip(
                              offset: _dayOffset,
                              onChanged: (v) => setState(() => _dayOffset = v),
                            ),
                            SizedBox(height: 16.h),
                            CountStepper(
                              label: _donation
                                  ? 'Number of meals'
                                  : 'Number of people',
                              value: _people,
                              max: _donation ? 1000 : 50,
                              step: _donation ? 5 : 1,
                              min: _donation ? 5 : 1,
                              onChanged: (v) => setState(() => _people = v),
                            ),
                          ],
                        ),
                      ),
                      FormSection(
                        step: 4,
                        title: 'Anything else?',
                        child: AppTextField(
                          controller: _note,
                          label: 'Note (optional)',
                          hint: _donation
                              ? 'e.g. biryani, packed, halal'
                              : 'e.g. children, no spicy food',
                          icon: Icons.notes_rounded,
                          maxLines: 2,
                          maxLength: 200,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SubmitBar(
              summary: chosen == null
                  ? 'Select a shelter to continue'
                  : '${_meal.label} · ${dayLabel(DateTime.now().add(Duration(days: _dayOffset)))} · '
                        '$_people ${_donation ? 'meals' : 'people'}\n'
                        '${chosen.displayName}',
              label: _donation ? 'Send offer' : 'Send request',
              loading: _busy,
              onPressed: () => _submit(shelters),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.neutral,
      ),
    ),
  );
}
