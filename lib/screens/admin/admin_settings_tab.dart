import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../providers/notification_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../widgets/admin_header.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/suspension_widgets.dart';
import '../../widgets/image_picker_field.dart';
import '../../widgets/registration_profile_dialog.dart';
import '../../widgets/request_widgets.dart';
import '../shelter_mode/shelter_common.dart';
import '../shelters/transfer_screens.dart';

/// Admin "Settings" tab: everything beyond the four main tabs.
class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  void _page(
    BuildContext context,
    String title,
    Widget body, {
    String? subtitle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: subtitle == null
                ? Text(title)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
          body: body,
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will return to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseAuth.instance.signOut();
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<SessionProvider>().recipientIds;
    final unread = context.watch<NotificationProvider>().unreadCount(ids);
    final regs = context.watch<RegistrationProvider>();
    final reqs = context.watch<RequestProvider>();
    final moves = context
        .watch<TransferProvider>()
        .all
        .where((t) => t.status.isOpen)
        .length;
    final shelters = regs.approvedPartners;
    final partnerAccounts = regs.all.where((r) => r.isPartner).toList();
    final users = regs.all
        .where((r) => r.kind == RegistrationKind.individual)
        .toList();

    return PageBody(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminHeader(
            margin: EdgeInsets.only(top: 8.h, bottom: 12.h),
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Alerts, moves, shelters and more',
          ),
          _Tile(
            icon: Icons.notifications_rounded,
            color: AppColors.pending,
            title: 'Alerts',
            subtitle: unread == 0 ? 'No new alerts' : '$unread unread',
            count: unread,
            onTap: () => AppRouter.push(context, AppRoutes.alerts),
          ),
          _Tile(
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF7C3AED),
            title: 'Shelter moves',
            subtitle: moves == 0
                ? 'No open moves'
                : '$moves waiting for review',
            count: moves,
            onTap: () =>
                _page(context, 'Shelter moves', const AdminTransfersTab()),
          ),
          _Tile(
            icon: Icons.home_work_rounded,
            color: AppColors.primary,
            title: 'Shelters',
            subtitle:
                '${shelters.length} approved · ${regs.freeBeds} free beds',
            onTap: () => _page(
              context,
              'Partner Shelters Directory',
              PageBody(child: _ShelterDirectory(items: shelters)),
              subtitle: '${shelters.length} approved · tap one for details',
            ),
          ),
          _Tile(
            icon: Icons.groups_rounded,
            color: const Color(0xFF0E7490),
            title: 'Users',
            subtitle:
                '${users.length} registered · '
                '${users.where((r) => r.status == ReviewStatus.pending).length} pending',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminUsersScreen()),
            ),
          ),
          _Tile(
            icon: Icons.inbox_rounded,
            color: AppColors.accent,
            title: 'Shelter requests',
            subtitle: '${reqs.all.length} in total',
            onTap: () => _page(
              context,
              'Shelter requests',
              reqs.all.isEmpty
                  ? const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No requests yet',
                      message: 'Requests sent to shelters appear here.',
                    )
                  : PageBody(
                      child: Column(
                        children: [
                          for (final r in reqs.all)
                            Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: RequestCard(request: r, showTarget: true),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          const SectionTitle('Manage accounts'),
          _Tile(
            icon: Icons.storefront_rounded,
            color: AppColors.accent,
            title: 'Partner accounts',
            count: partnerAccounts.where((r) => r.appealPending).length,
            subtitle: partnerAccounts.any((r) => r.appealPending)
                ? '${partnerAccounts.where((r) => r.appealPending).length} appeal(s) waiting'
                : '${partnerAccounts.length} accounts · shelters, companies, restaurants',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminPartnerAccountsScreen(),
              ),
            ),
          ),
          _Tile(
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF0E7490),
            title: 'User accounts',
            count: users.where((r) => r.appealPending).length,
            subtitle: users.any((r) => r.appealPending)
                ? '${users.where((r) => r.appealPending).length} appeal(s) waiting'
                : '${users.length} accounts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminUsersScreen()),
            ),
          ),
          const SectionTitle('Session'),
          _Tile(
            icon: Icons.logout_rounded,
            color: AppColors.rejected,
            title: 'Log out',
            subtitle: 'Sign out and return to login',
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

/// Cards for registrations; shelters open their detail screen.
class AdminRegList extends StatelessWidget {
  const AdminRegList({super.key, required this.items, required this.shelters});

  final List<Registration> items;
  final bool shelters;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: const Center(child: Text('Nothing here yet')),
      );
    }
    return Column(
      children: [
        for (final r in items)
          Card(
            child: ListTile(
              onTap: shelters
                  ? () => AppRouter.push(context, AppRoutes.shelter, r.id)
                  : () => showRegistrationProfile(context, r),
              leading: PersonAvatar(
                name: r.displayName,
                imageUrl: r.imageUrl,
                radius: 22,
              ),
              title: Text(
                r.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                shelters
                    ? '${r.city} · ${r.availableBeds}/${r.totalBeds} beds free'
                    : '${r.kind.label} · ${r.city}',
              ),
              trailing: shelters
                  ? const Icon(Icons.chevron_right_rounded)
                  : StatusChip(r.status),
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.count = 0,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0) Badge(label: Text('$count')),
              if (count > 0) SizedBox(width: 8.w),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Polished list of approved shelters: photo, location and bed occupancy.
class _ShelterDirectory extends StatelessWidget {
  const _ShelterDirectory({required this.items});

  final List<Registration> items;

  @override
  Widget build(BuildContext context) {
    final free = items.fold<int>(0, (a, r) => a + r.availableBeds);
    return Column(
      children: [
        AdminHeader(
          margin: EdgeInsets.only(top: 8.h, bottom: 12.h),
          icon: Icons.home_work_rounded,
          title: 'Safe homes network',
          subtitle: 'Approved shelters and their live capacity',
          tiles: [
            HeaderTile('Shelters', items.length),
            HeaderTile('Free beds', free),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: const Center(child: Text('No approved shelters yet')),
          )
        else
          for (final r in items) _ShelterCard(r: r),
      ],
    );
  }
}

class _ShelterCard extends StatelessWidget {
  const _ShelterCard({required this.r});

  final Registration r;

  @override
  Widget build(BuildContext context) {
    final total = r.totalBeds;
    final used = (total - r.availableBeds).clamp(0, total);
    final ratio = total == 0 ? 0.0 : used / total;
    final full = r.availableBeds == 0;
    final tone = full ? AppColors.rejected : AppColors.approved;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AppRouter.push(context, AppRoutes.shelter, r.id),
          child: Padding(
            padding: EdgeInsets.all(12.r),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72.w,
                    height: 72.w,
                    child: ShelterCover(shelter: r, height: 72.w),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.sp,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14.sp,
                            color: AppColors.neutral,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              r.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.neutral),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      if (r.kind == RegistrationKind.shelter) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6.h,
                            color: tone,
                            backgroundColor: tone.withValues(alpha: 0.15),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          full
                              ? 'Full · $total beds'
                              : '${r.availableBeds} of $total beds free',
                          style: TextStyle(
                            color: tone,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            r.kind.label,
                            style: TextStyle(
                              color: AppColors.pending,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// All people who registered for help: header filters, search and rich cards.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => AdminUsersScreenState();
}

class AdminUsersScreenState extends State<AdminUsersScreen> {
  int _section = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final regs = context.watch<RegistrationProvider>();
    final reqs = context.watch<RequestProvider>();
    final users = regs.all
        .where((r) => r.kind == RegistrationKind.individual)
        .toList();
    bool inShelter(Registration r) => reqs.chatStay(r.ownerId) != null;
    List<Registration> by(ReviewStatus s) =>
        users.where((r) => r.status == s).toList();
    final approved = by(ReviewStatus.approved);

    final sections = <(String, List<Registration>)>[
      ('Approved', approved),
      ('Rejected', by(ReviewStatus.rejected)),
      ('Pending', by(ReviewStatus.pending)),
      ('In shelter', approved.where(inShelter).toList()),
      ('No shelter', approved.where((r) => !inShelter(r)).toList()),
    ];
    final q = _query.trim().toLowerCase();
    final shown = sections[_section].$2
        .where(
          (r) =>
              q.isEmpty ||
              r.displayName.toLowerCase().contains(q) ||
              r.city.toLowerCase().contains(q) ||
              r.phone.contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Registered Users')),
      body: PageBody(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminHeader(
              margin: EdgeInsets.only(top: 8.h, bottom: 12.h),
              icon: Icons.groups_rounded,
              title: 'Community members',
              subtitle: '${users.length} people registered for help',
              tiles: [for (final t in sections) HeaderTile(t.$1, t.$2.length)],
              selected: _section,
              onSelected: (i) => setState(() => _section = i),
            ),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name, city or phone',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Text(
                  sections[_section].$1,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8.w),
                Badge(
                  label: Text('${shown.length}'),
                  backgroundColor: AppColors.primary,
                ),
              ],
            ),
            SizedBox(height: 10.h),
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32.h),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 44.sp,
                        color: AppColors.neutral,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        q.isEmpty
                            ? 'Nobody in "${sections[_section].$1}" yet'
                            : 'No matches for "$_query"',
                        style: const TextStyle(color: AppColors.neutral),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final r in shown) _UserCard(r: r, inShelter: inShelter(r)),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.r, required this.inShelter});

  final Registration r;
  final bool inShelter;

  Color get _tone => switch (r.status) {
    ReviewStatus.approved => AppColors.approved,
    ReviewStatus.rejected => AppColors.rejected,
    ReviewStatus.pending => AppColors.pending,
    ReviewStatus.cancelled => AppColors.neutral,
  };

  Widget _meta(IconData icon, String text) => Padding(
    padding: EdgeInsets.only(top: 3.h),
    child: Row(
      children: [
        Icon(icon, size: 14.sp, color: AppColors.neutral),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.neutral, fontSize: 12.5.sp),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fallback = PersonAvatar(name: r.displayName, radius: 36);
    final hasPhoto = r.imageUrl != null && r.imageUrl!.isNotEmpty;
    final shelterTone = inShelter ? AppColors.primary : AppColors.neutral;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => showRegistrationProfile(context, r),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5.w, color: _tone),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(12.r),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(2.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _tone, width: 2),
                          ),
                          child: ClipOval(
                            child: SizedBox(
                              width: 60.w,
                              height: 60.w,
                              child: hasPhoto
                                  ? appImage(r.imageUrl!, fallback: fallback)
                                  : fallback,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15.sp,
                                      ),
                                    ),
                                  ),
                                  if (r.isApproved)
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 17.sp,
                                      color: const Color(0xFF1D9BF0),
                                    ),
                                ],
                              ),
                              _meta(Icons.location_on_rounded, r.city),
                              _meta(Icons.call_rounded, r.phone),
                              _meta(
                                Icons.event_rounded,
                                'Joined ${fmtDate(r.createdAt)}',
                              ),
                              SizedBox(height: 8.h),
                              Wrap(
                                spacing: 6.w,
                                runSpacing: 4.h,
                                children: [
                                  StatusChip(r.status),
                                  SuspensionChips(account: r),
                                  if (r.isApproved && !r.suspended)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: shelterTone.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            inShelter
                                                ? Icons.home_rounded
                                                : Icons.home_outlined,
                                            size: 14.sp,
                                            color: shelterTone,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            inShelter
                                                ? 'In shelter'
                                                : 'No shelter',
                                            style: TextStyle(
                                              color: shelterTone,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AccountActionsMenu(account: r),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every partner account, split into Shelters, Companies and Restaurants.
class AdminPartnerAccountsScreen extends StatefulWidget {
  const AdminPartnerAccountsScreen({super.key});

  @override
  State<AdminPartnerAccountsScreen> createState() =>
      _AdminPartnerAccountsScreenState();
}

class _AdminPartnerAccountsScreenState
    extends State<AdminPartnerAccountsScreen> {
  int _section = 0;
  String _query = '';

  static const _kinds = [
    RegistrationKind.shelter,
    RegistrationKind.company,
    RegistrationKind.restaurant,
  ];

  @override
  Widget build(BuildContext context) {
    final all = context
        .watch<RegistrationProvider>()
        .all
        .where((r) => r.isPartner)
        .toList();
    List<Registration> of(RegistrationKind k) =>
        all.where((r) => r.kind == k).toList();
    final kind = _kinds[_section];
    final q = _query.trim().toLowerCase();
    final shown = of(kind)
        .where(
          (r) =>
              q.isEmpty ||
              r.displayName.toLowerCase().contains(q) ||
              r.city.toLowerCase().contains(q) ||
              r.phone.contains(q),
        )
        .toList();
    final plural = switch (kind) {
      RegistrationKind.shelter => 'Shelters',
      RegistrationKind.company => 'Companies',
      _ => 'Restaurants',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Partner Accounts')),
      body: PageBody(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminHeader(
              margin: EdgeInsets.only(top: 8.h, bottom: 12.h),
              icon: Icons.storefront_rounded,
              title: 'Partner network',
              subtitle: '${all.length} partner accounts in total',
              tiles: [
                HeaderTile('Shelters', of(RegistrationKind.shelter).length),
                HeaderTile('Companies', of(RegistrationKind.company).length),
                HeaderTile(
                  'Restaurants',
                  of(RegistrationKind.restaurant).length,
                ),
              ],
              selected: _section,
              onSelected: (i) => setState(() => _section = i),
            ),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name, city or phone',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Text(
                  plural,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8.w),
                Badge(
                  label: Text('${shown.length}'),
                  backgroundColor: AppColors.primary,
                ),
              ],
            ),
            SizedBox(height: 10.h),
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32.h),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.store_mall_directory_outlined,
                        size: 44.sp,
                        color: AppColors.neutral,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        q.isEmpty
                            ? 'No ${plural.toLowerCase()} yet'
                            : 'No matches for "$_query"',
                        style: const TextStyle(color: AppColors.neutral),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final r in shown) _PartnerAccountCard(r: r),
          ],
        ),
      ),
    );
  }
}

class _PartnerAccountCard extends StatelessWidget {
  const _PartnerAccountCard({required this.r});

  final Registration r;

  Color get _tone => switch (r.status) {
    ReviewStatus.approved => AppColors.approved,
    ReviewStatus.rejected => AppColors.rejected,
    ReviewStatus.pending => AppColors.pending,
    ReviewStatus.cancelled => AppColors.neutral,
  };

  Widget _meta(IconData icon, String text) => Padding(
    padding: EdgeInsets.only(top: 3.h),
    child: Row(
      children: [
        Icon(icon, size: 14.sp, color: AppColors.neutral),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.neutral, fontSize: 12.5.sp),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final icon = switch (r.kind) {
      RegistrationKind.shelter => Icons.home_work_rounded,
      RegistrationKind.restaurant => Icons.restaurant_rounded,
      _ => Icons.apartment_rounded,
    };
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.6)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 28.sp),
    );
    final hasPhoto = r.imageUrl != null && r.imageUrl!.isNotEmpty;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: r.kind == RegistrationKind.shelter && r.isApproved
              ? () => AppRouter.push(context, AppRoutes.shelter, r.id)
              : () => showRegistrationProfile(context, r),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5.w, color: _tone),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(12.r),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 68.w,
                            height: 68.w,
                            child: hasPhoto
                                ? appImage(r.imageUrl!, fallback: fallback)
                                : fallback,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.sp,
                                ),
                              ),
                              _meta(Icons.location_on_rounded, r.city),
                              _meta(Icons.call_rounded, r.phone),
                              _meta(
                                Icons.event_rounded,
                                'Joined ${fmtDate(r.createdAt)}',
                              ),
                              SizedBox(height: 8.h),
                              Wrap(
                                spacing: 6.w,
                                runSpacing: 4.h,
                                children: [
                                  StatusChip(r.status),
                                  SuspensionChips(account: r),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AccountActionsMenu(account: r),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
