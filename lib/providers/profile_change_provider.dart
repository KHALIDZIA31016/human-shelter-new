import 'package:flutter/foundation.dart';

import '../data/local/local_store.dart';
import '../data/models/enums.dart';
import '../data/models/profile_change.dart';
import 'notification_provider.dart';
import 'registration_provider.dart';

/// Resident -> shelter: "please change these details in my profile".
/// Approve updates the profile; reject leaves it untouched.
class ProfileChangeProvider extends ChangeNotifier {
  ProfileChangeProvider(this._store, this._notifs, this._registrations) {
    _items = _store.readList(_key).map(ProfileChange.fromJson).toList();
  }

  static const _key = 'profile_changes_v1';

  final LocalStore _store;
  final NotificationProvider _notifs;
  final RegistrationProvider _registrations;
  List<ProfileChange> _items = [];

  List<ProfileChange> get all =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  ProfileChange? byId(String? id) {
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<ProfileChange> by(String userId) =>
      all.where((c) => c.userId == userId).toList();

  ProfileChange? latestOf(String userId) {
    final mine = by(userId);
    return mine.isEmpty ? null : mine.first;
  }

  ProfileChange? pendingOf(String userId) {
    for (final c in by(userId)) {
      if (c.status == ReviewStatus.pending) return c;
    }
    return null;
  }

  List<ProfileChange> forShelter(String shelterId) =>
      all.where((c) => c.shelterId == shelterId).toList();

  int pendingCount(String shelterId) => _items
      .where(
        (c) => c.shelterId == shelterId && c.status == ReviewStatus.pending,
      )
      .length;

  /// Returns an error message, or null on success.
  Future<String?> submit(ProfileChange c) async {
    if (pendingOf(c.userId) != null) {
      return 'You already have a request waiting for the shelter.';
    }
    if (c.changed.isEmpty) return 'Change at least one detail first.';
    _items.add(c);
    notifyListeners();
    await _persist();
    final what = c.changed.keys.map((k) => kProfileFields[k]).join(', ');
    await _notifs.push(
      to: c.shelterId,
      title: 'Profile change request',
      body:
          '${c.userName} asked to change: $what. Open Settings → Profile '
          'changes to approve or reject.',
      kind: NotifKind.registration,
      refId: c.id,
    );
    return null;
  }

  Future<void> approve(String id) async {
    final c = byId(id);
    if (c == null || c.status != ReviewStatus.pending) return;
    final a = c.after;
    await _registrations.updateProfile(
      c.registrationId,
      name: a['name'],
      phone: a['phone'],
      email: a['email'],
      city: a['city'],
      address: a['address'],
      age: int.tryParse(a['age'] ?? ''),
    );
    _replace(
      c.copyWith(status: ReviewStatus.approved, decidedAt: DateTime.now()),
    );
    await _persist();
    await _notifs.push(
      to: c.userId,
      title: 'Profile changes approved ✅',
      body: '${c.shelterName} approved your changes. Your profile is updated.',
      kind: NotifKind.decision,
      refId: c.id,
    );
  }

  Future<void> reject(String id, String reason) async {
    final c = byId(id);
    if (c == null || c.status != ReviewStatus.pending) return;
    _replace(
      c.copyWith(
        status: ReviewStatus.rejected,
        decidedAt: DateTime.now(),
        rejectReason: reason,
      ),
    );
    await _persist();
    await _notifs.push(
      to: c.userId,
      title: 'Profile changes rejected',
      body:
          '${c.shelterName} did not approve your changes: "$reason". Your '
          'profile was not changed.',
      kind: NotifKind.decision,
      refId: c.id,
    );
  }

  void _replace(ProfileChange c) {
    final i = _items.indexWhere((e) => e.id == c.id);
    if (i >= 0) _items[i] = c;
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
