import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelter/data/local/local_store.dart';
import 'package:shelter/data/models/complaint.dart';
import 'package:shelter/data/models/enums.dart';
import 'package:shelter/data/models/registration.dart';
import 'package:shelter/data/models/service_request.dart';
import 'package:shelter/main.dart';
import 'package:shelter/providers/chat_provider.dart';
import 'package:shelter/screens/home/approval_gate_screen.dart';
import 'package:shelter/providers/complaint_provider.dart';
import 'package:shelter/providers/transfer_provider.dart';
import 'package:shelter/providers/notification_provider.dart';
import 'package:shelter/providers/registration_provider.dart';
import 'package:shelter/providers/request_provider.dart';
import 'package:shelter/providers/session_provider.dart';

Future<LocalStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore.open();
}

void main() {
  testWidgets('splash then login then home', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp(await _store()));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Login as User'), findsOneWidget);
    await tester.tap(find.text('Login as User'));
    await tester.pumpAndSettle();
    expect(find.text('What do you need?'), findsOneWidget);
  });

  test(
    'registration notifies admin and owner; approval/rejection notify owner',
    () async {
      final store = await _store();
      final n = NotificationProvider(store);
      final regs = RegistrationProvider(store, n);
      final reg = Registration(
        id: 'r1',
        ownerId: 'dev1',
        kind: RegistrationKind.individual,
        name: 'Ali',
        phone: '03001234567',
        city: 'Karachi',
        address: 'x',
        needs: ['Food'],
      );
      expect(await regs.submit(reg), isNull);
      expect(n.forRecipients({'admin'}).length, 1);
      expect(n.forRecipients({'dev1'}).length, 1);
      expect(await regs.submit(reg.copyWith()), isNotNull); // duplicate blocked
      await regs.reject('r1', 'Bad phone');
      expect(n.forRecipients({'dev1'}).first.body, contains('Bad phone'));
    },
  );

  test(
    'stay approval consumes a bed and notifies requester + admin; shelter gets request',
    () async {
      final store = await _store();
      final n = NotificationProvider(store);
      final regs = RegistrationProvider(store, n);
      final reqs = RequestProvider(store, n, regs);
      final shelter = regs.approvedShelters.first;
      final before = shelter.availableBeds;
      final r = ServiceRequest(
        id: 'q1',
        type: RequestType.stay,
        requesterId: 'dev1',
        requesterName: 'Ali',
        phone: '0300',
        targetId: shelter.id,
        targetName: shelter.displayName,
      );
      expect(await reqs.create(r), isNull);
      expect(n.forRecipients({shelter.id}).length, 1);
      expect(
        n.forRecipients({'admin'}).length,
        1,
      ); // heads-up only; shelter decides
      expect(
        await reqs.approve(
          'q1',
          Decision(
            arrivalAt: DateTime.now().add(const Duration(hours: 3)),
            contactPerson: 'Mr Khan',
          ),
        ),
        isNull,
      );
      expect(regs.byId(shelter.id)!.availableBeds, before - 1);
      expect(n.forRecipients({'dev1'}).first.body, contains('Mr Khan'));
      expect(n.forRecipients({'admin'}).length, 2);
    },
  );

  test(
    'help requests: multiple items, max 2 per category per shelter per 24h',
    () async {
      final store = await _store();
      final n = NotificationProvider(store);
      final regs = RegistrationProvider(store, n);
      final reqs = RequestProvider(store, n, regs);
      final shelter = regs.approvedShelters.first;
      ServiceRequest help(String id, HelpCategory c) => ServiceRequest(
        id: id,
        type: RequestType.help,
        requesterId: 'dev1',
        requesterName: 'Ali',
        phone: '0300',
        targetId: shelter.id,
        targetName: shelter.displayName,
        category: c,
        items: c.items.take(2).toList(),
      );
      expect(await reqs.create(help('a', HelpCategory.clothes)), isNull);
      expect(await reqs.create(help('b', HelpCategory.clothes)), isNull);
      expect(
        await reqs.create(help('c', HelpCategory.clothes)),
        contains('Limit reached'),
      );
      expect(
        await reqs.create(help('d', HelpCategory.medical)),
        isNull,
      ); // other category ok
      expect(
        reqs.nextSlot('dev1', shelter.id, HelpCategory.clothes),
        isNotNull,
      );
      expect(reqs.nextSlot('dev2', shelter.id, HelpCategory.clothes), isNull);
    },
  );

  test(
    'complaint: admin verifies with shelter without exposing complainant',
    () async {
      final store = await _store();
      final n = NotificationProvider(store);
      final cs = ComplaintProvider(store, n);
      final c = Complaint(
        id: 'c1',
        complainantId: 'dev1',
        complainantName: 'Ali',
        phone: '0300',
        shelterId: 's1',
        shelterName: 'Hope',
        reason: ComplaintReason.notDelivered,
        message: 'Approved but nothing arrived',
      );
      await cs.submit(c);
      expect(n.forRecipients({'admin'}).length, 1);
      expect(n.forRecipients({'s1'}), isEmpty); // shelter not told
      expect(cs.forShelter('s1'), isEmpty);
      await cs.askShelter('c1', 'Did you deliver?');
      final toShelter = n.forRecipients({'s1'}).single;
      expect(toShelter.body.contains('Ali'), isFalse);
      expect(cs.forShelter('s1').length, 1);
      await cs.shelterReply('c1', confirmed: false, note: 'We did not');
      expect(cs.byId('c1')!.status, ComplaintStatus.shelterReplied);
      await cs.resolve('c1', upheld: true, note: 'Please deliver on time');
      expect(cs.byId('c1')!.status, ComplaintStatus.upheld);
      expect(n.forRecipients({'s1'}).first.title, 'Notice from admin');
    },
  );

  test('each persona only sees its own notifications', () async {
    final store = await _store();
    final n = NotificationProvider(store);
    final session = SessionProvider(store);
    await n.push(to: session.deviceId, title: 'personal', body: '');
    await n.push(to: 'shelterA', title: 'for A', body: '');
    await n.push(to: 'shelterB', title: 'for B', body: '');
    await n.push(to: 'admin', title: 'admin', body: '');

    List<String> titles() =>
        n.forRecipients(session.recipientIds).map((e) => e.title).toList();

    expect(titles(), ['personal']);
    await session.usePartner('shelterA');
    expect(titles(), ['for A']); // not the device's personal ones, not B's
    await session.useAdmin();
    expect(titles(), ['admin']);
  });

  test('no-show: closes only after 2h, notifies user, frees the bed', () async {
    final store = await _store();
    final n = NotificationProvider(store);
    final regs = RegistrationProvider(store, n);
    final reqs = RequestProvider(store, n, regs);
    final shelter = regs.approvedShelters.first;
    final before = shelter.availableBeds;
    ServiceRequest stay(String id) => ServiceRequest(
      id: id,
      type: RequestType.stay,
      requesterId: id == 'q1' ? 'dev1' : 'dev2',
      requesterName: 'Ali',
      phone: '0300',
      targetId: shelter.id,
      targetName: shelter.displayName,
    );

    await reqs.create(stay('q1'));
    await reqs.approve(
      'q1',
      Decision(
        arrivalAt: DateTime.now().add(const Duration(hours: 1)),
        contactPerson: 'Mr Khan',
        allottedUntil: DateTime.now().add(const Duration(days: 5)),
      ),
    );
    expect(reqs.byId('q1')!.visitState, VisitState.upcoming);
    expect(reqs.activeStay('dev1'), isNotNull);
    expect(await reqs.closeNoShow('q1'), isNotNull); // too early

    // Second order whose slot was 3 hours ago -> delayed -> closable.
    await reqs.create(stay('q2'));
    await reqs.approve(
      'q2',
      Decision(
        arrivalAt: DateTime.now().subtract(const Duration(hours: 3)),
        contactPerson: 'Mr Khan',
      ),
    );
    expect(reqs.byId('q2')!.visitState, VisitState.delayed);
    final bedsNow = regs.byId(shelter.id)!.availableBeds;
    expect(await reqs.closeNoShow('q2'), isNull);
    expect(reqs.byId('q2')!.visitState, VisitState.missed);
    expect(regs.byId(shelter.id)!.availableBeds, bedsNow + 1);
    expect(before - bedsNow, greaterThanOrEqualTo(1));
    expect(n.forRecipients({'dev2'}).first.title, 'Order closed with a notice');
  });

  group('residency, chat and shelter change', () {
    late NotificationProvider n;
    late RegistrationProvider regs;
    late RequestProvider reqs;
    late ChatProvider chat;
    late TransferProvider tr;
    late String a, b;

    Future<void> place(String user, String shelterId) async {
      final shelter = regs.byId(shelterId)!;
      final id = 'stay-$user-$shelterId';
      expect(
        await reqs.create(
          ServiceRequest(
            id: id,
            type: RequestType.stay,
            requesterId: user,
            requesterName: user,
            phone: '0300',
            targetId: shelterId,
            targetName: shelter.displayName,
          ),
        ),
        isNull,
      );
      expect(
        await reqs.approve(
          id,
          Decision(
            arrivalAt: DateTime.now(),
            contactPerson: 'Mgr',
            allottedUntil: DateTime.now().add(const Duration(days: 9)),
          ),
        ),
        isNull,
      );
    }

    setUp(() async {
      final store = await _store();
      n = NotificationProvider(store);
      regs = RegistrationProvider(store, n);
      reqs = RequestProvider(store, n, regs);
      chat = ChatProvider(store, n);
      tr = TransferProvider(store, n, regs, reqs, chat);
      a = regs.approvedShelters[0].id;
      b = regs.approvedShelters[1].id;
    });

    test(
      'one shelter at a time; conflict only notifies admin + current shelter',
      () async {
        await place('u1', a);
        expect(reqs.commitmentBlock('u1', b), isNotNull);
        expect(
          await reqs.create(
            ServiceRequest(
              id: 'x',
              type: RequestType.stay,
              requesterId: 'u1',
              requesterName: 'u1',
              phone: '0300',
              targetId: b,
              targetName: 'B',
            ),
          ),
          contains('already registered'),
        );
        await reqs.reportCommitmentConflict(
          current: reqs.activeStay('u1')!,
          userName: 'u1',
          attemptedShelterName: 'B',
        );
        expect(
          n.forRecipients({'admin'}).any((x) => x.title.contains('elsewhere')),
          isTrue,
        );
        expect(
          n
              .forRecipients({a})
              .any((x) => x.title.contains('registering elsewhere')),
          isTrue,
        );
        expect(n.forRecipients({b}), isEmpty);
      },
    );

    test(
      'chat: separate thread per user, only the other side is notified',
      () async {
        await chat.send(
          userId: 'u1',
          userName: 'U1',
          shelterId: a,
          shelterName: 'A',
          fromUser: true,
          text: 'hello',
        );
        await chat.send(
          userId: 'u2',
          userName: 'U2',
          shelterId: a,
          shelterName: 'A',
          fromUser: true,
          text: 'hi there',
        );
        await chat.send(
          userId: 'u1',
          userName: 'U1',
          shelterId: a,
          shelterName: 'A',
          fromUser: false,
          text: 'welcome',
        );
        expect(chat.messages('u1', a).map((m) => m.text), ['hello', 'welcome']);
        expect(chat.messages('u2', a).length, 1);
        expect(chat.threadsOfShelter(a).length, 2);
        expect(chat.unreadForShelter(a), 2);
        expect(chat.unreadForUser('u1'), 1);
        expect(chat.unreadForUser('u2'), 0);
        expect(
          n.forRecipients({'u1'}).single.body,
          'welcome',
        ); // reply reached the user
        expect(n.forRecipients({'u2'}), isEmpty);
      },
    );

    test(
      'shelter change: report to admin, admin picks, shelter confirms, user submits',
      () async {
        await place('u1', a);
        final stay = reqs.activeStay('u1')!;
        expect(
          await tr.request(
            stay: stay,
            toShelterId: b,
            reason: 'Closer to my family',
          ),
          isNull,
        );
        final t = tr.openOf('u1')!;
        expect(chat.messages('u1', a).single.text, contains('24 hours'));
        expect(n.forRecipients({b}), isEmpty); // new shelter hears nothing yet
        expect(
          n.forRecipients({a}).any((x) => x.body.contains('cannot decide')),
          isTrue,
        );

        // The current shelter can only notify admin, with a full report.
        await tr.notifyAdmin(t.id, remarks: 'Calm resident');
        final r = tr.byId(t.id)!;
        expect(r.status, TransferStatus.pendingAdmin);
        expect(r.report, contains('Staying since'));
        expect(r.report, contains('Reason for change: Closer to my family'));
        expect(
          n
              .forRecipients({'admin'})
              .any((x) => x.title.contains('Resident report')),
          isTrue,
        );

        expect(await tr.adminDecision(t.id, approve: true, note: 'ok'), isNull);
        expect(tr.byId(t.id)!.status, TransferStatus.pendingNew);
        expect(
          n.forRecipients({b}).any((x) => x.title.contains('confirm a bed')),
          isTrue,
        );

        // Target confirms: a bed is now occupied for the user.
        final bedsB = regs.byId(b)!.availableBeds;
        expect(await tr.newConfirm(t.id), isNull);
        expect(regs.byId(b)!.availableBeds, bedsB - 1);
        expect(tr.byId(t.id)!.status, TransferStatus.confirmed);
        expect(tr.byId(t.id)!.reservedBed, isNotNull);
        expect(n.forRecipients({'u1'}).first.title, contains('ready'));
        expect(
          n.forRecipients({a}).any((x) => x.title.contains('will be leaving')),
          isTrue,
        );

        // User submits the form -> moved, old bed free, no second bed used.
        final bedsA = regs.byId(a)!.availableBeds;
        expect(await tr.userComplete(t.id, people: 1), isNull);
        expect(reqs.activeStay('u1')!.targetId, b);
        expect(regs.byId(b)!.availableBeds, bedsB - 1);
        expect(regs.byId(a)!.availableBeds, bedsA + 1);
        expect(tr.byId(t.id)!.status, TransferStatus.completed);
        expect(n.forRecipients({a}).first.title, contains('bed is empty'));
      },
    );

    test(
      'admin recommends another shelter when the requested one is full',
      () async {
        await place('u1', a);
        final third = regs.approvedShelters.firstWhere(
          (s) => s.id != a && s.id != b,
        );
        while (regs.byId(b)!.availableBeds > 0) {
          await regs.consumeBed(b);
        }
        expect(
          await tr.request(
            stay: reqs.activeStay('u1')!,
            toShelterId: b,
            reason: 'Closer to work',
          ),
          isNull,
        );
        final t = tr.openOf('u1')!;
        await tr.notifyAdmin(t.id);
        expect(
          await tr.adminDecision(t.id, approve: true, note: 'x'),
          contains('no free bed'),
        );
        expect(
          await tr.adminDecision(
            t.id,
            approve: true,
            toShelterId: third.id,
            note: 'Recommended',
          ),
          isNull,
        );
        final r = tr.byId(t.id)!;
        expect(r.toShelterId, third.id);
        expect(r.recommended, isTrue);
        expect(n.forRecipients({third.id}), isNotEmpty);
        expect(n.forRecipients({b}), isEmpty);
      },
    );

    test('withdraw frees the bed and ends the stay', () async {
      await place('u1', a);
      final beds = regs.byId(a)!.availableBeds;
      expect(
        await reqs.withdrawStay(
          reqs.activeStay('u1')!.id,
          reason: 'found work',
        ),
        isNull,
      );
      expect(reqs.activeStay('u1'), isNull);
      expect(regs.byId(a)!.availableBeds, beds + 1);
    });
  });

  test('several users on one device only see their own data', () async {
    final store = await _store();
    final n = NotificationProvider(store);
    final regs = RegistrationProvider(store, n);
    final reqs = RequestProvider(store, n, regs);
    final session = SessionProvider(store);
    final first = session.deviceId;
    expect(session.users.length, 1);

    final second = (await session.addUser()).id;
    expect(session.deviceId, second);
    expect(session.users.length, 2);

    final shelter = regs.approvedShelters.first;
    await reqs.create(
      ServiceRequest(
        id: 'a',
        type: RequestType.food,
        requesterId: first,
        requesterName: 'One',
        phone: '0300',
        targetId: shelter.id,
        targetName: shelter.displayName,
        meal: MealType.lunch,
      ),
    );
    await reqs.create(
      ServiceRequest(
        id: 'b',
        type: RequestType.food,
        requesterId: second,
        requesterName: 'Two',
        phone: '0300',
        targetId: shelter.id,
        targetName: shelter.displayName,
        meal: MealType.lunch,
      ),
    );

    // As the second user: only their request and notifications.
    expect(reqs.sentBy(session.deviceId).map((r) => r.id), ['b']);
    expect(
      n.forRecipients(session.recipientIds).every((x) => x.refId == 'b'),
      isTrue,
    );

    await session.useNeedy(userId: first);
    expect(reqs.sentBy(session.deviceId).map((r) => r.id), ['a']);
    expect(
      n.forRecipients(session.recipientIds).every((x) => x.refId == 'a'),
      isTrue,
    );

    // Survives a restart.
    final again = SessionProvider(store);
    expect(again.deviceId, first);
    expect(again.users.length, 2);
  });

  test(
    'a user cannot enter until the admin approves their registration',
    () async {
      final store = await _store();
      final n = NotificationProvider(store);
      final regs = RegistrationProvider(store, n);
      final session = SessionProvider(store);

      // Original user, never registered: may use the app (meals need no sign-up).
      expect(isBlockedUser(session, regs), isFalse);

      // New user made with "Register myself": blocked even before the form.
      final u = await session.addUser();
      expect(isBlockedUser(session, regs), isTrue);

      final reg = Registration(
        id: 'r9',
        ownerId: u.id,
        kind: RegistrationKind.individual,
        name: 'Zoya',
        phone: '03001234567',
        city: 'Lahore',
        address: 'x',
      );
      await regs.submit(reg);
      expect(isBlockedUser(session, regs), isTrue); // pending
      await regs.approve('r9');
      expect(isBlockedUser(session, regs), isFalse); // approved -> can enter
    },
  );
}
