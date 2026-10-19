import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/service_request.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../shelters/shelter_detail_screen.dart';
import 'shelter_common.dart';
import 'staff_screens.dart';

DateTime _serviceDay(ServiceRequest r) =>
    DateUtils.dateOnly(r.arrivalAt ?? r.neededDate ?? r.createdAt);

int _headcount(ServiceRequest r) => r.approvedPeople ?? r.people;

/// The shelter's own full profile: photo, residents, daily serving, staff.
class ShelterProfileScreen extends StatelessWidget {
  const ShelterProfileScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final shelter = context.watch<RegistrationProvider>().byId(shelterId);
    if (shelter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const EmptyState(
          icon: Icons.home_work_outlined,
          title: 'Shelter not found',
        ),
      );
    }
    final reqs = context.watch<RequestProvider>().sentTo(shelterId);
    final roster = residentsRoster(reqs);
    final staying = roster.where((r) => r.state == ResidentState.current);
    final arriving = roster.where((r) => r.state == ResidentState.arriving);
    final left = roster.where((r) => r.state == ResidentState.former);
    final peopleStaying = staying.fold<int>(0, (a, r) => a + r.people);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelter profile'),
        actions: [
          IconButton(
            tooltip: 'Edit public profile',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () =>
                AppRouter.push(context, AppRoutes.profileEdit, shelterId),
          ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(shelter: shelter),
              SizedBox(height: 12.h),
              StatGrid(
                children: [
                  StatTile(
                    icon: Icons.groups_rounded,
                    value: '${roster.length}',
                    label: 'Users registered',
                    color: AppColors.primary,
                  ),
                  StatTile(
                    icon: Icons.hotel_rounded,
                    value: '$peopleStaying',
                    label: 'People staying now',
                    color: AppColors.approved,
                  ),
                  StatTile(
                    icon: Icons.bed_rounded,
                    value:
                        '${shelter.totalBeds - shelter.availableBeds}/${shelter.totalBeds}',
                    label: 'Beds occupied',
                    color: AppColors.accent,
                  ),
                ],
              ),
              const SectionTitle('About'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      InfoRow(
                        Icons.person_outline_rounded,
                        'Manager',
                        shelter.name,
                      ),
                      InfoRow(Icons.phone_outlined, 'Phone', shelter.phone),
                      InfoRow(
                        Icons.email_outlined,
                        'Email',
                        shelter.email.isEmpty ? '—' : shelter.email,
                      ),
                      InfoRow(
                        Icons.location_city_rounded,
                        'City',
                        shelter.city,
                      ),
                      InfoRow(Icons.place_outlined, 'Address', shelter.address),
                      InfoRow(
                        Icons.schedule_rounded,
                        'Open hours',
                        shelter.hours.isEmpty ? '—' : shelter.hours,
                      ),
                      InfoRow(
                        Icons.event_available_rounded,
                        'Running since',
                        fmtFullDate(shelter.reviewedAt ?? shelter.createdAt),
                      ),
                      if (shelter.notes.isNotEmpty)
                        InfoRow(
                          Icons.info_outline_rounded,
                          'About',
                          shelter.notes,
                        ),
                    ],
                  ),
                ),
              ),
              if (shelter.services.isNotEmpty) ...[
                const SectionTitle('Help we offer'),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    for (final s in shelter.services)
                      Chip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              const SectionTitle('Users & stays'),
              if (roster.isEmpty)
                Text(
                  'Nobody is registered yet. Approved stays appear here.',
                  style: TextStyle(color: AppColors.neutral, fontSize: 13.sp),
                )
              else ...[
                _ResidentGroup(
                  title: 'Staying now',
                  color: AppColors.approved,
                  items: staying.toList(),
                  shelterId: shelterId,
                ),
                _ResidentGroup(
                  title: 'Coming soon',
                  color: AppColors.accent,
                  items: arriving.toList(),
                  shelterId: shelterId,
                ),
                _ResidentGroup(
                  title: 'Left the shelter',
                  color: AppColors.neutral,
                  items: left.toList(),
                  shelterId: shelterId,
                ),
              ],
              const SectionTitle('Daily serving'),
              _ServingSection(requests: reqs),
              const SectionTitle('Staff'),
              StaffSection(shelterId: shelterId),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.shelter});

  final Registration shelter;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          ShelterCover(shelter: shelter, height: 210.h),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16.w,
            right: 16.w,
            bottom: 14.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shelter.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${shelter.city} · ${shelter.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResidentGroup extends StatelessWidget {
  const _ResidentGroup({
    required this.title,
    required this.color,
    required this.items,
    required this.shelterId,
  });

  final String title;
  final Color color;
  final List<Resident> items;
  final String shelterId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 8.h, bottom: 6.h),
          child: Text(
            '$title · ${items.length}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  onTap: () => AppRouter.push(
                    context,
                    AppRoutes.shelterUser,
                    '${items[i].userId}|$shelterId',
                  ),
                  leading: PersonAvatar(
                    name: items[i].name,
                    radius: 18,
                    color: color,
                  ),
                  title: Text(
                    items[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    items[i].state == ResidentState.arriving
                        ? 'Arrives ${fmtFullDate(items[i].latest.arrivalAt!)}'
                        : items[i].until != null
                        ? '${fmtFullDate(items[i].since)} → ${fmtFullDate(items[i].until!)}'
                        : 'Since ${fmtFullDate(items[i].since)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Meals / help given out, built from the requests this shelter handled.
class _ServingSection extends StatelessWidget {
  const _ServingSection({required this.requests});

  final List<ServiceRequest> requests;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final meals = requests
        .where(
          (r) =>
              r.type == RequestType.food && r.status == ReviewStatus.approved,
        )
        .toList();
    final donations = requests
        .where(
          (r) =>
              r.type == RequestType.donation &&
              r.status == ReviewStatus.approved,
        )
        .toList();

    int sum(Iterable<ServiceRequest> l) =>
        l.fold(0, (a, r) => a + _headcount(r));

    final todayMeals = meals.where((r) => _serviceDay(r) == today).toList();
    final servedToday = todayMeals.where((r) => r.fulfilledAt != null);
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final perDay = [
      for (final d in days)
        sum(meals.where((r) => r.fulfilledAt != null && _serviceDay(r) == d)),
    ];
    final maxDay = perDay.fold<int>(1, (a, b) => a > b ? a : b);
    final avg = (perDay.fold<int>(0, (a, b) => a + b) / 7).round();

    final since = today.subtract(const Duration(days: 30));
    final help = <HelpCategory, int>{};
    for (final r in requests) {
      if (r.type == RequestType.help &&
          r.status == ReviewStatus.approved &&
          r.category != null &&
          !r.createdAt.isBefore(since)) {
        help[r.category!] = (help[r.category!] ?? 0) + 1;
      }
    }
    final helpSorted = help.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatGrid(
          children: [
            StatTile(
              value: '${sum(todayMeals)}',
              label: 'Meals planned today',
              color: AppColors.primary,
            ),
            StatTile(
              value: '${sum(servedToday)}',
              label: 'Served today',
              color: AppColors.approved,
            ),
            StatTile(
              value: '${sum(donations.where((r) => _serviceDay(r) == today))}',
              label: 'Donated today',
              color: AppColors.accent,
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Meals served · last 7 days',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'avg $avg / day',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  height: 96.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${perDay[i]}',
                                  style: TextStyle(fontSize: 10.sp),
                                ),
                                SizedBox(height: 2.h),
                                Container(
                                  height: 4.h + 48.h * perDay[i] / maxDay,
                                  decoration: BoxDecoration(
                                    color: days[i] == today
                                        ? AppColors.primary
                                        : AppColors.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '${days[i].day}',
                                  style: TextStyle(
                                    fontSize: 10.sp,
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
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where help is going · last 30 days',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8.h),
                if (helpSorted.isEmpty)
                  Text(
                    'No approved help requests in the last 30 days.',
                    style: TextStyle(color: AppColors.neutral, fontSize: 13.sp),
                  )
                else
                  for (final e in helpSorted)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      child: Row(
                        children: [
                          Text(e.key.emoji, style: TextStyle(fontSize: 16.sp)),
                          SizedBox(width: 8.w),
                          Expanded(child: Text(e.key.label)),
                          Text(
                            '${e.value} request${e.value == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Free / total beds with steppers. Beds also drop automatically when a stay
/// is approved.
class BedManagementScreen extends StatelessWidget {
  const BedManagementScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RegistrationProvider>().byId(shelterId);
    return Scaffold(
      appBar: AppBar(title: const Text('Bed management')),
      body: SafeArea(
        child: p == null
            ? const EmptyState(
                icon: Icons.bed_outlined,
                title: 'Shelter not found',
              )
            : PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BedsBar(available: p.availableBeds, total: p.totalBeds),
                    SizedBox(height: 14.h),
                    CountStepper(
                      label: 'Free beds',
                      value: p.availableBeds,
                      min: 0,
                      max: p.totalBeds,
                      onChanged: (v) => context
                          .read<RegistrationProvider>()
                          .updateBeds(p.id, total: p.totalBeds, available: v),
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
                    SizedBox(height: 10.h),
                    Text(
                      'Beds are reduced automatically when you approve a stay.',
                      style: TextStyle(
                        color: AppColors.neutral,
                        fontSize: 12.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
