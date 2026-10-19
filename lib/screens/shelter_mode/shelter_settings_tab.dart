import 'package:flutter/material.dart';

import '../profile/profile_screen.dart' show confirmLogout;
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../data/models/staff_member.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/profile_change_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/approval_report.dart';
import '../partner/partner_tabs.dart';
import '../shelters/transfer_screens.dart';
import 'shelter_common.dart';

/// Shelter "Settings" tab: shelter name, profile, cases, requests, then the
/// rest of what a shelter manages.
class ShelterSettingsTab extends StatelessWidget {
  const ShelterSettingsTab({super.key, required this.shelter});

  final Registration shelter;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RegistrationProvider>().byId(shelter.id) ?? shelter;
    final pending = context
        .watch<RequestProvider>()
        .sentTo(s.id)
        .where((r) => r.isPending)
        .length;
    final transfers = context
        .watch<TransferProvider>()
        .forShelter(s.id)
        .where((t) => t.status.isOpen)
        .length;
    final verifications = context
        .watch<ComplaintProvider>()
        .forShelter(s.id)
        .where((c) => !c.status.isClosed)
        .length;
    final cases = transfers + verifications;
    final staff = context.watch<StaffProvider>();
    final profileChanges = context.watch<ProfileChangeProvider>().pendingCount(
      s.id,
    );
    final reports = approvalReports(
      context.watch<RequestProvider>().sentTo(s.id),
    ).length;

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Shelter name
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, Color(0xFF134E4A)],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_work_rounded, color: Colors.white),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        s.city,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          // 2. Profile
          _Tile(
            icon: Icons.storefront_rounded,
            color: AppColors.primary,
            title: 'Shelter profile',
            subtitle: 'Photo, residents, daily serving and staff',
            leading: PersonAvatar(
              name: s.displayName,
              imageUrl: s.imageUrl,
              radius: 22,
            ),
            onTap: () =>
                AppRouter.push(context, AppRoutes.shelterProfile, s.id),
          ),
          // 3. Cases
          _Tile(
            icon: Icons.fact_check_rounded,
            color: const Color(0xFF7C3AED),
            title: 'Cases',
            subtitle: cases == 0
                ? 'No open cases'
                : '$cases open · shelter changes & admin checks',
            count: cases,
            onTap: () => AppRouter.push(context, AppRoutes.shelterCases, s.id),
          ),
          // 4. Requests
          _Tile(
            icon: Icons.inbox_rounded,
            color: AppColors.accent,
            title: 'Requests',
            subtitle: pending == 0
                ? 'No pending requests'
                : '$pending waiting for your decision',
            count: pending,
            onTap: () =>
                AppRouter.push(context, AppRoutes.shelterRequests, s.id),
          ),
          // 5. Everything else
          const SectionTitle('Manage'),
          _Tile(
            icon: Icons.edit_note_rounded,
            color: AppColors.accent,
            title: 'Profile changes',
            subtitle: profileChanges == 0
                ? 'Residents asking to edit their details'
                : '$profileChanges waiting for your decision',
            count: profileChanges,
            onTap: () =>
                AppRouter.push(context, AppRoutes.profileChanges, s.id),
          ),
          _Tile(
            icon: Icons.verified_rounded,
            color: AppColors.primary,
            title: 'Approval reports',
            subtitle: reports == 0
                ? 'Official reports of approved stays'
                : '$reports saved · official reports of approved stays',
            onTap: () =>
                AppRouter.push(context, AppRoutes.approvalReports, s.id),
          ),
          _Tile(
            icon: Icons.bed_rounded,
            color: AppColors.approved,
            title: 'Bed management',
            subtitle:
                '${s.totalBeds - s.availableBeds}/${s.totalBeds} beds occupied',
            onTap: () => AppRouter.push(context, AppRoutes.beds, s.id),
          ),
          _Tile(
            icon: Icons.badge_rounded,
            color: AppColors.primary,
            title: 'Staff',
            subtitle:
                '${staff.inState(s.id, StaffState.current).length} working · '
                '${staff.inState(s.id, StaffState.upcoming).length} joining soon',
            onTap: () => AppRouter.push(context, AppRoutes.staff, s.id),
          ),
          _Tile(
            icon: Icons.edit_rounded,
            color: const Color(0xFF0E7490),
            title: 'Edit public profile',
            subtitle: 'Contact, address, hours and services users see',
            onTap: () => AppRouter.push(context, AppRoutes.profileEdit, s.id),
          ),
          const SectionTitle('App'),
          _Tile(
            icon: Icons.help_outline_rounded,
            color: AppColors.neutral,
            title: 'Help & guide',
            subtitle: 'How each tab works',
            onTap: () => _showHelp(context),
          ),
          _Tile(
            icon: Icons.info_outline_rounded,
            color: AppColors.neutral,
            title: 'About Shelter Connect',
            subtitle: 'Version 1.0.0',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Shelter Connect',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(
                Icons.home_work_rounded,
                color: AppColors.primary,
                size: 36,
              ),
              children: const [
                Text(
                  'Connecting people in need with shelters, restaurants and companies.',
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),
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

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How your shelter app works'),
        content: const SingleChildScrollView(
          child: Text(
            'Users: everyone registered at your shelter, with full profiles.\n\n'
            'Chat: messages from your residents.\n\n'
            'Settings: profile, cases, requests, beds and staff.\n\n'
            'Alerts: updates from users, admin and other shelters. Tap one to read it in full.\n\n'
            'Donations: restaurants and companies that donated to you.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
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
    this.leading,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int count;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading:
              leading ??
              CircleAvatar(
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

/// Settings -> Cases.
class ShelterCasesScreen extends StatelessWidget {
  const ShelterCasesScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cases')),
    body: SafeArea(child: ShelterCasesTab(shelterId: shelterId)),
  );
}

/// Settings -> Requests.
class ShelterRequestsScreen extends StatelessWidget {
  const ShelterRequestsScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RegistrationProvider>().byId(shelterId);
    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: SafeArea(
        child: p == null
            ? const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Shelter not found',
              )
            : PartnerRequestsTab(partner: p),
      ),
    );
  }
}
