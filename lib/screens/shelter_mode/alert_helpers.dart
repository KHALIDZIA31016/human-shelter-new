import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/enums.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/transfer_provider.dart';

/// Who an alert came from, as the shelter sees it.
enum AlertSource { users, admin, shelters }

extension AlertSourceX on AlertSource {
  String get label => switch (this) {
    AlertSource.users => 'Users',
    AlertSource.admin => 'Admin',
    AlertSource.shelters => 'Shelters',
  };

  String get longLabel => switch (this) {
    AlertSource.users => 'From users',
    AlertSource.admin => 'From admin',
    AlertSource.shelters => 'From other shelters',
  };

  IconData get icon => switch (this) {
    AlertSource.users => Icons.people_alt_rounded,
    AlertSource.admin => Icons.admin_panel_settings_rounded,
    AlertSource.shelters => Icons.home_work_rounded,
  };

  Color get color => switch (this) {
    AlertSource.users => AppColors.primary,
    AlertSource.admin => const Color(0xFF7C3AED),
    AlertSource.shelters => AppColors.accent,
  };
}

/// Sorts a notification into users / admin / shelters by what it is about.
AlertSource alertSource(AppNotification n) {
  final t = n.title.toLowerCase();
  if (t.contains('admin')) return AlertSource.admin;
  switch (n.kind) {
    case NotifKind.registration:
    case NotifKind.complaint:
    case NotifKind.system:
      return AlertSource.admin;
    case NotifKind.decision:
      return t.startsWith('registration')
          ? AlertSource.admin
          : AlertSource.users;
    case NotifKind.transfer:
      if (t.contains('change requested') || t.contains('requested a shelter')) {
        return AlertSource.users;
      }
      if (t.contains('rejected')) return AlertSource.admin;
      return AlertSource.shelters;
    case NotifKind.request:
    case NotifKind.chat:
      return AlertSource.users;
  }
}

/// A screen an alert can open.
class AlertTarget {
  const AlertTarget(this.label, this.icon, this.route, this.args);

  final String label;
  final IconData icon;
  final String route;
  final Object? args;
}

/// The in-app screen this alert is about, or null when none exists (so no
/// "Visit" button is shown).
AlertTarget? alertTarget(BuildContext context, AppNotification n) {
  final id = n.refId;
  if (id == null || id.isEmpty) return null;
  switch (n.kind) {
    case NotifKind.chat:
      return id.contains('|')
          ? AlertTarget(
              'Open chat',
              Icons.chat_bubble_rounded,
              AppRoutes.chat,
              id,
            )
          : null;
    case NotifKind.complaint:
      return context.read<ComplaintProvider>().byId(id) == null
          ? null
          : AlertTarget(
              'Open case',
              Icons.fact_check_rounded,
              AppRoutes.complaint,
              id,
            );
    case NotifKind.transfer:
      if (context.read<TransferProvider>().byId(id) != null) {
        return AlertTarget(
          'Open shelter change',
          Icons.swap_horiz_rounded,
          AppRoutes.transfer,
          id,
        );
      }
      return null;
    case NotifKind.request:
    case NotifKind.decision:
      if (context.read<RequestProvider>().byId(id) != null) {
        return AlertTarget(
          'Open request',
          Icons.inbox_rounded,
          AppRoutes.request,
          id,
        );
      }
      if (context.read<RegistrationProvider>().byId(id)?.isApproved ?? false) {
        return AlertTarget(
          'Open profile',
          Icons.storefront_rounded,
          AppRoutes.shelterProfile,
          id,
        );
      }
      return null;
    case NotifKind.registration:
    case NotifKind.system:
      return null;
  }
}
