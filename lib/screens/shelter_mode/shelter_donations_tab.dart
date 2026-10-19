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
import '../../widgets/app_widgets.dart';
import 'shelter_common.dart';

int _meals(ServiceRequest r) => r.approvedPeople ?? r.people;

IconData kindIcon(RegistrationKind k) => switch (k) {
  RegistrationKind.restaurant => Icons.restaurant_rounded,
  RegistrationKind.company => Icons.business_rounded,
  RegistrationKind.shelter => Icons.home_work_rounded,
  RegistrationKind.individual => Icons.person_rounded,
};

/// One donor and everything they gave this shelter.
class _Donor {
  _Donor(this.id, this.donations);

  final String id;

  /// Accepted donations, newest first.
  final List<ServiceRequest> donations;

  ServiceRequest get last => donations.first;
  int get meals => donations.fold(0, (a, r) => a + _meals(r));
  DateTime get first =>
      donations.map((r) => r.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
}

List<_Donor> _donors(List<ServiceRequest> sentToShelter) {
  final by = <String, List<ServiceRequest>>{};
  for (final r in sentToShelter) {
    if (r.type == RequestType.donation && r.status == ReviewStatus.approved) {
      by.putIfAbsent(r.requesterId, () => []).add(r);
    }
  }
  final out = [
    for (final e in by.entries)
      _Donor(
        e.key,
        e.value..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
  ]..sort((a, b) => b.last.createdAt.compareTo(a.last.createdAt));
  return out;
}

/// Shelter "Donations" tab: only people / businesses that actually donated.
class ShelterDonationsTab extends StatefulWidget {
  const ShelterDonationsTab({super.key, required this.shelterId});

  final String shelterId;

  @override
  State<ShelterDonationsTab> createState() => _ShelterDonationsTabState();
}

class _ShelterDonationsTabState extends State<ShelterDonationsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final reqs = context.watch<RequestProvider>().sentTo(widget.shelterId);
    final regs = context.watch<RegistrationProvider>();
    final donors = _donors(reqs);

    if (donors.isEmpty) {
      return const EmptyState(
        icon: Icons.volunteer_activism_outlined,
        title: 'No donations yet',
        message:
            'Restaurants and companies that donate to your shelter will appear here once you accept their offer.',
      );
    }

    final now = DateTime.now();
    final all = donors.expand((d) => d.donations).toList();
    final monthMeals = all
        .where(
          (r) => r.createdAt.year == now.year && r.createdAt.month == now.month,
        )
        .fold<int>(0, (a, r) => a + _meals(r));
    final totalMeals = donors.fold<int>(0, (a, d) => a + d.meals);
    final q = _query.trim().toLowerCase();
    final shown = donors.where((d) {
      if (q.isEmpty) return true;
      final reg = regs.byId(d.id);
      final name = (reg?.displayName ?? d.last.requesterName).toLowerCase();
      return name.contains(q) || (reg?.phone ?? d.last.phone).contains(q);
    }).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenUtils.maxContentWidth,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
          children: [
            StatGrid(
              children: [
                StatTile(
                  icon: Icons.handshake_rounded,
                  value: '${donors.length}',
                  label: 'Donors',
                  color: AppColors.primary,
                ),
                StatTile(
                  icon: Icons.restaurant_rounded,
                  value: '$totalMeals',
                  label: 'Meals donated',
                  color: AppColors.approved,
                ),
                StatTile(
                  icon: Icons.calendar_month_rounded,
                  value: '$monthMeals',
                  label: 'Meals this month',
                  color: AppColors.accent,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search donors',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            SizedBox(height: 12.h),
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 30.h),
                child: const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No match',
                ),
              )
            else
              for (final d in shown) ...[
                _DonorCard(
                  donor: d,
                  reg: regs.byId(d.id),
                  shelterId: widget.shelterId,
                ),
                SizedBox(height: 10.h),
              ],
          ],
        ),
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  const _DonorCard({
    required this.donor,
    required this.reg,
    required this.shelterId,
  });

  final _Donor donor;
  final Registration? reg;
  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final name = reg?.displayName ?? donor.last.requesterName;
    final kind = reg?.kind;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            AppRouter.push(context, AppRoutes.donor, '${donor.id}|$shelterId'),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PersonAvatar(
                    name: name,
                    imageUrl: reg?.imageUrl,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          [
                            kind?.label ?? 'Donor',
                            if (reg != null && reg!.city.isNotEmpty) reg!.city,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.neutral,
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 6.h,
                children: [
                  Pill(
                    '${donor.meals} meals',
                    AppColors.approved,
                    icon: Icons.restaurant_rounded,
                  ),
                  Pill(
                    '${donor.donations.length} donation${donor.donations.length == 1 ? '' : 's'}',
                    AppColors.primary,
                    icon: Icons.volunteer_activism_rounded,
                  ),
                  Pill(
                    'Last: ${fmtFullDate(donor.last.createdAt)}',
                    AppColors.neutral,
                    icon: Icons.event_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything about one donor: contact, business and every donation.
class DonorDetailScreen extends StatelessWidget {
  const DonorDetailScreen({
    super.key,
    required this.donorId,
    required this.shelterId,
  });

  final String donorId;
  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final reg = context.watch<RegistrationProvider>().byId(donorId);
    final sent = context.watch<RequestProvider>().sentTo(shelterId);
    final donor = _donors(sent).where((d) => d.id == donorId).firstOrNull;
    if (donor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donor')),
        body: const EmptyState(
          icon: Icons.volunteer_activism_outlined,
          title: 'Donor not found',
        ),
      );
    }
    final name = reg?.displayName ?? donor.last.requesterName;
    String or(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

    return Scaffold(
      appBar: AppBar(title: const Text('Donor')),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
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
                        imageUrl: reg?.imageUrl,
                        radius: 34,
                        color: AppColors.accent,
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
                          Text(
                            reg?.kind.label ?? 'Donor',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14.sp,
                            ),
                          ),
                          Text(
                            'Donating since ${fmtFullDate(donor.first)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12.5.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              StatGrid(
                children: [
                  StatTile(
                    value: '${donor.donations.length}',
                    label: 'Donations',
                    color: AppColors.primary,
                  ),
                  StatTile(
                    value: '${donor.meals}',
                    label: 'Meals given',
                    color: AppColors.approved,
                  ),
                  StatTile(
                    value:
                        '${donor.donations.where((r) => r.fulfilledAt != null).length}',
                    label: 'Delivered',
                    color: AppColors.accent,
                  ),
                ],
              ),
              const SectionTitle('Contact'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      InfoRow(
                        Icons.person_outline_rounded,
                        'Contact person',
                        or(reg?.name ?? donor.last.requesterName),
                      ),
                      InfoRow(
                        Icons.phone_outlined,
                        'Phone',
                        or(reg?.phone ?? donor.last.phone),
                      ),
                      InfoRow(Icons.email_outlined, 'Email', or(reg?.email)),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Business details'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: reg == null
                      ? Text(
                          'This donor\'s business profile is no longer available.',
                          style: TextStyle(
                            color: AppColors.neutral,
                            fontSize: 13.sp,
                          ),
                        )
                      : Column(
                          children: [
                            InfoRow(
                              kindIcon(reg.kind),
                              'Business',
                              reg.displayName,
                            ),
                            InfoRow(
                              Icons.category_outlined,
                              'Type',
                              reg.kind.label,
                            ),
                            InfoRow(
                              Icons.location_city_rounded,
                              'City',
                              or(reg.city),
                            ),
                            InfoRow(
                              Icons.place_outlined,
                              'Address',
                              or(reg.address),
                            ),
                            InfoRow(
                              Icons.schedule_rounded,
                              'Open hours',
                              or(reg.hours),
                            ),
                            InfoRow(
                              Icons.restaurant_menu_rounded,
                              'Offers',
                              reg.services.isEmpty
                                  ? '—'
                                  : reg.services.join(', '),
                            ),
                            InfoRow(
                              Icons.verified_rounded,
                              'Verified on',
                              fmtFullDate(reg.reviewedAt ?? reg.createdAt),
                            ),
                            if (reg.notes.isNotEmpty)
                              InfoRow(
                                Icons.info_outline_rounded,
                                'About',
                                reg.notes,
                              ),
                          ],
                        ),
                ),
              ),
              SectionTitle('Donation history · ${donor.donations.length}'),
              for (final r in donor.donations) ...[
                _DonationTile(request: r),
                SizedBox(height: 10.h),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationTile extends StatelessWidget {
  const _DonationTile({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final delivered = r.fulfilledAt != null;
    final when = r.arrivalAt ?? r.neededDate;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRouter.push(context, AppRoutes.request, r.id),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_meals(r)} ${r.meal?.label.toLowerCase() ?? 'meal'}'
                      '${_meals(r) == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Pill(
                    delivered ? 'Delivered' : 'Accepted',
                    delivered ? AppColors.approved : AppColors.pending,
                    icon: delivered
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              _line(
                Icons.event_note_rounded,
                'Offered ${fmtDateTime(r.createdAt)}',
              ),
              if (when != null)
                _line(
                  Icons.local_shipping_outlined,
                  'Delivery ${r.arrivalAt != null ? fmtDateTime(when) : fmtDate(when)}',
                ),
              if (delivered)
                _line(
                  Icons.task_alt_rounded,
                  'Received ${fmtDateTime(r.fulfilledAt!)}',
                ),
              if ((r.contactPerson ?? '').isNotEmpty)
                _line(
                  Icons.support_agent_rounded,
                  'Handled by ${r.contactPerson}',
                ),
              if (r.message.isNotEmpty)
                _line(Icons.sticky_note_2_outlined, r.message),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData i, String t) => Padding(
    padding: EdgeInsets.symmetric(vertical: 2.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, size: 15.sp, color: AppColors.neutral),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            t,
            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
