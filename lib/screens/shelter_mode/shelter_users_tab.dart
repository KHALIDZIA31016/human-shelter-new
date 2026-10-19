import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/registration.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/app_widgets.dart';
import 'shelter_common.dart';

/// Shelter "Users" tab: everyone registered with this shelter.
class ShelterUsersTab extends StatefulWidget {
  const ShelterUsersTab({super.key, required this.shelterId});

  final String shelterId;

  @override
  State<ShelterUsersTab> createState() => _ShelterUsersTabState();
}

class _ShelterUsersTabState extends State<ShelterUsersTab> {
  ResidentState? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final reqs = context.watch<RequestProvider>();
    final regs = context.watch<RegistrationProvider>();
    final roster = residentsRoster(reqs.sentTo(widget.shelterId));

    if (roster.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'No registered users yet',
        message:
            'People whose stay you approve are registered with your shelter and appear here.',
      );
    }

    int count(ResidentState s) => roster.where((r) => r.state == s).length;
    final q = _query.trim().toLowerCase();
    final shown = roster.where((r) {
      if (_filter != null && r.state != _filter) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) || r.phone.contains(q);
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
              perRow: 4,
              children: [
                StatTile(
                  value: '${roster.length}',
                  label: 'Registered',
                  color: AppColors.primary,
                ),
                StatTile(
                  value: '${count(ResidentState.current)}',
                  label: 'Staying',
                  color: AppColors.approved,
                ),
                StatTile(
                  value: '${count(ResidentState.arriving)}',
                  label: 'Arriving',
                  color: AppColors.accent,
                ),
                StatTile(
                  value: '${count(ResidentState.former)}',
                  label: 'Left',
                  color: AppColors.neutral,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            SizedBox(height: 8.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final o in <ResidentState?>[
                    null,
                    ...ResidentState.values,
                  ])
                    Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: ChoiceChip(
                        label: Text(o?.label ?? 'All'),
                        selected: _filter == o,
                        onSelected: (_) => setState(() => _filter = o),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: const EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No match',
                  message: 'Try a different name or filter.',
                ),
              )
            else
              for (final r in shown) ...[
                _ResidentCard(
                  resident: r,
                  profile: regs.individualOf(r.userId),
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

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({
    required this.resident,
    required this.profile,
    required this.shelterId,
  });

  final Resident resident;
  final Registration? profile;
  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final r = resident;
    final bed = r.latest.bedLabel;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRouter.push(
          context,
          AppRoutes.shelterUser,
          '${r.userId}|$shelterId',
        ),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Row(
            children: [
              PersonAvatar(
                name: r.name,
                imageUrl: profile?.imageUrl,
                color: r.state.color,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      [
                        r.people == 1 ? 'Alone' : 'With family · ${r.people}',
                        if (bed != null && bed.isNotEmpty) 'Bed $bed',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      r.until != null
                          ? '${fmtFullDate(r.since)} → ${fmtFullDate(r.until!)}'
                          : 'Since ${fmtFullDate(r.since)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Pill(r.state.label, r.state.color),
                  SizedBox(height: 6.h),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.neutral,
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
