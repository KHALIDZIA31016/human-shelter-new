import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/screen_utils.dart';
import 'providers/notification_provider.dart';
import 'providers/session_provider.dart';
import 'widgets/checkin_gate.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Drops every showing or queued toast whenever the user moves to another
/// screen, so messages never pile up or follow them around.
class _ToastClearer extends NavigatorObserver {
  void _clear() => messengerKey.currentState?.clearSnackBars();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _clear();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _clear();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _clear();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _clear();
}

class ShelterApp extends StatelessWidget {
  const ShelterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelter Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: messengerKey,
      navigatorObservers: [_ToastClearer()],
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        ScreenUtils.init(context);
        return NotificationToaster(
          child: CheckInGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Shows an in-app banner whenever a notification arrives for whoever is
/// currently using the app.
class NotificationToaster extends StatefulWidget {
  const NotificationToaster({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationToaster> createState() => _NotificationToasterState();
}

class _NotificationToasterState extends State<NotificationToaster> {
  late final NotificationProvider _notifs = context
      .read<NotificationProvider>();
  String? _lastShown;

  @override
  void initState() {
    super.initState();
    _lastShown = _notifs.latest?.id;
    _notifs.addListener(_onChange);
  }

  @override
  void dispose() {
    _notifs.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final n = _notifs.latest;
    if (n == null || n.id == _lastShown) return;
    _lastShown = n.id;
    final mine = context.read<SessionProvider>().recipientIds;
    if (!mine.contains(n.recipientId)) return;
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF134E4A),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                n.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
