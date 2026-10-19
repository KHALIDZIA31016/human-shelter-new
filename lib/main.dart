import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local/local_store.dart';
import 'firebase_options.dart';
import 'providers/chat_provider.dart';
import 'providers/complaint_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_change_provider.dart';
import 'providers/registration_provider.dart';
import 'providers/request_provider.dart';
import 'providers/session_provider.dart';
import 'providers/staff_provider.dart';
import 'providers/transfer_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final store = await LocalStore.open();
  await store.cleanSlateOnce();
  runApp(buildApp(store));
}

/// Wires providers; separated from [main] so tests can inject a store.
Widget buildApp(LocalStore store) {
  final notifs = NotificationProvider(store);
  final registrations = RegistrationProvider(store, notifs);
  final requests = RequestProvider(store, notifs, registrations);
  final complaints = ComplaintProvider(store, notifs);
  final chat = ChatProvider(store, notifs);
  final transfers = TransferProvider(
    store,
    notifs,
    registrations,
    requests,
    chat,
  );
  final profileChanges = ProfileChangeProvider(store, notifs, registrations);
  final session = SessionProvider(store);
  final staff = StaffProvider(store);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: notifs),
      ChangeNotifierProvider.value(value: registrations),
      ChangeNotifierProvider.value(value: requests),
      ChangeNotifierProvider.value(value: complaints),
      ChangeNotifierProvider.value(value: chat),
      ChangeNotifierProvider.value(value: transfers),
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: staff),
      ChangeNotifierProvider.value(value: profileChanges),
    ],
    child: const ShelterApp(),
  );
}
