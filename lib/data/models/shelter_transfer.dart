import 'enums.dart';

/// A user's request to move from their current shelter to another one.
class ShelterTransfer {
  ShelterTransfer({
    required this.id,
    required this.userId,
    required this.userName,
    required this.stayRequestId,
    required this.fromShelterId,
    required this.fromName,
    required this.toShelterId,
    required this.toName,
    required this.reason,
    this.status = TransferStatus.pendingCurrent,
    this.report,
    this.currentRemarks,
    this.adminNote,
    this.newReply,
    this.reservedBed,
    this.recommended = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String userId;
  final String userName;

  /// The stay being moved away from.
  final String stayRequestId;
  final String fromShelterId;
  final String fromName;

  /// Target shelter. The admin may change it (a recommendation).
  final String toShelterId;
  final String toName;
  final String reason;
  final TransferStatus status;

  /// Full resident report the current shelter sent to the admin.
  final String? report;
  final String? currentRemarks;
  final String? adminNote;
  final String? newReply;

  /// Bed the target shelter set aside once it confirmed.
  final String? reservedBed;

  /// True when the admin picked a different shelter than the user asked for.
  final bool recommended;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShelterTransfer copyWith({
    TransferStatus? status,
    String? toShelterId,
    String? toName,
    String? report,
    String? currentRemarks,
    String? adminNote,
    String? newReply,
    String? reservedBed,
    bool? recommended,
  }) => ShelterTransfer(
    id: id,
    userId: userId,
    userName: userName,
    stayRequestId: stayRequestId,
    fromShelterId: fromShelterId,
    fromName: fromName,
    toShelterId: toShelterId ?? this.toShelterId,
    toName: toName ?? this.toName,
    reason: reason,
    status: status ?? this.status,
    report: report ?? this.report,
    currentRemarks: currentRemarks ?? this.currentRemarks,
    adminNote: adminNote ?? this.adminNote,
    newReply: newReply ?? this.newReply,
    reservedBed: reservedBed ?? this.reservedBed,
    recommended: recommended ?? this.recommended,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'stayRequestId': stayRequestId,
    'fromShelterId': fromShelterId,
    'fromName': fromName,
    'toShelterId': toShelterId,
    'toName': toName,
    'reason': reason,
    'status': status.name,
    'report': report,
    'currentRemarks': currentRemarks,
    'adminNote': adminNote,
    'newReply': newReply,
    'reservedBed': reservedBed,
    'recommended': recommended,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory ShelterTransfer.fromJson(Map<String, dynamic> j) => ShelterTransfer(
    id: j['id'] as String,
    userId: j['userId'] as String,
    userName: j['userName'] as String? ?? '',
    stayRequestId: j['stayRequestId'] as String,
    fromShelterId: j['fromShelterId'] as String,
    fromName: j['fromName'] as String? ?? '',
    toShelterId: j['toShelterId'] as String,
    toName: j['toName'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
    status: enumByName(
      TransferStatus.values,
      j['status'],
      TransferStatus.pendingCurrent,
    ),
    report: j['report'] as String?,
    currentRemarks: j['currentRemarks'] as String?,
    adminNote: j['adminNote'] as String?,
    newReply: j['newReply'] as String?,
    reservedBed: j['reservedBed'] as String?,
    recommended: j['recommended'] as bool? ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
  );
}
