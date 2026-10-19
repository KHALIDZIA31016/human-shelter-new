import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/local/local_store.dart';
import '../data/models/enums.dart';
import '../data/models/registration.dart';
import '../data/remote/registration_remote.dart';
import 'notification_provider.dart';

class RegistrationProvider extends ChangeNotifier {
  RegistrationProvider(this._store, this._notifs) {
    _items = _store.readList(_key).map(Registration.fromJson).toList();
    // Push everything stored on this device to Firestore whenever someone
    // signs in, so records saved while offline or before sync existed appear.
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u != null) {
        for (final r in _items) {
          RegistrationRemote.save(r);
        }
      }
    });
  }

  static const _key = 'registrations_v1';

  final LocalStore _store;
  final NotificationProvider _notifs;
  List<Registration> _items = [];

  // ---- queries -----------------------------------------------------------

  List<Registration> get all =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Registration> byStatus(ReviewStatus s) =>
      all.where((r) => r.status == s).toList();

  List<Registration> get approvedShelters => all
      .where((r) => r.kind == RegistrationKind.shelter && r.isApproved)
      .toList();

  List<Registration> get approvedPartners =>
      all.where((r) => r.isPartner && r.isApproved).toList();

  List<Registration> ownedApprovedPartners(String ownerId) =>
      approvedPartners.where((r) => r.ownerId == ownerId).toList();

  Registration? byId(String? id) {
    for (final r in _items) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Latest individual registration of this device (any status).
  Registration? individualOf(String ownerId) {
    final mine = all.where(
      (r) => r.ownerId == ownerId && r.kind == RegistrationKind.individual,
    );
    return mine.isEmpty ? null : mine.first;
  }

  int get freeBeds =>
      approvedShelters.fold(0, (sum, s) => sum + s.availableBeds);

  // ---- commands ----------------------------------------------------------

  /// Returns an error message, or null on success.
  Future<String?> submit(Registration r) async {
    if (r.kind == RegistrationKind.individual) {
      final existing = individualOf(r.ownerId);
      if (existing != null && existing.status != ReviewStatus.rejected) {
        return existing.isApproved
            ? 'You are already registered and approved.'
            : 'Your registration is already under review.';
      }
    }
    _items.add(r);
    notifyListeners();
    await _persist();
    await RegistrationRemote.save(r);

    await _notifs.push(
      to: NotificationProvider.adminId,
      title: r.isPartner ? 'New partner request' : 'New help registration',
      body: r.adminSummary,
      kind: NotifKind.registration,
      refId: r.id,
    );
    await _notifs.push(
      to: r.ownerId,
      title: 'Registration received',
      body:
          'Thank you ${r.name}! Admin will respond to your request within '
          '24–48 hours. You will be notified here.',
      kind: NotifKind.registration,
      refId: r.id,
    );
    return null;
  }

  Future<void> approve(String id) async {
    final r = byId(id);
    if (r == null || r.status != ReviewStatus.pending) return;
    _replace(
      r.copyWith(
        status: ReviewStatus.approved,
        reviewedAt: DateTime.now(),
        availableBeds: r.totalBeds,
      ),
    );
    await _persist();
    await _notifs.push(
      to: r.ownerId,
      title: 'Registration approved ✅',
      body: r.isPartner
          ? '${r.displayName} is now an approved ${r.kind.label.toLowerCase()} '
                'partner. Open your dashboard from the home screen.'
          : 'Your registration is approved. You can now apply for a shelter stay.',
      kind: NotifKind.decision,
      refId: r.id,
    );
  }

  Future<void> reject(String id, String reason) async {
    final r = byId(id);
    if (r == null || r.status != ReviewStatus.pending) return;
    _replace(
      r.copyWith(
        status: ReviewStatus.rejected,
        rejectReason: reason,
        reviewedAt: DateTime.now(),
      ),
    );
    await _persist();
    await _notifs.push(
      to: r.ownerId,
      title: 'Registration rejected',
      body: 'Reason: $reason',
      kind: NotifKind.decision,
      refId: r.id,
    );
  }

  Future<void> updateBeds(
    String id, {
    required int total,
    required int available,
  }) async {
    final r = byId(id);
    if (r == null) return;
    _replace(
      r.copyWith(totalBeds: total, availableBeds: available.clamp(0, total)),
    );
    await _persist();
  }

  /// Reserves one bed. Returns its label, or null if the shelter is full.
  Future<String?> consumeBed(String shelterId) async {
    final r = byId(shelterId);
    if (r == null || r.availableBeds < 1) return null;
    final label = 'Bed #${r.totalBeds - r.availableBeds + 1}';
    _replace(r.copyWith(availableBeds: r.availableBeds - 1));
    await _persist();
    return label;
  }

  /// Frees one bed again (e.g. a no-show was closed).
  Future<void> releaseBed(String shelterId) async {
    final r = byId(shelterId);
    if (r == null) return;
    _replace(
      r.copyWith(availableBeds: (r.availableBeds + 1).clamp(0, r.totalBeds)),
    );
    await _persist();
  }

  /// Shelter / partner edits their public profile. Users see it instantly.
  Future<void> updateProfile(
    String id, {
    String? name,
    String? phone,
    String? email,
    String? city,
    String? address,
    String? notes,
    String? hours,
    String? imageUrl,
    List<String>? services,
    int? age,
    int? familyMembers,
  }) async {
    final r = byId(id);
    if (r == null) return;
    _replace(
      r.copyWith(
        name: name,
        phone: phone,
        email: email,
        city: city,
        address: address,
        notes: notes,
        hours: hours,
        imageUrl: imageUrl,
        services: services,
        age: age,
        familyMembers: familyMembers,
      ),
    );
    await _persist();
  }

  // ---- suspension --------------------------------------------------------

  List<Registration> get pendingAppeals =>
      all.where((r) => r.appealPending).toList();

  /// Admin blocks login for this account. Nothing else is touched, so users,
  /// services and donations are all still there when it is lifted.
  Future<void> suspend(String id, String reason) async {
    final r = byId(id);
    if (r == null) return;
    _replace(
      r.copyWith(
        suspended: true,
        suspendReason: reason,
        suspendedAt: DateTime.now(),
        appealText: null,
        appealAt: null,
        appealResponse: null,
      ),
    );
    await _persist();
    await _notifs.push(
      to: r.ownerId,
      title: 'Account suspended',
      body: 'Your account was suspended by the admin. Violation: $reason',
      kind: NotifKind.decision,
      refId: r.id,
    );
  }

  /// Removes the suspension: the owner can log in to everything again.
  Future<void> liftSuspension(String id) async {
    final r = byId(id);
    if (r == null) return;
    _replace(
      r.copyWith(
        suspended: false,
        suspendReason: null,
        suspendedAt: null,
        appealText: null,
        appealAt: null,
        appealResponse: null,
      ),
    );
    await _persist();
    await _notifs.push(
      to: r.ownerId,
      title: 'Suspension removed',
      body: 'Your appeal was accepted. You can log in again.',
      kind: NotifKind.decision,
      refId: r.id,
    );
  }

  /// Owner explains why the suspension should be removed. One at a time.
  Future<String?> submitAppeal(String id, String text) async {
    final r = byId(id);
    if (r == null || !r.suspended) return 'This account is not suspended.';
    if (r.appealPending) return 'Your appeal is already waiting for review.';
    _replace(
      r.copyWith(
        appealText: text,
        appealAt: DateTime.now(),
        appealResponse: null,
      ),
    );
    await _persist();
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'Suspension appeal',
      body: '${r.displayName} appealed their suspension: "$text"',
      kind: NotifKind.registration,
      refId: r.id,
    );
    return null;
  }

  /// Admin turns the appeal down; the owner may appeal again.
  Future<void> rejectAppeal(String id, String response) async {
    final r = byId(id);
    if (r == null || !r.appealPending) return;
    _replace(
      r.copyWith(appealText: null, appealAt: null, appealResponse: response),
    );
    await _persist();
    await _notifs.push(
      to: r.ownerId,
      title: 'Appeal not accepted',
      body: response.isEmpty
          ? 'The admin kept your account suspended.'
          : 'The admin kept your account suspended: $response',
      kind: NotifKind.decision,
      refId: r.id,
    );
  }

  // ---- internals ---------------------------------------------------------

  void _replace(Registration r) {
    final i = _items.indexWhere((e) => e.id == r.id);
    if (i >= 0) _items[i] = r;
    notifyListeners();
    RegistrationRemote.save(r);
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
