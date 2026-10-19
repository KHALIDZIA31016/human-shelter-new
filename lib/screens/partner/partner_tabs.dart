import 'package:flutter/material.dart';

import '../profile/profile_screen.dart' show confirmLogout;
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/request_widgets.dart';
import '../shelters/shelter_detail_screen.dart';

/// Shelter: incoming requests to approve / reject.
/// Restaurant / company: donation offers they have sent.
class PartnerRequestsTab extends StatefulWidget {
  const PartnerRequestsTab({super.key, required this.partner});

  final Registration partner;

  @override
  State<PartnerRequestsTab> createState() => _PartnerRequestsTabState();
}

class _PartnerRequestsTabState extends State<PartnerRequestsTab> {
  ReviewStatus? _filter = ReviewStatus.pending;

  @override
  Widget build(BuildContext context) {
    final isShelter = widget.partner.kind == RegistrationKind.shelter;
    final provider = context.watch<RequestProvider>();
    final all = isShelter
        ? provider.sentTo(widget.partner.id)
        : provider
              .sentBy(widget.partner.id)
              .where((r) => r.type == RequestType.donation)
              .toList();
    final items = _filter == null
        ? all
        : all.where((r) => r.status == _filter).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isShelter
          ? null
          : FloatingActionButton.extended(
              onPressed: () => AppRouter.push(
                context,
                AppRoutes.foodForm,
                const FoodFormArgs(type: RequestType.donation),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Offer food'),
            ),
      body: Column(
        children: [
          if (isShelter)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
              child: Row(
                children: [
                  for (final (label, count, color) in [
                    (
                      'Pending',
                      all.where((r) => r.isPending).length,
                      AppColors.pending,
                    ),
                    (
                      'Approved',
                      all
                          .where((r) => r.status == ReviewStatus.approved)
                          .length,
                      AppColors.approved,
                    ),
                    ('Total', all.length, AppColors.primary),
                  ])
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: 8.w),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: AppColors.neutral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusFilterBar(
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.inbox_outlined,
                    title: _filter == ReviewStatus.pending
                        ? (isShelter
                              ? 'No pending requests'
                              : 'No pending offers')
                        : 'Nothing here',
                    message: isShelter
                        ? 'Stay and food requests sent to your shelter appear here.'
                        : 'Tap "Offer food" to send surplus meals to a shelter.',
                  )
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ScreenUtils.maxContentWidth,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 90.h),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => SizedBox(height: 12.h),
                        itemBuilder: (_, i) => RequestCard(
                          request: items[i],
                          canDecide: isShelter,
                          showTarget: !isShelter,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class PartnerProfileTab extends StatelessWidget {
  const PartnerProfileTab({super.key, required this.partner});

  final Registration partner;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RegistrationProvider>().byId(partner.id) ?? partner;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.displayName,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
          ),
          Text(
            '${p.kind.label} partner',
            style: TextStyle(color: AppColors.neutral, fontSize: 14.sp),
          ),
          SizedBox(height: 14.h),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  InfoRow(Icons.person_outline_rounded, 'Contact', p.name),
                  InfoRow(Icons.phone_outlined, 'Phone', p.phone),
                  InfoRow(Icons.location_city_rounded, 'City', p.city),
                  InfoRow(Icons.place_outlined, 'Address', p.address),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          AppButton(
            label: 'Edit public profile',
            icon: Icons.edit_rounded,
            onPressed: () =>
                AppRouter.push(context, AppRoutes.profileEdit, p.id),
          ),
          if (p.kind == RegistrationKind.shelter) ...[
            const SectionTitle('Bed management'),
            BedsBar(available: p.availableBeds, total: p.totalBeds),
            SizedBox(height: 12.h),
            CountStepper(
              label: 'Free beds',
              value: p.availableBeds,
              min: 0,
              max: p.totalBeds,
              onChanged: (v) => context.read<RegistrationProvider>().updateBeds(
                p.id,
                total: p.totalBeds,
                available: v,
              ),
            ),
            SizedBox(height: 10.h),
            CountStepper(
              label: 'Total beds',
              value: p.totalBeds,
              min: 1,
              max: 500,
              onChanged: (v) {
                // Keep the number of occupied beds constant.
                final occupied = p.totalBeds - p.availableBeds;
                context.read<RegistrationProvider>().updateBeds(
                  p.id,
                  total: v,
                  available: (v - occupied).clamp(0, v),
                );
              },
            ),
            SizedBox(height: 8.h),
            Text(
              'Beds are reduced automatically when you approve a stay.',
              style: TextStyle(color: AppColors.neutral, fontSize: 12.5.sp),
            ),
          ],
          SizedBox(height: 24.h),
          AppButton(
            label: 'Log out',
            icon: Icons.logout_rounded,
            outlined: true,
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
