import 'enums.dart';

/// Why a person is complaining about a shelter.
enum ComplaintReason {
  notDelivered,
  wronglyRejected,
  misbehaviour,
  wrongInfo,
  other,
}

extension ComplaintReasonX on ComplaintReason {
  String get label => switch (this) {
    ComplaintReason.notDelivered => 'Approved but not delivered',
    ComplaintReason.wronglyRejected => 'Rejected unfairly',
    ComplaintReason.misbehaviour => 'Bad behaviour',
    ComplaintReason.wrongInfo => 'Wrong information',
    ComplaintReason.other => 'Something else',
  };
}

/// A confidential complaint from a user to the admin about a shelter.
/// The shelter is never told who complained; the admin only asks it to
/// verify a service record, then decides.
class Complaint {
  Complaint({
    required this.id,
    required this.complainantId,
    required this.complainantName,
    required this.phone,
    required this.shelterId,
    required this.shelterName,
    required this.reason,
    required this.message,
    this.requestId,
    this.requestSummary = '',
    this.status = ComplaintStatus.open,
    DateTime? createdAt,
    this.question,
    this.askedAt,
    this.shelterConfirmed,
    this.shelterNote,
    this.repliedAt,
    this.adminNote,
    this.resolvedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String complainantId;
  final String complainantName;
  final String phone;
  final String shelterId;
  final String shelterName;
  final ComplaintReason reason;
  final String message;

  /// Optional request the complaint is about, plus a snapshot of it.
  final String? requestId;
  final String requestSummary;
  final ComplaintStatus status;
  final DateTime createdAt;

  // Admin -> shelter verification
  final String? question;
  final DateTime? askedAt;

  /// true = shelter says the service was provided; false = it was not.
  final bool? shelterConfirmed;
  final String? shelterNote;
  final DateTime? repliedAt;

  // Final decision
  final String? adminNote;
  final DateTime? resolvedAt;

  Complaint copyWith({
    ComplaintStatus? status,
    String? question,
    DateTime? askedAt,
    bool? shelterConfirmed,
    String? shelterNote,
    DateTime? repliedAt,
    String? adminNote,
    DateTime? resolvedAt,
  }) => Complaint(
    id: id,
    complainantId: complainantId,
    complainantName: complainantName,
    phone: phone,
    shelterId: shelterId,
    shelterName: shelterName,
    reason: reason,
    message: message,
    requestId: requestId,
    requestSummary: requestSummary,
    status: status ?? this.status,
    createdAt: createdAt,
    question: question ?? this.question,
    askedAt: askedAt ?? this.askedAt,
    shelterConfirmed: shelterConfirmed ?? this.shelterConfirmed,
    shelterNote: shelterNote ?? this.shelterNote,
    repliedAt: repliedAt ?? this.repliedAt,
    adminNote: adminNote ?? this.adminNote,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'complainantId': complainantId,
    'complainantName': complainantName,
    'phone': phone,
    'shelterId': shelterId,
    'shelterName': shelterName,
    'reason': reason.name,
    'message': message,
    'requestId': requestId,
    'requestSummary': requestSummary,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'question': question,
    'askedAt': askedAt?.toIso8601String(),
    'shelterConfirmed': shelterConfirmed,
    'shelterNote': shelterNote,
    'repliedAt': repliedAt?.toIso8601String(),
    'adminNote': adminNote,
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory Complaint.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) => DateTime.tryParse(j[k] as String? ?? '');
    return Complaint(
      id: j['id'] as String,
      complainantId: j['complainantId'] as String,
      complainantName: j['complainantName'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      shelterId: j['shelterId'] as String,
      shelterName: j['shelterName'] as String? ?? '',
      reason: enumByName(
        ComplaintReason.values,
        j['reason'],
        ComplaintReason.other,
      ),
      message: j['message'] as String? ?? '',
      requestId: j['requestId'] as String?,
      requestSummary: j['requestSummary'] as String? ?? '',
      status: enumByName(
        ComplaintStatus.values,
        j['status'],
        ComplaintStatus.open,
      ),
      createdAt: d('createdAt'),
      question: j['question'] as String?,
      askedAt: d('askedAt'),
      shelterConfirmed: j['shelterConfirmed'] as bool?,
      shelterNote: j['shelterNote'] as String?,
      repliedAt: d('repliedAt'),
      adminNote: j['adminNote'] as String?,
      resolvedAt: d('resolvedAt'),
    );
  }
}
