import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../data/local/local_store.dart';
import '../data/models/chat_message.dart';
import '../data/models/enums.dart';
import 'notification_provider.dart';

/// One-to-one chat between a resident and the shelter they are registered
/// at. Every pair has its own thread, so a shelter with many residents has
/// many separate chats.
class ChatProvider extends ChangeNotifier {
  ChatProvider(this._store, this._notifs) {
    _items = _store.readList(_key).map(ChatMessage.fromJson).toList();
  }

  static const _key = 'chat_v1';

  final LocalStore _store;
  final NotificationProvider _notifs;
  List<ChatMessage> _items = [];

  List<ChatMessage> messages(String userId, String shelterId) =>
      _items
          .where((m) => m.userId == userId && m.shelterId == shelterId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Latest message of every thread of this shelter, newest first.
  List<ChatMessage> threadsOfShelter(String shelterId) {
    final latest = <String, ChatMessage>{};
    for (final m in _items.where((m) => m.shelterId == shelterId)) {
      final cur = latest[m.userId];
      if (cur == null || m.createdAt.isAfter(cur.createdAt))
        latest[m.userId] = m;
    }
    return latest.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int unreadForShelter(String shelterId, [String? userId]) => _items
      .where(
        (m) =>
            m.shelterId == shelterId &&
            m.fromUser &&
            !m.read &&
            (userId == null || m.userId == userId),
      )
      .length;

  int unreadForUser(String userId, [String? shelterId]) => _items
      .where(
        (m) =>
            m.userId == userId &&
            !m.fromUser &&
            !m.read &&
            (shelterId == null || m.shelterId == shelterId),
      )
      .length;

  Future<void> send({
    required String userId,
    required String userName,
    required String shelterId,
    required String shelterName,
    required bool fromUser,
    required String text,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _items.add(
      ChatMessage(
        id: newId(),
        userId: userId,
        shelterId: shelterId,
        fromUser: fromUser,
        text: t,
      ),
    );
    notifyListeners();
    await _persist();
    // Only the other side is notified.
    await _notifs.push(
      to: fromUser ? shelterId : userId,
      title: fromUser ? 'Message from $userName' : 'Message from $shelterName',
      body: t,
      kind: NotifKind.chat,
      refId: '$userId|$shelterId',
    );
  }

  /// Automatic reply written by the system into the thread (shown to the
  /// user as coming from the shelter's desk).
  Future<void> system({
    required String userId,
    required String shelterId,
    required String text,
    bool fromUser = false,
  }) async {
    _items.add(
      ChatMessage(
        id: newId(),
        userId: userId,
        shelterId: shelterId,
        fromUser: fromUser,
        text: text,
        system: true,
      ),
    );
    notifyListeners();
    await _persist();
  }

  /// Marks messages addressed to the viewer as read.
  Future<void> markRead(
    String userId,
    String shelterId, {
    required bool asUser,
  }) async {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final m = _items[i];
      if (m.userId == userId &&
          m.shelterId == shelterId &&
          !m.read &&
          m.fromUser != asUser) {
        _items[i] = m.markRead();
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
