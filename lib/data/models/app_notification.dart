import 'enums.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    this.kind = NotifKind.system,
    this.refId,
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;

  /// 'admin', a device id, or a partner registration id.
  final String recipientId;
  final String title;
  final String body;
  final NotifKind kind;

  /// Registration / request this notification is about.
  final String? refId;
  final DateTime createdAt;
  final bool read;

  AppNotification markRead() => AppNotification(
    id: id,
    recipientId: recipientId,
    title: title,
    body: body,
    kind: kind,
    refId: refId,
    createdAt: createdAt,
    read: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipientId': recipientId,
    'title': title,
    'body': body,
    'kind': kind.name,
    'refId': refId,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    recipientId: j['recipientId'] as String,
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    kind: enumByName(NotifKind.values, j['kind'], NotifKind.system),
    refId: j['refId'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    read: j['read'] as bool? ?? false,
  );
}
