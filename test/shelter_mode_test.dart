import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelter/data/local/local_store.dart';
import 'package:shelter/data/models/enums.dart';
import 'package:shelter/data/models/registration.dart';
import 'package:shelter/data/models/service_request.dart';
import 'package:shelter/data/models/staff_member.dart';
import 'package:shelter/main.dart';
import 'package:shelter/providers/notification_provider.dart';
import 'package:shelter/providers/registration_provider.dart';
import 'package:shelter/providers/request_provider.dart';
import 'package:shelter/providers/staff_provider.dart';

void main() {
  Future<void> boot(WidgetTester tester, {bool withData = true}) async {
    SharedPreferences.setMockInitialValues({
      'persona': 'partner',
      'active_partner': 'seed-1',
    });
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = await LocalStore.open();
    await tester.pumpWidget(buildApp(store));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I want to help'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login as Partner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    if (!withData) return;

    final ctx = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      final regs = ctx.read<RegistrationProvider>();
      final reqs = ctx.read<RequestProvider>();
      final staff = ctx.read<StaffProvider>();
      final shelter = regs.byId('seed-1')!;

      // A resident with an approved stay.
      await regs.submit(
        Registration(
          id: 'u1',
          ownerId: 'dev1',
          kind: RegistrationKind.individual,
          name: 'Ali Raza',
          phone: '03001234567',
          email: 'ali@example.com',
          city: 'Karachi',
          address: 'Street 4',
          familyMembers: 3,
          age: 41,
          needs: const ['Food', 'Shelter'],
        ),
      );
      await reqs.create(
        ServiceRequest(
          id: 'stay1',
          type: RequestType.stay,
          requesterId: 'dev1',
          requesterName: 'Ali Raza',
          phone: '03001234567',
          targetId: shelter.id,
          targetName: shelter.displayName,
          people: 3,
        ),
      );
      await reqs.approve(
        'stay1',
        Decision(
          arrivalAt: DateTime.now().subtract(const Duration(days: 3)),
          contactPerson: 'Mr Khan',
        ),
      );

      // A restaurant donation.
      await regs.submit(
        Registration(
          id: 'rest1',
          ownerId: 'dev2',
          kind: RegistrationKind.restaurant,
          name: 'Sara',
          orgName: 'Spice Hub',
          phone: '03111234567',
          city: 'Karachi',
          address: 'Food Street',
        ),
      );
      await regs.approve('rest1');
      await reqs.create(
        ServiceRequest(
          id: 'don1',
          type: RequestType.donation,
          requesterId: 'rest1',
          requesterName: 'Sara',
          phone: '03111234567',
          targetId: shelter.id,
          targetName: shelter.displayName,
          people: 40,
          meal: MealType.dinner,
          neededDate: DateTime.now(),
        ),
      );
      await reqs.approve(
        'don1',
        Decision(
          arrivalAt: DateTime.now().add(const Duration(hours: 2)),
          contactPerson: 'Mr Khan',
        ),
      );

      await staff.save(
        StaffMember(
          id: 's1',
          shelterId: shelter.id,
          name: 'Nadia',
          role: 'Cook',
          duties: 'Prepares meals',
          salary: 30000,
          joinedAt: DateTime.now().subtract(const Duration(days: 200)),
        ),
      );
      await staff.save(
        StaffMember(
          id: 's2',
          shelterId: shelter.id,
          name: 'Bilal',
          role: 'Warden',
          duties: 'Night watch',
          salary: 25000,
          joinedAt: DateTime.now().add(const Duration(days: 10)),
        ),
      );
      await staff.save(
        StaffMember(
          id: 's3',
          shelterId: shelter.id,
          name: 'Hina',
          role: 'Nurse',
          duties: 'Health checks',
          salary: 40000,
          joinedAt: DateTime.now().subtract(const Duration(days: 400)),
          leftAt: DateTime.now().subtract(const Duration(days: 20)),
          leaveReason: 'Moved cities',
        ),
      );
    });
    await tester.pumpAndSettle();
  }

  testWidgets('shelter mode: five tabs, no overflow, drill-downs work', (
    tester,
  ) async {
    await boot(tester);
    for (final l in ['Users', 'Donations', 'Chat', 'Alerts', 'Settings']) {
      expect(find.text(l), findsWidgets);
    }

    // Users
    expect(find.text('Ali Raza'), findsOneWidget);
    await tester.tap(find.text('Ali Raza'));
    await tester.pumpAndSettle();
    expect(find.text('User profile'), findsOneWidget);
    expect(find.text('ali@example.com'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Chat: nothing yet
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('No updates on chat yet'), findsOneWidget);

    // Settings -> profile
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Cases'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    await tester.tap(find.text('Shelter profile'));
    await tester.pumpAndSettle();
    expect(find.text('Shelter profile'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Nadia'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Nadia'));
    await tester.pumpAndSettle();
    expect(find.text('Staff profile'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cases'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bed management'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bed management'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Staff').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Donations
    await tester.tap(find.text('Donations').last);
    await tester.pumpAndSettle();
    expect(find.text('Spice Hub'), findsOneWidget);
    await tester.tap(find.text('Spice Hub'));
    await tester.pumpAndSettle();
    expect(find.text('Business details'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Alerts: badge counts down when one is read
    await tester.tap(find.text('Alerts').last);
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(MaterialApp));
    final notifs = ctx.read<NotificationProvider>();
    final before = notifs.unreadCount({'seed-1'});
    expect(before, greaterThan(0));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Users')); // category chip
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsWidgets);
    expect(notifs.unreadCount({'seed-1'}), before - 1);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shelter mode: large text scale does not overflow', (
    tester,
  ) async {
    await boot(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    for (final l in ['Chat', 'Settings', 'Alerts', 'Donations', 'Users']) {
      await tester.tap(find.text(l).last);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('shelter mode: add staff through the form', (tester) async {
    await boot(tester, withData: false);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Staff').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    // Empty submit shows validation, saves nothing.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add staff'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add staff'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Zainab Noor');
    await tester.enterText(fields.at(1), 'Cook');
    await tester.enterText(fields.at(2), 'Cooks three meals a day');
    await tester.enterText(fields.at(3), '35000');
    await tester.enterText(fields.at(5), '03001234567');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add staff'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add staff'));
    await tester.pumpAndSettle();
    expect(find.text('Zainab Noor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
