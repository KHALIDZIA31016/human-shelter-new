import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/request_widgets.dart';
import '../../widgets/visit_widgets.dart';

/// Everything about the user's registration: when, which shelter, what was
/// asked for, which bed, and until when.
class RegistrationDetailScreen extends StatelessWidget {
  const RegistrationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final me = context.watch<RegistrationProvider>().individualOf(
      session.deviceId,
    );
    final reqs = context.watch<RequestProvider>();
    final stay = reqs.activeStay(session.deviceId);
    final all = reqs.sentBy(session.deviceId);
    final stays = all.where((r) => r.type == RequestType.stay).toList();
    final others = all
        .where(
          (r) => r.type != RequestType.stay && r.type != RequestType.donation,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My registration')),
      body: SafeArea(
        child: me == null
            ? const EmptyState(
                icon: Icons.badge_outlined,
                title: 'Not registered',
                message: 'Register for help from the Home tab.',
              )
            : PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormHeader(
                      icon: Icons.badge_rounded,
                      title: me.name,
                      text:
                          '${me.status.label} · registered ${fmtDate(me.createdAt)}'
                          '${me.reviewedAt == null ? '' : '\nReviewed ${fmtDate(me.reviewedAt!)}'}',
                    ),
                    FormSection(
                      step: 1,
                      title: 'Registration',
                      child: Column(
                        children: [
                          InfoRow(
                            Icons.event_rounded,
                            'Registered on',
                            fmtDateTime(me.createdAt),
                          ),
                          InfoRow(
                            Icons.verified_rounded,
                            'Status',
                            me.status.label,
                          ),
                          if (me.reviewedAt != null)
                            InfoRow(
                              Icons.fact_check_rounded,
                              'Reviewed on',
                              fmtDateTime(me.reviewedAt!),
                            ),
                          InfoRow(
                            Icons.groups_rounded,
                            'People',
                            '${me.familyMembers}',
                          ),
                          if (me.needs.isNotEmpty)
                            InfoRow(
                              Icons.favorite_border_rounded,
                              'Needs',
                              me.needs.join(', '),
                            ),
                          if (me.notes.isNotEmpty)
                            InfoRow(
                              Icons.notes_rounded,
                              'My situation',
                              me.notes,
                            ),
                          if (me.rejectReason != null)
                            InfoRow(
                              Icons.cancel_outlined,
                              'Rejected',
                              me.rejectReason!,
                            ),
                        ],
                      ),
                    ),
                    FormSection(
                      step: 2,
                      title: 'Shelter allotment',
                      subtitle: stay == null
                          ? 'You are not placed in a shelter right now.'
                          : null,
                      child: stay == null
                          ? stays.isEmpty
                                ? const Text('No stay requested yet.')
                                : Column(
                                    children: [
                                      for (final r in stays) _StayRow(r),
                                    ],
                                  )
                          : Column(
                              children: [
                                InfoRow(
                                  Icons.home_work_rounded,
                                  'Shelter',
                                  stay.targetName,
                                ),
                                InfoRow(
                                  Icons.bed_rounded,
                                  'Bed',
                                  stay.bedLabel ?? '—',
                                ),
                                InfoRow(
                                  Icons.groups_rounded,
                                  'People',
                                  '${stay.approvedPeople ?? stay.people}',
                                ),
                                if (stay.arrivalAt != null)
                                  InfoRow(
                                    Icons.login_rounded,
                                    'Arrival',
                                    fmtDateTime(stay.arrivalAt!),
                                  ),
                                if (stay.allottedUntil != null)
                                  InfoRow(
                                    Icons.event_available_rounded,
                                    'Allotted until',
                                    fmtDate(stay.allottedUntil!),
                                  ),
                                if ((stay.contactPerson ?? '').isNotEmpty)
                                  InfoRow(
                                    Icons.badge_outlined,
                                    'Contact',
                                    stay.contactPerson!,
                                  ),
                                SizedBox(height: 8.h),
                                AppButton(
                                  label: 'View shelter profile',
                                  outlined: true,
                                  icon: Icons.home_work_rounded,
                                  onPressed: () => AppRouter.push(
                                    context,
                                    AppRoutes.shelter,
                                    stay.targetId,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    FormSection(
                      step: 3,
                      title: 'What I requested',
                      subtitle:
                          '${others.length} request${others.length == 1 ? '' : 's'} (meals and other help)',
                      child: others.isEmpty
                          ? const Text('Nothing yet.')
                          : Column(
                              children: [
                                for (final r in others.take(12))
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () => AppRouter.push(
                                      context,
                                      AppRoutes.request,
                                      r.id,
                                    ),
                                    leading: Text(
                                      r.helpCategory?.emoji ?? '🍽️',
                                      style: TextStyle(fontSize: 22.sp),
                                    ),
                                    title: Text(
                                      r.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${r.targetName} · ${fmtDate(r.createdAt)}',
                                    ),
                                    trailing: VisitStateChip(r.visitState),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StayRow extends StatelessWidget {
  const _StayRow(this.r);

  final ServiceRequest r;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: () => AppRouter.push(context, AppRoutes.request, r.id),
    leading: Icon(requestIcon(r.type), color: AppColors.primary),
    title: Text(r.targetName),
    subtitle: Text(
      '${r.bedLabel ?? 'Stay'} · ${fmtDate(r.createdAt)}'
      '${r.allottedUntil == null ? '' : ' → ${fmtDate(r.allottedUntil!)}'}',
    ),
    trailing: VisitStateChip(r.visitState),
  );
}
