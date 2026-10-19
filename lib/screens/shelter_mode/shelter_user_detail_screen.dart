import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/service_request.dart';
import '../../providers/chat_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/request_widgets.dart';
import 'shelter_common.dart';

/// Full profile of one person registered at this shelter, built from what
/// they submitted plus what the shelter decided.
class ShelterUserDetailScreen extends StatelessWidget {
  const ShelterUserDetailScreen({
    super.key,
    required this.userId,
    required this.shelterId,
  });

  final String userId;
  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final reqs = context.watch<RequestProvider>();
    final profile = context.watch<RegistrationProvider>().individualOf(userId);
    final unread = context.watch<ChatProvider>().unreadForShelter(
      shelterId,
      userId,
    );
    final sent = reqs.sentTo(shelterId).where((r) => r.requesterId == userId);
    final all = sent.toList();
    final resident = residentsRoster(all).where((r) => r.userId == userId);

    if (resident.isEmpty && all.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('User')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'User not found',
        ),
      );
    }
    final res = resident.isEmpty ? null : resident.first;
    final name = res?.name ?? profile?.name ?? all.first.requesterName;
    final stay = res?.latest;
    final people = res?.people ?? profile?.familyMembers ?? 1;
    final state = res?.state;

    return Scaffold(
      appBar: AppBar(title: const Text('User profile')),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                name: name,
                profile: profile,
                state: state,
                people: people,
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: unread > 0 ? 'Chat · $unread new' : 'Chat',
                      icon: Icons.chat_bubble_rounded,
                      onPressed: () => AppRouter.push(
                        context,
                        AppRoutes.chat,
                        '$userId|$shelterId',
                      ),
                    ),
                  ),
                  if (stay != null &&
                      stay.status == ReviewStatus.approved &&
                      stay.fulfilledAt == null &&
                      stay.closedAt == null &&
                      stay.endedAt == null) ...[
                    SizedBox(width: 10.w),
                    Expanded(
                      child: AppButton(
                        label: 'Edit',
                        icon: Icons.edit_calendar_rounded,
                        outlined: true,
                        onPressed: () => _editCheckIn(context, stay),
                      ),
                    ),
                  ],
                ],
              ),
              const SectionTitle('Personal details'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      InfoRow(Icons.person_outline_rounded, 'Name', name),
                      InfoRow(
                        Icons.phone_outlined,
                        'Phone',
                        _or(profile?.phone ?? stay?.phone),
                      ),
                      InfoRow(
                        Icons.email_outlined,
                        'Email',
                        _or(profile?.email),
                      ),
                      InfoRow(
                        Icons.cake_outlined,
                        'Age',
                        profile?.age == null ? '—' : '${profile!.age} years',
                      ),
                      InfoRow(
                        Icons.groups_rounded,
                        'Staying',
                        people <= 1 ? 'Alone' : 'With family · $people people',
                      ),
                      InfoRow(
                        Icons.location_city_rounded,
                        'City',
                        _or(profile?.city),
                      ),
                      InfoRow(
                        Icons.place_outlined,
                        'Address',
                        _or(profile?.address),
                      ),
                      if (profile != null)
                        InfoRow(
                          Icons.event_available_rounded,
                          'App member since',
                          fmtFullDate(profile.createdAt),
                        ),
                    ],
                  ),
                ),
              ),
              if (profile != null &&
                  (profile.needs.isNotEmpty || profile.notes.isNotEmpty)) ...[
                const SectionTitle('Needs & notes'),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile.needs.isNotEmpty)
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 6.h,
                            children: [
                              for (final n in profile.needs)
                                Chip(
                                  label: Text(n),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        if (profile.needs.isNotEmpty &&
                            profile.notes.isNotEmpty)
                          SizedBox(height: 10.h),
                        if (profile.notes.isNotEmpty)
                          Text(
                            profile.notes,
                            style: TextStyle(fontSize: 14.sp, height: 1.45),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (res != null && stay != null) ...[
                const SectionTitle('Stay at this shelter'),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      children: [
                        InfoRow(Icons.flag_rounded, 'Status', res.state.label),
                        InfoRow(
                          Icons.bed_rounded,
                          'Bed no',
                          _or(stay.bedLabel),
                        ),
                        InfoRow(
                          Icons.login_rounded,
                          'Registered here',
                          fmtFullDate(res.since),
                        ),
                        InfoRow(
                          Icons.logout_rounded,
                          res.until != null ? 'Left on' : 'Allotted until',
                          res.until != null
                              ? fmtFullDate(res.until!)
                              : (stay.allottedUntil == null
                                    ? 'Open stay'
                                    : fmtFullDate(stay.allottedUntil!)),
                        ),
                        InfoRow(
                          Icons.timelapse_rounded,
                          res.until != null ? 'Stayed for' : 'Staying for',
                          res.state == ResidentState.arriving
                              ? 'Not arrived yet'
                              : spanLabel(
                                  res.since,
                                  res.until ?? DateTime.now(),
                                ),
                        ),
                        InfoRow(
                          Icons.support_agent_rounded,
                          'Contact person',
                          _or(stay.contactPerson),
                        ),
                        if (res.until != null && stay.endReason != null)
                          InfoRow(
                            Icons.info_outline_rounded,
                            'Reason',
                            stay.endReason!,
                          ),
                        if ((stay.decisionNote ?? '').isNotEmpty)
                          InfoRow(
                            Icons.sticky_note_2_outlined,
                            'Shelter note',
                            stay.decisionNote!,
                          ),
                        if (stay.arrivalAt != null)
                          InfoRow(
                            Icons.event_available_rounded,
                            'Check-in time',
                            fmtDateTime(stay.arrivalAt!),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              SectionTitle(
                'Requests to this shelter',
                trailing: Text(
                  '${all.length}',
                  style: const TextStyle(
                    color: AppColors.neutral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (all.isEmpty)
                Text(
                  'No requests yet.',
                  style: TextStyle(color: AppColors.neutral, fontSize: 13.sp),
                )
              else
                for (final r in all) ...[
                  RequestCard(request: r, canDecide: false),
                  SizedBox(height: 10.h),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _editCheckIn(BuildContext context, ServiceRequest stay) async {
  var at = stay.arrivalAt ?? DateTime.now().add(const Duration(hours: 1));
  final name = TextEditingController(text: stay.contactPerson ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Edit check-in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only the check-in time and the person allowed to check in can '
              'be changed after approval.',
              style: TextStyle(fontSize: 13.sp, color: AppColors.neutral),
            ),
            SizedBox(height: 14.h),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded),
              label: Text(fmtDateTime(at)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: at,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d == null || !ctx.mounted) return;
                final t = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.fromDateTime(at),
                );
                if (t == null) return;
                setS(
                  () => at = DateTime(d.year, d.month, d.day, t.hour, t.minute),
                );
              },
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Person allowed to check in',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final err = await context.read<RequestProvider>().editApproval(
    stay.id,
    arrivalAt: at,
    contactPerson: name.text,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(err ?? 'Check-in details updated.')));
}

String _or(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.profile,
    required this.state,
    required this.people,
  });

  final String name;
  final Registration? profile;
  final ResidentState? state;
  final int people;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF134E4A)],
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
              name: name,
              imageUrl: profile?.imageUrl,
              radius: 36,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  people <= 1 ? 'Alone' : 'With family · $people people',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.sp,
                  ),
                ),
                if (state != null) ...[
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
                      state!.label,
                      style: TextStyle(
                        color: state!.color,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
