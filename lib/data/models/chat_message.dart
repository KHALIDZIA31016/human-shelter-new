/// One message in the thread between a user and the shelter they are
/// registered at. Thread key = userId|shelterId.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.userId,
    required this.shelterId,
    required this.fromUser,
    required this.text,
    this.system = false,
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String userId;
  final String shelterId;

  /// true = written by the user, false = by the shelter (or system).
  final bool fromUser;
  final String text;

  /// Automatic notice (e.g. "feedback within 24 hours").
  final bool system;
  final DateTime createdAt;
  final bool read;

  String get threadKey => '$userId|$shelterId';

  ChatMessage markRead() => ChatMessage(
    id: id,
    userId: userId,
    shelterId: shelterId,
    fromUser: fromUser,
    text: text,
    system: system,
    createdAt: createdAt,
    read: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'shelterId': shelterId,
    'fromUser': fromUser,
    'text': text,
    'system': system,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    userId: j['userId'] as String,
    shelterId: j['shelterId'] as String,
    fromUser: j['fromUser'] as bool? ?? true,
    text: j['text'] as String? ?? '',
    system: j['system'] as bool? ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    read: j['read'] as bool? ?? false,
  );
}
