import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/screen_utils.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../providers/registration_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/image_picker_field.dart';

/// Partner edits its public profile. Users see the changes immediately.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _phone,
      _email,
      _city,
      _address,
      _hours,
      _about,
      _image;
  final Set<String> _services = {};
  late final bool _isShelter;

  @override
  void initState() {
    super.initState();
    final p = context.read<RegistrationProvider>().byId(widget.partnerId)!;
    _isShelter = p.kind == RegistrationKind.shelter;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone);
    _email = TextEditingController(text: p.email);
    _city = TextEditingController(text: p.city);
    _address = TextEditingController(text: p.address);
    _hours = TextEditingController(text: p.hours);
    _about = TextEditingController(text: p.notes);
    _image = TextEditingController(text: p.imageUrl ?? '');
    _services.addAll(p.services);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _city,
      _address,
      _hours,
      _about,
      _image,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await context.read<RegistrationProvider>().updateProfile(
      widget.partnerId,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      city: _city.text.trim(),
      address: _address.text.trim(),
      hours: _hours.text.trim(),
      notes: _about.text.trim(),
      imageUrl: _image.text.trim(),
      services: _services.toList(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated. Users see it now.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                      FormSection(
                        step: 1,
                        title: 'Contact',
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _name,
                              label: 'Contact person',
                              icon: Icons.person_outline_rounded,
                              validator: Validators.name,
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
                          ],
                        ),
                      ),
                      FormSection(
                        step: 2,
                        title: 'Location & hours',
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _city,
                              label: 'City',
                              icon: Icons.location_city_rounded,
                              validator: (v) => Validators.required(v, 'City'),
                            ),
                            AppTextField(
                              controller: _address,
                              label: 'Full address',
                              icon: Icons.place_outlined,
                              maxLines: 2,
                              validator: (v) =>
                                  Validators.required(v, 'Address'),
                            ),
                            AppTextField(
                              controller: _hours,
                              label: 'Opening hours (optional)',
                              hint: 'e.g. Daily 8 AM – 10 PM',
                              icon: Icons.schedule_rounded,
                            ),
                          ],
                        ),
                      ),
                      FormSection(
                        step: 3,
                        title: 'About & photo',
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _about,
                              label: 'About us',
                              icon: Icons.notes_rounded,
                              maxLines: 4,
                              maxLength: 400,
                            ),
                            ImagePickerField(
                              controller: _image,
                              label: _isShelter
                                  ? 'Shelter photo'
                                  : 'Profile photo',
                            ),
                          ],
                        ),
                      ),
                      if (_isShelter)
                        FormSection(
                          step: 4,
                          title: 'Help we offer',
                          subtitle: 'Users see these on your profile.',
                          child: Wrap(
                            spacing: 8.w,
                            runSpacing: 4.h,
                            children: [
                              for (final c in HelpCategory.values)
                                FilterChip(
                                  label: Text('${c.emoji} ${c.label}'),
                                  selected: _services.contains(c.name),
                                  onSelected: (on) => setState(
                                    () => on
                                        ? _services.add(c.name)
                                        : _services.remove(c.name),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SubmitBar(
              summary: 'Changes are visible to users immediately',
              label: 'Save profile',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
