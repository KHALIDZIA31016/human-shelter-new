import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';

/// Ask a shelter for any of the 12 kinds of help. One request may contain
/// several items; each category is limited to 2 per shelter per 24 hours.
class HelpRequestScreen extends StatefulWidget {
  const HelpRequestScreen({super.key, this.shelterId, this.category});

  final String? shelterId;
  final HelpCategory? category;

  @override
  State<HelpRequestScreen> createState() => _HelpRequestScreenState();
}

class _HelpRequestScreenState extends State<HelpRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();

  String? _shelterId;
  HelpCategory? _category;
  final Set<String> _items = {};
  int _people = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _shelterId = widget.shelterId;
    _category = widget.category;
    final session = context.read<SessionProvider>();
    final me = context.read<RegistrationProvider>().individualOf(
      session.deviceId,
    );
    if (me != null) {
      _name.text = me.name;
      _phone.text = me.phone;
      _people = me.familyMembers;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _toast(String m, {bool warn = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: warn ? AppColors.pending : null,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  /// Warns about the 24h limit. Returns false when the category is blocked.
  bool _checkLimit(HelpCategory c, {bool announce = true}) {
    final sid = _shelterId;
    if (sid == null) return true;
    final session = context.read<SessionProvider>();
    final reqs = context.read<RequestProvider>();
    final shelterName =
        context.read<RegistrationProvider>().byId(sid)?.displayName ??
        'this shelter';
    final next = reqs.nextSlot(session.deviceId, sid, c);
    if (next != null) {
      if (announce) {
        _toast(
          'You already sent $kCategoryLimit ${c.label} requests to '
          '$shelterName today. You can ask again after ${fmtDateTime(next)}.',
          warn: true,
        );
      }
      return false;
    }
    final used = reqs.recentFor(session.deviceId, sid, c).length;
    if (announce && used == kCategoryLimit - 1) {
      _toast(
        'Heads up: you already sent a ${c.label} request to $shelterName in '
        'the last 24 hours. Only 1 more is allowed.',
        warn: true,
      );
    }
    return true;
  }

  void _pickCategory(HelpCategory c) {
    if (!_checkLimit(c)) return;
    setState(() {
      if (_category != c) _items.clear();
      _category = c;
    });
  }

  Future<void> _submit() async {
    final shelters = context.read<RegistrationProvider>();
    if (!_form.currentState!.validate()) return;
    final shelter = shelters.byId(_shelterId);
    if (shelter == null) return;
    final c = _category;
    if (c == null) {
      _toast('Please choose what kind of help you need.');
      return;
    }
    if (_items.isEmpty) {
      _toast('Select at least one item.');
      return;
    }
    if (!_checkLimit(c, announce: false)) {
      _checkLimit(c);
      return;
    }
    setState(() => _busy = true);
    final session = context.read<SessionProvider>();
    final reqs = context.read<RequestProvider>();
    final usedBefore = reqs.recentFor(session.deviceId, shelter.id, c).length;
    final err = await reqs.create(
      ServiceRequest(
        id: newId(),
        type: RequestType.help,
        requesterId: session.deviceId,
        requesterName: _name.text.trim(),
        phone: _phone.text.trim(),
        targetId: shelter.id,
        targetName: shelter.displayName,
        people: _people,
        message: _note.text.trim(),
        category: c,
        items: _items.toList(),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(err, warn: true);
      return;
    }
    final last = usedBefore + 1 >= kCategoryLimit;
    await showSuccessDialog(
      context,
      title: 'Request sent',
      message:
          '${shelter.displayName} has been notified and will decide. You will '
          'get a notification with time and place.'
          '${last ? '\n\nThis was your last ${c.label} request to this shelter for 24 hours.' : ''}',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final shelters = context.watch<RegistrationProvider>().approvedShelters;
    final chosen = shelters.where((s) => s.id == _shelterId).firstOrNull;
    final cat = _category;
    return Scaffold(
      appBar: AppBar(title: const Text('Request help')),
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
                      const FormHeader(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'Ask for what you need',
                        text:
                            'Pick a shelter, a category and one or more items. Each category can be requested twice per shelter every 24 hours.',
                      ),
                      FormSection(
                        step: 1,
                        title: 'Choose a shelter',
                        child: ShelterPickerField(
                          shelters: shelters,
                          value: _shelterId,
                          onChanged: (id) => setState(() => _shelterId = id),
                        ),
                      ),
                      FormSection(
                        step: 2,
                        title: 'What kind of help?',
                        subtitle: _shelterId == null
                            ? 'Choose a shelter first to see your daily limit.'
                            : 'Tap a category.',
                        child: _CategoryGrid(
                          selected: cat,
                          shelterId: _shelterId,
                          onTap: _pickCategory,
                        ),
                      ),
                      if (cat != null)
                        FormSection(
                          step: 3,
                          title: '${cat.emoji} ${cat.label} items',
                          subtitle:
                              'Select everything you need in one request.',
                          child: Wrap(
                            spacing: 8.w,
                            runSpacing: 4.h,
                            children: [
                              for (final i in cat.items)
                                FilterChip(
                                  label: Text(i),
                                  selected: _items.contains(i),
                                  onSelected: (on) => setState(
                                    () => on ? _items.add(i) : _items.remove(i),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      FormSection(
                        step: cat == null ? 3 : 4,
                        title: 'Your details',
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _name,
                              label: 'Your name',
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
                            CountStepper(
                              label: 'People this is for',
                              value: _people,
                              max: 50,
                              onChanged: (v) => setState(() => _people = v),
                            ),
                            SizedBox(height: 14.h),
                            AppTextField(
                              controller: _note,
                              label: 'Note (optional)',
                              icon: Icons.notes_rounded,
                              maxLines: 2,
                              maxLength: 200,
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
              summary: chosen == null
                  ? 'Select a shelter to continue'
                  : '${cat == null ? 'No category' : '${cat.emoji} ${cat.label}'}'
                        '${_items.isEmpty ? '' : ' · ${_items.length} item${_items.length == 1 ? '' : 's'}'}\n'
                        '${chosen.displayName}',
              label: 'Send request',
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.selected,
    required this.shelterId,
    required this.onTap,
  });

  final HelpCategory? selected;
  final String? shelterId;
  final ValueChanged<HelpCategory> onTap;

  @override
  Widget build(BuildContext context) {
    final reqs = context.watch<RequestProvider>();
    final me = context.watch<SessionProvider>().deviceId;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 1.0,
      children: [
        for (final c in HelpCategory.values)
          _CategoryTile(
            category: c,
            on: selected == c,
            used: shelterId == null
                ? 0
                : reqs.recentFor(me, shelterId!, c).length,
            onTap: () => onTap(c),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.on,
    required this.used,
    required this.onTap,
  });

  final HelpCategory category;
  final bool on;
  final int used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blocked = used >= kCategoryLimit;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Opacity(
        opacity: blocked ? 0.5 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: on ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? AppColors.primary : const Color(0xFFCBD5E1),
              width: on ? 1.8 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.emoji, style: TextStyle(fontSize: 28.sp)),
                    SizedBox(height: 4.h),
                    Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: on ? AppColors.primary : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              if (used > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: blocked ? AppColors.rejected : AppColors.pending,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$used/$kCategoryLimit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
