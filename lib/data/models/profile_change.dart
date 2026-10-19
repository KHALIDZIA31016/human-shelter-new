import 'enums.dart';

/// Profile fields a person can ask their shelter to change, in display order.
const kProfileFields = <String, String>{
  'name': 'Full name',
  'age': 'Age',
  'phone': 'Phone',
  'email': 'Email',
  'city': 'City',
  'address': 'Location',
};

/// A registered resident asks their shelter to change profile details. Only
/// when the shelter approves is the profile updated.
class ProfileChange {
  ProfileChange({
    required this.id,
    required this.registrationId,
    required this.userId,
    required this.userName,
    required this.shelterId,
    required this.shelterName,
    required this.before,
    required this.after,
    this.status = ReviewStatus.pending,
    DateTime? createdAt,
    this.decidedAt,
    this.rejectReason,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String registrationId;

  /// Device id of the person asking.
  final String userId;
  final String userName;
  final String shelterId;
  final String shelterName;

  /// Field key (see [kProfileFields]) -> value, as it is now / as requested.
  final Map<String, String> before;
  final Map<String, String> after;
  final ReviewStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? rejectReason;

  /// Only the fields that really differ.
  Map<String, String> get changed => {
    for (final k in kProfileFields.keys)
      if ((after[k] ?? '') != (before[k] ?? '')) k: after[k] ?? '',
  };

  ProfileChange copyWith({
    ReviewStatus? status,
    DateTime? decidedAt,
    String? rejectReason,
  }) => ProfileChange(
    id: id,
    registrationId: registrationId,
    userId: userId,
    userName: userName,
    shelterId: shelterId,
    shelterName: shelterName,
    before: before,
    after: after,
    status: status ?? this.status,
    createdAt: createdAt,
    decidedAt: decidedAt ?? this.decidedAt,
    rejectReason: rejectReason ?? this.rejectReason,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'registrationId': registrationId,
    'userId': userId,
    'userName': userName,
    'shelterId': shelterId,
    'shelterName': shelterName,
    'before': before,
    'after': after,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'decidedAt': decidedAt?.toIso8601String(),
    'rejectReason': rejectReason,
  };

  factory ProfileChange.fromJson(Map<String, dynamic> j) => ProfileChange(
    id: j['id'] as String,
    registrationId: j['registrationId'] as String,
    userId: j['userId'] as String,
    userName: j['userName'] as String? ?? '',
    shelterId: j['shelterId'] as String,
    shelterName: j['shelterName'] as String? ?? '',
    before: Map<String, String>.from(j['before'] as Map? ?? const {}),
    after: Map<String, String>.from(j['after'] as Map? ?? const {}),
    status: enumByName(ReviewStatus.values, j['status'], ReviewStatus.pending),
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    decidedAt: DateTime.tryParse(j['decidedAt'] as String? ?? ''),
    rejectReason: j['rejectReason'] as String?,
  );
}
