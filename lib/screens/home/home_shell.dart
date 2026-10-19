import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/registration.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/session_provider.dart';
import '../admin/admin_tabs.dart';
import '../chat/chat_screen.dart';
import '../admin/admin_settings_tab.dart';
import 'approval_gate_screen.dart';
import '../complaints/complaint_tabs.dart';
import '../shelter_mode/shelter_alerts_tab.dart';
import '../shelter_mode/shelter_common.dart';
import '../shelter_mode/shelter_donations_tab.dart';
import '../shelter_mode/shelter_settings_tab.dart';
import '../shelter_mode/shelter_users_tab.dart';
import '../profile/profile_screen.dart';
import 'needy_tabs.dart';

/// Chooses the dashboard for the active persona.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final regs = context.watch<RegistrationProvider>();

    switch (session.persona) {
      case Persona.admin:
        return ShellScaffold(
          title: 'Admin Control Center',
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Admin Control Center',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'Manage shelters, partners & care requests',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).appBarTheme.foregroundColor?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          showSwitchView: false,
          tabs: [
            ShellTab(
              'Overview',
              Icons.insights_rounded,
              const AdminOverviewTab(),
            ),
            ShellTab(
              'Requests',
              Icons.how_to_reg_rounded,
              const AdminRegistrationsTab(),
            ),
            ShellTab(
              'Complaints',
              Icons.report_gmailerrorred_rounded,
              const AdminComplaintsTab(),
            ),
            ShellTab(
              'Settings',
              Icons.settings_rounded,
              const AdminSettingsTab(),
            ),
          ],
        );
      case Persona.partner:
        final partner = regs.byId(session.activePartnerId);
        if (partner != null && partner.isApproved) {
          // Shelters, restaurants and companies all share the shelter UI.
          return ShellScaffold(
            title: partner.displayName,
            showSwitchView: false,
            tabs: [
              ShellTab(
                'Users',
                Icons.groups_rounded,
                ShelterUsersTab(shelterId: partner.id),
              ),
              ShellTab(
                'Donations',
                Icons.volunteer_activism_rounded,
                ShelterDonationsTab(shelterId: partner.id),
              ),
              ShellTab(
                'Chat',
                Icons.message_rounded,
                ShelterChatsTab(shelterId: partner.id),
                shelterChatId: partner.id,
                center: true,
              ),
              ShellTab(
                'Alerts',
                Icons.notifications_rounded,
                const ShelterAlertsTab(),
                isAlerts: true,
              ),
              ShellTab(
                'Settings',
                Icons.settings_rounded,
                ShelterSettingsTab(shelter: partner),
              ),
            ],
          );
        }
        // Partner no longer valid: fall back to the needy view.
        WidgetsBinding.instance.addPostFrameCallback((_) => session.useNeedy());
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case Persona.needy:
        if (regs.individualOf(session.deviceId) == null &&
            session.activeUser.needsRegistration) {
          // Never registered: go straight to the form (back = login).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.register, (_) => false);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (isBlockedUser(session, regs)) return const ApprovalGateScreen();
        final me = regs.individualOf(session.deviceId);
        return ShellScaffold(
          title: me?.name ?? 'Shelter Connect',
          titleWidget: me == null ? null : _UserTitle(me),
          alertsInAppBar: true,
          showSwitchView: false,
          centerChat: true,
          tabs: [
            ShellTab('Home', Icons.home_rounded, const NeedyHomeTab()),
            ShellTab('Shelters', Icons.home_work_rounded, const SheltersTab()),
            ShellTab(
              'Requests',
              Icons.receipt_long_rounded,
              const MyRequestsTab(),
            ),
            ShellTab('Settings', Icons.settings_rounded, const ProfileTab()),
          ],
        );
    }
  }
}

class ShellTab {
  const ShellTab(
    this.label,
    this.icon,
    this.body, {
    this.isAlerts = false,
    this.shelterChatId,
    this.center = false,
  });

  final String label;
  final IconData icon;
  final Widget body;
  final bool isAlerts;

  /// Set on a shelter's chat tab: its unread-message count shows as a badge.
  final String? shelterChatId;

  /// Drawn as the colourful docked button in the middle of the bar.
  final bool center;
}

class ShellScaffold extends StatefulWidget {
  const ShellScaffold({
    super.key,
    required this.title,
    required this.tabs,
    this.titleWidget,
    this.alertsInAppBar = false,
    this.centerChat = false,
    this.showSwitchView = true,
  });

  final String title;

  /// Replaces the plain [title] text in the app bar when set.
  final Widget? titleWidget;
  final List<ShellTab> tabs;

  /// Show the alerts bell in the top-right instead of a bottom tab.
  final bool alertsInAppBar;

  /// Colourful label-less chat button in the middle of the bottom bar.
  final bool centerChat;

  /// Show the demo "switch view" button in the top-right.
  final bool showSwitchView;

  @override
  State<ShellScaffold> createState() => ShellScaffoldState();
}

class ShellScaffoldState extends State<ShellScaffold> {
  int _index = 0;

  /// Lets a tab body jump to another tab (e.g. Home -> Shelters).
  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<SessionProvider>().recipientIds;
    final unread = context.watch<NotificationProvider>().unreadCount(ids);
    final chat = context.watch<ChatProvider>();
    final index = _index.clamp(0, widget.tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title:
            widget.titleWidget ??
            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.alertsInAppBar && widget.tabs[index].label != 'Settings')
            IconButton(
              tooltip: 'Alerts',
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_rounded),
              ),
              onPressed: () => AppRouter.push(context, AppRoutes.alerts),
            ),
          if (widget.showSwitchView)
            IconButton(
              tooltip: 'Switch view (demo)',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => AppRouter.push(context, AppRoutes.modes),
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: [for (final t in widget.tabs) t.body],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.centerChat && index >= _mid ? index + 1 : index,
        onDestinationSelected: (d) {
          if (widget.centerChat && d == _mid) {
            _openChat();
          } else {
            setState(() => _index = widget.centerChat && d > _mid ? d - 1 : d);
          }
        },
        destinations: [
          for (var i = 0; i < widget.tabs.length; i++) ...[
            if (widget.centerChat && i == _mid) _chatDestination(),
            NavigationDestination(
              label: widget.tabs[i].label,
              tooltip: widget.tabs[i].label,
              icon: _icon(widget.tabs[i], unread, false, chat),
              selectedIcon: _icon(widget.tabs[i], unread, true, chat),
            ),
          ],
        ],
      ),
    );
  }

  /// Position of the chat button among the destinations.
  static const _mid = 2;

  NavigationDestination _chatDestination() {
    final session = context.watch<SessionProvider>();
    final unread = context.watch<ChatProvider>().unreadForUser(
      session.deviceId,
    );
    return NavigationDestination(
      label: 'Chat',
      tooltip: 'Chat with my shelter',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: _ChatOrb(icon: Icons.message_rounded),
      ),
    );
  }

  void _openChat() {
    final session = context.read<SessionProvider>();
    final stay = context.read<RequestProvider>().chatStay(session.deviceId);
    if (stay == null) {
      AppRouter.push(context, AppRoutes.chatRegister);
      return;
    }
    AppRouter.push(
      context,
      AppRoutes.chat,
      '${session.deviceId}|${stay.targetId}',
    );
  }

  Widget _icon(ShellTab t, int unread, bool selected, ChatProvider chat) {
    final icon = Icon(t.icon, color: selected ? AppColors.primary : null);
    final count = t.isAlerts
        ? unread
        : (t.shelterChatId == null
              ? 0
              : chat.unreadForShelter(t.shelterChatId!));
    if (t.center) {
      return Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: _ChatOrb(icon: t.icon, glow: selected),
      );
    }
    if (count == 0) return icon;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);
  }
}

/// Chat button of the bottom bar: a teal disc with a message icon (bubble
/// with text lines), the same height as the other bar icons so it lines up.
class _ChatOrb extends StatelessWidget {
  const _ChatOrb({required this.icon, this.glow = false});

  final IconData icon;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32.r,
      height: 32.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: Colors.white, size: 18.sp),
    );
  }
}

/// App bar title for a user: photo, name and phone number.
class _UserTitle extends StatelessWidget {
  const _UserTitle(this.user);

  final Registration user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: PersonAvatar(
            name: user.name,
            imageUrl: user.imageUrl,
            radius: 19,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              Text(
                user.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutral,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
