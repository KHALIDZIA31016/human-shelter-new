import 'enums.dart';

/// A sign-up awaiting (or past) admin review. Covers both an individual
/// asking for help and partners (shelter / restaurant / company).
/// Approved shelters double as the shelter directory.
class Registration {
  Registration({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.name,
    this.orgName,
    required this.phone,
    this.email = '',
    this.imageUrl,
    this.hours = '',
    this.age,
    this.services = const [],
    required this.city,
    required this.address,
    this.needs = const [],
    this.notes = '',
    this.familyMembers = 1,
    this.totalBeds = 0,
    this.availableBeds = 0,
    this.status = ReviewStatus.pending,
    this.rejectReason,
    DateTime? createdAt,
    this.reviewedAt,
    this.suspended = false,
    this.suspendReason,
    this.suspendedAt,
    this.appealText,
    this.appealAt,
    this.appealResponse,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;

  /// Device that submitted the registration.
  final String ownerId;
  final RegistrationKind kind;

  /// Person name (individual) or contact person (partner).
  final String name;
  final String? orgName;
  final String phone;
  final String email;

  /// Optional shelter photo; a generated cover is shown when absent.
  final String? imageUrl;

  /// Shelter-editable profile: opening hours and the help categories it offers.
  final String hours;

  /// Optional age of the person (shown to shelters and admin in reports).
  final int? age;

  final List<String> services;
  final String city;
  final String address;
  final List<String> needs;
  final String notes;
  final int familyMembers;
  final int totalBeds;
  final int availableBeds;
  final ReviewStatus status;
  final String? rejectReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  /// Admin suspended this account: login is blocked, all data is kept.
  final bool suspended;

  /// The violation the admin named when suspending.
  final String? suspendReason;
  final DateTime? suspendedAt;

  /// Appeal written by the account owner; waiting for admin while set.
  final String? appealText;
  final DateTime? appealAt;

  /// Admin's reply when an appeal was turned down.
  final String? appealResponse;

  /// An appeal was sent and the admin has not reviewed it yet.
  bool get appealPending => suspended && (appealText ?? '').isNotEmpty;

  bool get isPartner => kind.isPartner;
  bool get isApproved => status == ReviewStatus.approved;
  String get displayName =>
      (isPartner && (orgName?.isNotEmpty ?? false)) ? orgName! : name;

  /// One-line "who wants what" used in admin notifications.
  String get adminSummary => isPartner
      ? '$displayName (${kind.label}) from $city wants to join as a partner. '
            'Contact: $name, $phone.'
      : '$name from $city registered for personal help'
            '${needs.isEmpty ? '' : ' (${needs.join(', ')})'}. Phone: $phone.';

  static const _keep = Object();

  Registration copyWith({
    ReviewStatus? status,
    String? rejectReason,
    DateTime? reviewedAt,
    int? totalBeds,
    int? availableBeds,
    String? name,
    String? phone,
    String? email,
    String? imageUrl,
    String? city,
    String? address,
    String? notes,
    String? hours,
    List<String>? services,
    int? age,
    int? familyMembers,
    bool? suspended,
    Object? suspendReason = _keep,
    Object? suspendedAt = _keep,
    Object? appealText = _keep,
    Object? appealAt = _keep,
    Object? appealResponse = _keep,
  }) => Registration(
    id: id,
    ownerId: ownerId,
    kind: kind,
    name: name ?? this.name,
    orgName: orgName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    imageUrl: imageUrl ?? this.imageUrl,
    hours: hours ?? this.hours,
    age: age ?? this.age,
    services: services ?? this.services,
    city: city ?? this.city,
    address: address ?? this.address,
    needs: needs,
    notes: notes ?? this.notes,
    familyMembers: familyMembers ?? this.familyMembers,
    totalBeds: totalBeds ?? this.totalBeds,
    availableBeds: availableBeds ?? this.availableBeds,
    status: status ?? this.status,
    rejectReason: rejectReason ?? this.rejectReason,
    createdAt: createdAt,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    suspended: suspended ?? this.suspended,
    suspendReason: identical(suspendReason, _keep)
        ? this.suspendReason
        : suspendReason as String?,
    suspendedAt: identical(suspendedAt, _keep)
        ? this.suspendedAt
        : suspendedAt as DateTime?,
    appealText: identical(appealText, _keep)
        ? this.appealText
        : appealText as String?,
    appealAt: identical(appealAt, _keep)
        ? this.appealAt
        : appealAt as DateTime?,
    appealResponse: identical(appealResponse, _keep)
        ? this.appealResponse
        : appealResponse as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'kind': kind.name,
    'name': name,
    'orgName': orgName,
    'phone': phone,
    'email': email,
    'imageUrl': imageUrl,
    'hours': hours,
    'age': age,
    'services': services,
    'city': city,
    'address': address,
    'needs': needs,
    'notes': notes,
    'familyMembers': familyMembers,
    'totalBeds': totalBeds,
    'availableBeds': availableBeds,
    'status': status.name,
    'rejectReason': rejectReason,
    'createdAt': createdAt.toIso8601String(),
    'reviewedAt': reviewedAt?.toIso8601String(),
    'suspended': suspended,
    'suspendReason': suspendReason,
    'suspendedAt': suspendedAt?.toIso8601String(),
    'appealText': appealText,
    'appealAt': appealAt?.toIso8601String(),
    'appealResponse': appealResponse,
  };

  factory Registration.fromJson(Map<String, dynamic> j) => Registration(
    id: j['id'] as String,
    ownerId: j['ownerId'] as String,
    kind: enumByName(
      RegistrationKind.values,
      j['kind'],
      RegistrationKind.individual,
    ),
    name: j['name'] as String? ?? '',
    orgName: j['orgName'] as String?,
    phone: j['phone'] as String? ?? '',
    email: j['email'] as String? ?? '',
    imageUrl: j['imageUrl'] as String?,
    hours: j['hours'] as String? ?? '',
    age: j['age'] as int?,
    services: (j['services'] as List?)?.cast<String>() ?? const [],
    city: j['city'] as String? ?? '',
    address: j['address'] as String? ?? '',
    needs: (j['needs'] as List?)?.cast<String>() ?? const [],
    notes: j['notes'] as String? ?? '',
    familyMembers: j['familyMembers'] as int? ?? 1,
    totalBeds: j['totalBeds'] as int? ?? 0,
    availableBeds: j['availableBeds'] as int? ?? 0,
    status: enumByName(ReviewStatus.values, j['status'], ReviewStatus.pending),
    rejectReason: j['rejectReason'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    reviewedAt: DateTime.tryParse(j['reviewedAt'] as String? ?? ''),
    suspended: j['suspended'] as bool? ?? false,
    suspendReason: j['suspendReason'] as String?,
    suspendedAt: DateTime.tryParse(j['suspendedAt'] as String? ?? ''),
    appealText: j['appealText'] as String?,
    appealAt: DateTime.tryParse(j['appealAt'] as String? ?? ''),
    appealResponse: j['appealResponse'] as String?,
  );
}
