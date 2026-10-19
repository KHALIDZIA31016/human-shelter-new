import 'package:flutter/foundation.dart';

import '../data/local/local_store.dart';
import '../data/models/staff_member.dart';

class StaffProvider extends ChangeNotifier {
  StaffProvider(this._store) {
    _items = _store.readList(_key).map(StaffMember.fromJson).toList();
  }

  static const _key = 'staff_v1';

  final LocalStore _store;
  List<StaffMember> _items = [];

  StaffMember? byId(String? id) {
    for (final s in _items) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Every staff record of a shelter: working first, then joining soon, then
  /// former (most recently left first).
  List<StaffMember> of(String shelterId) {
    final list = _items.where((s) => s.shelterId == shelterId).toList();
    int rank(StaffMember s) => switch (s.state) {
      StaffState.current => 0,
      StaffState.upcoming => 1,
      StaffState.former => 2,
    };
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.state == StaffState.former
          ? b.leftAt!.compareTo(a.leftAt!)
          : a.joinedAt.compareTo(b.joinedAt);
    });
    return list;
  }

  List<StaffMember> inState(String shelterId, StaffState state) =>
      of(shelterId).where((s) => s.state == state).toList();

  /// Monthly salary bill of the people currently working.
  int monthlyPayroll(String shelterId) =>
      inState(shelterId, StaffState.current).fold(0, (a, s) => a + s.salary);

  Future<void> save(StaffMember s) async {
    final i = _items.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      _items[i] = s;
    } else {
      _items.add(s);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((s) => s.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
