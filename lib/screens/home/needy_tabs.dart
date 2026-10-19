import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/request_widgets.dart';
import '../shelters/shelter_detail_screen.dart';
export 'needy_home_tab.dart';

class SheltersTab extends StatelessWidget {
  const SheltersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final shelters = context.watch<RegistrationProvider>().approvedShelters;
    if (shelters.isEmpty) {
      return const EmptyState(
        icon: Icons.home_work_outlined,
        title: 'No shelters yet',
        message: 'Approved shelters will appear here.',
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenUtils.maxContentWidth,
        ),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          itemCount: shelters.length,
          separatorBuilder: (_, _) => SizedBox(height: 12.h),
          itemBuilder: (_, i) => ShelterCard(shelterId: shelters[i].id),
        ),
      ),
    );
  }
}

class MyRequestsTab extends StatelessWidget {
  const MyRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.watch<SessionProvider>().deviceId;
    final flat = context.watch<RequestProvider>().sentBy(id);
    final items = groupRequests(flat);
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No requests yet',
        message: 'Your food and shelter requests will show up here.',
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenUtils.maxContentWidth,
        ),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: 16.h),
          itemBuilder: (_, i) {
            if (i == 0) {
              final active = flat
                  .where(
                    (r) =>
                        r.visitState == VisitState.pending ||
                        r.visitState == VisitState.upcoming ||
                        r.visitState == VisitState.due,
                  )
                  .length;
              return Text(
                '${flat.length} request${flat.length == 1 ? '' : 's'} · $active active',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral,
                ),
              );
            }
            final it = items[i - 1];
            return it is RequestGroup
                ? RequestGroupCard(group: it)
                : RequestCard(request: it as ServiceRequest, showTarget: true);
          },
        ),
      ),
    );
  }
}
