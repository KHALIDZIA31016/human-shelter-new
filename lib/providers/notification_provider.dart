import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../data/local/local_store.dart';
import '../data/models/app_notification.dart';
import '../data/models/enums.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._store) {
    _items = _store.readList(_key).map(AppNotification.fromJson).toList();
  }

  static const _key = 'notifications_v1';
  static const adminId = 'admin';

  final LocalStore _store;
  List<AppNotification> _items = [];

  /// Most recently pushed notification (drives the in-app banner).
  AppNotification? latest;

  AppNotification? byId(String? id) {
    for (final n in _items) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<AppNotification> forRecipients(Set<String> ids) =>
      _items.where((n) => ids.contains(n.recipientId)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadCount(Set<String> ids) =>
      _items.where((n) => ids.contains(n.recipientId) && !n.read).length;

  Future<void> push({
    required String to,
    required String title,
    required String body,
    NotifKind kind = NotifKind.system,
    String? refId,
  }) async {
    final n = AppNotification(
      id: newId(),
      recipientId: to,
      title: title,
      body: body,
      kind: kind,
      refId: refId,
    );
    _items.add(n);
    latest = n;
    notifyListeners();
    await _persist();
  }

  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].read) return;
    _items[i] = _items[i].markRead();
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead(Set<String> ids) async {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (ids.contains(_items[i].recipientId) && !_items[i].read) {
        _items[i] = _items[i].markRead();
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
