import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/chat/chat_register_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/complaints/complaint_detail_screen.dart';
import '../../screens/shelters/transfer_screens.dart';
import '../../screens/complaints/complaint_form_screen.dart';
import '../../screens/home/home_shell.dart';
import '../../screens/notifications/alerts_tab.dart';
import '../../screens/partner/profile_edit_screen.dart';
import '../../screens/home/mode_screen.dart';
import '../../screens/notifications/notification_detail_screen.dart';
import '../../screens/registration/register_screen.dart';
import '../../screens/profile/registration_detail_screen.dart';
import '../../screens/profile/user_profile_edit_screen.dart';
import '../../screens/requests/food_form_screen.dart';
import '../../screens/requests/help_request_screen.dart';
import '../../screens/requests/request_detail_screen.dart';
import '../../screens/requests/visits_screen.dart';
import '../../screens/requests/stay_request_screen.dart';
import '../../screens/shelters/shelter_detail_screen.dart';
import '../../screens/shelter_mode/approval_reports_screen.dart';
import '../../screens/shelter_mode/profile_changes_screen.dart';
import '../../screens/shelter_mode/shelter_donations_tab.dart';
import '../../screens/shelter_mode/shelter_profile_screen.dart';
import '../../screens/shelter_mode/shelter_settings_tab.dart';
import '../../screens/shelter_mode/shelter_user_detail_screen.dart';
import '../../screens/shelter_mode/staff_screens.dart';
import '../../screens/splash/splash_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const register = '/register';
  static const shelter = '/shelter';
  static const stay = '/stay';
  static const foodForm = '/food-form';
  static const request = '/request';
  static const help = '/help';
  static const visits = '/visits';
  static const alerts = '/alerts';
  static const chat = '/chat';
  static const chatRegister = '/chat-register';
  static const shelterChange = '/shelter-change';
  static const transfer = '/transfer';
  static const transferForm = '/transfer-form';
  static const notification = '/notification';
  static const modes = '/modes';
  static const profileEdit = '/profile-edit';
  static const myRegistration = '/my-registration';
  static const complaintForm = '/complaint-form';
  static const complaint = '/complaint';
  static const shelterUser = '/shelter-user';
  static const shelterProfile = '/shelter-profile';
  static const shelterCases = '/shelter-cases';
  static const shelterRequests = '/shelter-requests';
  static const beds = '/beds';
  static const staff = '/staff';
  static const staffDetail = '/staff-detail';
  static const staffForm = '/staff-form';
  static const donor = '/donor';
  static const approvalReports = '/approval-reports';
  static const myProfileEdit = '/my-profile-edit';
  static const profileChanges = '/profile-changes';
}

/// Arguments for [AppRoutes.foodForm]: a meal request (needy user) or a
/// donation offer (restaurant / company partner).
class FoodFormArgs {
  const FoodFormArgs({this.type = RequestType.food, this.shelterId});

  final RequestType type;
  final String? shelterId;
}

class AppRouter {
  AppRouter._();

  static Future<T?> push<T>(
    BuildContext context,
    String route, [
    Object? args,
  ]) => Navigator.of(context).pushNamed<T>(route, arguments: args);

  static Route<dynamic> onGenerateRoute(RouteSettings s) {
    final Widget page = switch (s.name) {
      AppRoutes.splash => const SplashScreen(),
      AppRoutes.login => const LoginScreen(),
      AppRoutes.home => const HomeShell(),
      AppRoutes.register => RegisterScreen(startAsPartner: s.arguments == true),
      AppRoutes.shelter => ShelterDetailScreen(
        shelterId: s.arguments as String,
      ),
      AppRoutes.stay => StayRequestScreen(shelterId: s.arguments as String?),
      AppRoutes.foodForm => FoodFormScreen(
        args: s.arguments as FoodFormArgs? ?? const FoodFormArgs(),
      ),
      AppRoutes.request => RequestDetailScreen(
        requestId: s.arguments as String,
      ),
      AppRoutes.myRegistration => const RegistrationDetailScreen(),
      AppRoutes.profileEdit => ProfileEditScreen(
        partnerId: s.arguments as String,
      ),
      AppRoutes.notification => NotificationDetailScreen(
        notificationId: s.arguments as String,
      ),
      AppRoutes.modes => const ModeScreen(),
      AppRoutes.chatRegister => const ChatRegisterScreen(),
      AppRoutes.chat => ChatScreen(
        userId: (s.arguments as String).split('|').first,
        shelterId: (s.arguments as String).split('|').last,
      ),
      AppRoutes.shelterChange => ShelterChangeScreen(
        toShelterId: s.arguments as String,
      ),
      AppRoutes.transferForm => TransferFormScreen(
        transferId: s.arguments as String,
      ),
      AppRoutes.transfer => TransferDetailScreen(
        transferId: s.arguments as String,
      ),
      AppRoutes.alerts => Scaffold(
        appBar: AppBar(title: const Text('Alerts')),
        body: const SafeArea(child: AlertsTab()),
      ),
      AppRoutes.visits => const VisitsScreen(),
      AppRoutes.help => HelpRequestScreen(shelterId: s.arguments as String?),
      AppRoutes.complaintForm => ComplaintFormScreen(
        requestId: s.arguments as String?,
      ),
      AppRoutes.complaint => ComplaintDetailScreen(
        complaintId: s.arguments as String,
      ),
      AppRoutes.shelterUser => ShelterUserDetailScreen(
        userId: (s.arguments as String).split('|').first,
        shelterId: (s.arguments as String).split('|').last,
      ),
      AppRoutes.shelterProfile => ShelterProfileScreen(
        shelterId: s.arguments as String,
      ),
      AppRoutes.shelterCases => ShelterCasesScreen(
        shelterId: s.arguments as String,
      ),
      AppRoutes.shelterRequests => ShelterRequestsScreen(
        shelterId: s.arguments as String,
      ),
      AppRoutes.myProfileEdit => const UserProfileEditScreen(),
      AppRoutes.profileChanges => ProfileChangesScreen(
        shelterId: s.arguments as String,
      ),
      AppRoutes.approvalReports => ApprovalReportsScreen(
        shelterId: s.arguments as String,
      ),
      AppRoutes.beds => BedManagementScreen(shelterId: s.arguments as String),
      AppRoutes.staff => StaffScreen(shelterId: s.arguments as String),
      AppRoutes.staffDetail => StaffDetailScreen(
        staffId: s.arguments as String,
      ),
      AppRoutes.staffForm => StaffFormScreen(
        shelterId: (s.arguments as String).split('|').first,
        staffId: (s.arguments as String).split('|').last.isEmpty
            ? null
            : (s.arguments as String).split('|').last,
      ),
      AppRoutes.donor => DonorDetailScreen(
        donorId: (s.arguments as String).split('|').first,
        shelterId: (s.arguments as String).split('|').last,
      ),
      _ => const SplashScreen(),
    };
    return MaterialPageRoute(builder: (_) => page, settings: s);
  }
}
