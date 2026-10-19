import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/admin_header.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/registration_profile_dialog.dart';
import '../../widgets/request_widgets.dart';
import '../home/home_shell.dart' show ShellScaffoldState;
import 'admin_settings_tab.dart';

class AdminRegistrationsTab extends StatefulWidget {
  const AdminRegistrationsTab({super.key});

  @override
  State<AdminRegistrationsTab> createState() => _AdminRegistrationsTabState();
}

class _AdminRegistrationsTabState extends State<AdminRegistrationsTab> {
  ReviewStatus? _filter = ReviewStatus.pending;

  @override
  Widget build(BuildContext context) {
    final regs = context.watch<RegistrationProvider>();
    // Seeded demo shelters are pre-approved and never need review.
    final items = regs.all
        .where(
          (r) =>
              r.ownerId != 'seed' && (_filter == null || r.status == _filter),
        )
        .toList();

    return Column(
      children: [
        _RequestsHeader(
          all: regs.all.where((r) => r.ownerId != 'seed').toList(),
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing to review',
                  message:
                      'New individual and partner registrations appear here.',
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ScreenUtils.maxContentWidth,
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12.h),
                      itemBuilder: (_, i) => _RegistrationCard(items[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _RequestsHeader extends StatelessWidget {
  const _RequestsHeader({
    required this.all,
    required this.selected,
    required this.onChanged,
  });

  final List<Registration> all;
  final ReviewStatus? selected;
  final ValueChanged<ReviewStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    int count(ReviewStatus? s) =>
        s == null ? all.length : all.where((r) => r.status == s).length;
    final pending = count(ReviewStatus.pending);
    final options = <(ReviewStatus?, String, IconData, Color)>[
      (
        ReviewStatus.pending,
        'Pending',
        Icons.hourglass_top_rounded,
        AppColors.pending,
      ),
      (
        ReviewStatus.approved,
        'Approved',
        Icons.check_circle_rounded,
        AppColors.approved,
      ),
      (
        ReviewStatus.rejected,
        'Rejected',
        Icons.cancel_rounded,
        AppColors.rejected,
      ),
      (null, 'All', Icons.layers_rounded, AppColors.primary),
    ];
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF134E4A)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.how_to_reg_rounded,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registration requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      pending == 0
                          ? 'All caught up'
                          : '$pending waiting for your review',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) SizedBox(width: 6.w),
                Expanded(
                  child: _FilterPill(
                    label: options[i].$2,
                    icon: options[i].$3,
                    count: count(options[i].$1),
                    selected: selected == options[i].$1,
                    color: options[i].$4,
                    onTap: () => onChanged(options[i].$1),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? color : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: fg,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.h),
            FittedBox(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard(this.r);

  final Registration r;

  Widget _detail(IconData icon, String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(7.r),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16.sp, color: AppColors.primary),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5.sp,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => showRegistrationProfile(context, r),
            child: Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                ),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46.r,
                    height: 46.r,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF14B8A6), AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      switch (r.kind) {
                        RegistrationKind.individual => Icons.person_rounded,
                        RegistrationKind.shelter => Icons.home_work_rounded,
                        RegistrationKind.restaurant => Icons.restaurant_rounded,
                        RegistrationKind.company => Icons.business_rounded,
                      },
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.displayName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          r.isPartner
                              ? '${r.kind.label} partner'
                              : 'Needs help · ${r.familyMembers} ${r.familyMembers == 1 ? 'person' : 'people'}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  StatusChip(r.status),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.r, 8.r, 14.r, 6.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail(Icons.person_outline_rounded, 'Contact', r.name),
                _detail(Icons.phone_outlined, 'Phone', r.phone),
                _detail(
                  Icons.place_outlined,
                  'Location',
                  '${r.city} · ${r.address}',
                ),
                if (r.needs.isNotEmpty)
                  _detail(
                    Icons.volunteer_activism_outlined,
                    'Needs',
                    r.needs.join(', '),
                  ),
                if (r.kind == RegistrationKind.shelter)
                  _detail(Icons.bed_outlined, 'Beds', '${r.totalBeds}'),
                if (r.notes.isNotEmpty)
                  _detail(Icons.notes_rounded, 'Notes', r.notes),
                _detail(
                  Icons.schedule_rounded,
                  'Submitted',
                  timeAgo(r.createdAt),
                ),
                if (r.status == ReviewStatus.rejected)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 6.h, bottom: 8.h),
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: AppColors.rejected.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rejected: ${r.rejectReason}',
                      style: TextStyle(
                        color: AppColors.rejected,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (r.status == ReviewStatus.pending)
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rejected,
                        side: BorderSide(
                          color: AppColors.rejected.withValues(alpha: 0.5),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: () => _reject(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: () async {
                        await context.read<RegistrationProvider>().approve(
                          r.id,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${r.displayName} approved and notified.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject ${r.displayName}',
      quickReasons: const [
        'Incomplete or unclear details',
        'Phone number could not be verified',
        'Outside our service area',
      ],
    );
    if (reason == null || !context.mounted) return;
    await context.read<RegistrationProvider>().reject(r.id, reason);
  }
}

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  /// 0 All, 1 Shelters, 2 Users.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final regs = context.watch<RegistrationProvider>();
    final reqs = context.watch<RequestProvider>();
    final recent = reqs.all.take(10).toList();
    final pendingRegs = regs.byStatus(ReviewStatus.pending).length;
    final shelters = regs.approvedPartners;
    final users = regs.all
        .where(
          (r) => r.kind == RegistrationKind.individual && r.ownerId != 'seed',
        )
        .toList();

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminHeader(
            margin: EdgeInsets.only(bottom: 12.h),
            icon: Icons.dashboard_rounded,
            title: 'Overview',
            subtitle: pendingRegs == 0
                ? 'Everything is up to date'
                : '$pendingRegs registrations need review',
            tiles: [
              HeaderTile('All', shelters.length + users.length),
              HeaderTile('Shelters', shelters.length),
              HeaderTile('Users', users.length),
            ],
            selected: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
          if (_tab == 1) ...[
            const SectionTitle('Registered shelters'),
            AdminRegList(items: shelters, shelters: true),
          ] else if (_tab == 2) ...[
            const SectionTitle('Registered users'),
            AdminRegList(items: users, shelters: false),
          ] else ...[
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                mainAxisExtent: 132.r,
              ),
              children: [
                _Stat(
                  'Pending reviews',
                  '$pendingRegs',
                  Icons.hourglass_top_rounded,
                  AppColors.pending,
                  onTap: () => context
                      .findAncestorStateOfType<ShellScaffoldState>()
                      ?.goTo(1),
                ),
                _Stat(
                  'Approved sign-ups',
                  '${regs.byStatus(ReviewStatus.approved).length}',
                  Icons.verified_rounded,
                  AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminUsersScreen(),
                    ),
                  ),
                ),
                _Stat(
                  'Requests pending',
                  '${reqs.countWhere(ReviewStatus.pending)}',
                  Icons.inbox_rounded,
                  AppColors.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const _RequestsByStatus(ReviewStatus.pending),
                    ),
                  ),
                ),
                _Stat(
                  'Requests approved',
                  '${reqs.countWhere(ReviewStatus.approved)}',
                  Icons.check_circle_rounded,
                  AppColors.approved,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const _RequestsByStatus(ReviewStatus.approved),
                    ),
                  ),
                ),
              ],
            ),
            const SectionTitle('Recent shelter requests'),
            if (recent.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: const Center(child: Text('No requests yet')),
              )
            else
              for (final r in recent)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: RequestCard(request: r, showTarget: true),
                ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, this.color, {this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.16), Colors.white],
        ),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -14,
                child: Icon(
                  icon,
                  size: 84.sp,
                  color: color.withValues(alpha: 0.07),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(14.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(9.r),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(icon, color: Colors.white, size: 20.sp),
                        ),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 18.sp,
                          color: color,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
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

/// Shelter requests filtered by one review status.
class _RequestsByStatus extends StatelessWidget {
  const _RequestsByStatus(this.status);

  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final items = context
        .watch<RequestProvider>()
        .all
        .where((r) => r.status == status)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('${status.label} requests (${items.length})')),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No ${status.label.toLowerCase()} requests',
              message: 'Requests will appear here.',
            )
          : PageBody(
              child: Column(
                children: [
                  for (final r in items)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: RequestCard(request: r, showTarget: true),
                    ),
                ],
              ),
            ),
    );
  }
}
