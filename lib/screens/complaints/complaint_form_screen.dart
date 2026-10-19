import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/complaint.dart';
import '../../data/models/enums.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';

/// Confidential complaint to the admin about a shelter.
class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key, this.requestId});

  final String? requestId;

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  String? _shelterId;
  String? _requestId;
  ComplaintReason _reason = ComplaintReason.notDelivered;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = context.read<RequestProvider>().byId(widget.requestId);
    if (r != null) {
      _requestId = r.id;
      _shelterId = r.targetId;
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final session = context.read<SessionProvider>();
    final regs = context.read<RegistrationProvider>();
    final shelter = regs.byId(_shelterId);
    if (shelter == null) return;
    final req = context.read<RequestProvider>().byId(_requestId);
    final me = regs.individualOf(session.deviceId);
    setState(() => _busy = true);
    await context.read<ComplaintProvider>().submit(
      Complaint(
        id: newId(),
        complainantId: session.deviceId,
        complainantName: me?.name ?? req?.requesterName ?? 'A user',
        phone: me?.phone ?? req?.phone ?? '',
        shelterId: shelter.id,
        shelterName: shelter.displayName,
        reason: _reason,
        message: _message.text.trim(),
        requestId: req?.id,
        requestSummary: req == null
            ? ''
            : '${req.title} · ${fmtDate(req.createdAt)}',
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await showSuccessDialog(
      context,
      title: 'Complaint sent',
      icon: Icons.shield_rounded,
      message:
          'Only the admin can see your complaint. The shelter is not told who '
          'complained. We will update you here and in notifications.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final shelters = context.watch<RegistrationProvider>().approvedShelters;
    final mine = context
        .watch<RequestProvider>()
        .sentBy(session.deviceId)
        .where((r) => r.targetId == _shelterId)
        .toList();
    final chosen = shelters.where((s) => s.id == _shelterId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
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
                        icon: Icons.shield_rounded,
                        title: 'Confidential complaint',
                        text:
                            'Goes to the admin only. The shelter is not told you complained; admin verifies with them first.',
                      ),
                      FormSection(
                        step: 1,
                        title: 'Which shelter?',
                        child: ShelterPickerField(
                          shelters: shelters,
                          value: _shelterId,
                          onChanged: (id) => setState(() {
                            if (id != _shelterId) _requestId = null;
                            _shelterId = id;
                          }),
                        ),
                      ),
                      if (_shelterId != null && mine.isNotEmpty)
                        FormSection(
                          step: 2,
                          title: 'Which request? (optional)',
                          child: Column(
                            children: [
                              for (final r in mine.take(8))
                                RadioListTile<String>(
                                  value: r.id,
                                  groupValue: _requestId,
                                  onChanged: (v) =>
                                      setState(() => _requestId = v),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${r.status.label} · ${timeAgo(r.createdAt)}',
                                  ),
                                ),
                              if (_requestId != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => _requestId = null),
                                    child: const Text('Clear selection'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      FormSection(
                        step: _shelterId != null && mine.isNotEmpty ? 3 : 2,
                        title: 'What went wrong?',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 4.h,
                              children: [
                                for (final r in ComplaintReason.values)
                                  ChoiceChip(
                                    label: Text(r.label),
                                    selected: _reason == r,
                                    onSelected: (_) =>
                                        setState(() => _reason = r),
                                  ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            AppTextField(
                              controller: _message,
                              label: 'Tell us what happened',
                              icon: Icons.notes_rounded,
                              maxLines: 4,
                              maxLength: 500,
                              validator: (v) => (v ?? '').trim().length < 10
                                  ? 'Please write at least 10 characters'
                                  : null,
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
                  : '${_reason.label} · ${chosen.displayName}',
              label: 'Send to admin',
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
