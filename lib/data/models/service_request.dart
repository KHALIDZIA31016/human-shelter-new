import 'enums.dart';

/// A request sent to a shelter: a stay (bed), a meal, or a food donation
/// offered by a restaurant / company. These go to the shelter, never admin.
class ServiceRequest {
  ServiceRequest({
    required this.id,
    required this.type,
    required this.requesterId,
    required this.requesterName,
    required this.phone,
    required this.targetId,
    required this.targetName,
    this.people = 1,
    this.meal,
    this.neededDate,
    this.message = '',
    this.status = ReviewStatus.pending,
    DateTime? createdAt,
    this.decidedAt,
    this.rejectReason,
    this.arrivalAt,
    this.contactPerson,
    this.decisionNote,
    this.approvedPeople,
    this.bedLabel,
    this.category,
    this.items = const [],
    this.allottedUntil,
    this.fulfilledAt,
    this.closedAt,
    this.closeNotice,
    this.endedAt,
    this.endReason,
    this.arrivalAlertedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final RequestType type;

  /// Device id of the sender (all decision notifications go here).
  final String requesterId;
  final String requesterName;
  final String phone;

  /// Registration id of the shelter that must decide.
  final String targetId;
  final String targetName;
  final int people;
  final MealType? meal;
  final DateTime? neededDate;
  final String message;
  final ReviewStatus status;
  final DateTime createdAt;

  // Decision (filled by the shelter)
  final DateTime? decidedAt;
  final String? rejectReason;
  final DateTime? arrivalAt;
  final String? contactPerson;
  final String? decisionNote;
  final int? approvedPeople;
  final String? bedLabel;

  /// Set for [RequestType.help]: what kind of help, and which items.
  final HelpCategory? category;
  final List<String> items;

  /// Stay allotment end, set by the shelter on approval.
  final DateTime? allottedUntil;

  /// Set when the shelter marks the order as delivered / done.
  final DateTime? fulfilledAt;

  /// Set when the shelter closed the order because the user did not come.
  final DateTime? closedAt;
  final String? closeNotice;

  /// Set when a stay ended: user withdrew or was moved to another shelter.
  final DateTime? endedAt;
  final String? endReason;

  /// Set once the shelter was alerted that the arrival time is up.
  final DateTime? arrivalAlertedAt;

  /// Where this request is in its life, for the status screen.
  VisitState get visitState {
    switch (status) {
      case ReviewStatus.pending:
        return VisitState.pending;
      case ReviewStatus.rejected:
        return VisitState.rejected;
      case ReviewStatus.cancelled:
        return VisitState.cancelled;
      case ReviewStatus.approved:
        if (endedAt != null) return VisitState.ended;
        if (fulfilledAt != null) {
          return type == RequestType.stay
              ? VisitState.registered
              : VisitState.delivered;
        }
        if (closedAt != null) return VisitState.missed;
        final at = arrivalAt;
        final now = DateTime.now();
        if (at == null || now.isBefore(at)) return VisitState.upcoming;
        if (now.isBefore(at.add(kNoShowGrace))) return VisitState.due;
        return VisitState.delayed;
    }
  }

  /// True when the shelter may close the order as a no-show.
  bool get canCloseNoShow => visitState == VisitState.delayed;

  /// Category used for the per-24h limit and for grouping repeats.
  /// Donations are offers from partners, so they are not limited.
  HelpCategory? get helpCategory => switch (type) {
    RequestType.help => category,
    RequestType.food => HelpCategory.food,
    RequestType.stay => HelpCategory.shelter,
    RequestType.donation => null,
  };

  bool get isPending => status == ReviewStatus.pending;

  /// Short human title, e.g. "Lunch for 3" / "Stay for 2".
  String get title => switch (type) {
    RequestType.stay => 'Stay for $people',
    RequestType.food => '${meal?.label ?? 'Meal'} for $people',
    RequestType.donation => '${meal?.label ?? 'Meal'} · $people meals',
    RequestType.help =>
      items.isEmpty
          ? (category?.label ?? 'Help')
          : '${category?.label ?? 'Help'}: ${items.join(', ')}',
  };

  ServiceRequest copyWith({
    ReviewStatus? status,
    DateTime? decidedAt,
    String? rejectReason,
    DateTime? arrivalAt,
    String? contactPerson,
    String? decisionNote,
    int? approvedPeople,
    String? bedLabel,
    DateTime? allottedUntil,
    DateTime? fulfilledAt,
    DateTime? closedAt,
    String? closeNotice,
    DateTime? endedAt,
    String? endReason,
    DateTime? arrivalAlertedAt,
  }) => ServiceRequest(
    id: id,
    type: type,
    requesterId: requesterId,
    requesterName: requesterName,
    phone: phone,
    targetId: targetId,
    targetName: targetName,
    people: people,
    meal: meal,
    neededDate: neededDate,
    message: message,
    status: status ?? this.status,
    createdAt: createdAt,
    decidedAt: decidedAt ?? this.decidedAt,
    rejectReason: rejectReason ?? this.rejectReason,
    arrivalAt: arrivalAt ?? this.arrivalAt,
    contactPerson: contactPerson ?? this.contactPerson,
    decisionNote: decisionNote ?? this.decisionNote,
    approvedPeople: approvedPeople ?? this.approvedPeople,
    bedLabel: bedLabel ?? this.bedLabel,
    category: category,
    items: items,
    allottedUntil: allottedUntil ?? this.allottedUntil,
    fulfilledAt: fulfilledAt ?? this.fulfilledAt,
    closedAt: closedAt ?? this.closedAt,
    closeNotice: closeNotice ?? this.closeNotice,
    endedAt: endedAt ?? this.endedAt,
    endReason: endReason ?? this.endReason,
    arrivalAlertedAt: arrivalAlertedAt ?? this.arrivalAlertedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'requesterId': requesterId,
    'requesterName': requesterName,
    'phone': phone,
    'targetId': targetId,
    'targetName': targetName,
    'people': people,
    'meal': meal?.name,
    'neededDate': neededDate?.toIso8601String(),
    'message': message,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'decidedAt': decidedAt?.toIso8601String(),
    'rejectReason': rejectReason,
    'arrivalAt': arrivalAt?.toIso8601String(),
    'contactPerson': contactPerson,
    'decisionNote': decisionNote,
    'approvedPeople': approvedPeople,
    'bedLabel': bedLabel,
    'category': category?.name,
    'items': items,
    'allottedUntil': allottedUntil?.toIso8601String(),
    'fulfilledAt': fulfilledAt?.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'closeNotice': closeNotice,
    'endedAt': endedAt?.toIso8601String(),
    'endReason': endReason,
    'arrivalAlertedAt': arrivalAlertedAt?.toIso8601String(),
  };

  factory ServiceRequest.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) => DateTime.tryParse(j[k] as String? ?? '');
    return ServiceRequest(
      id: j['id'] as String,
      type: enumByName(RequestType.values, j['type'], RequestType.food),
      requesterId: j['requesterId'] as String,
      requesterName: j['requesterName'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      targetId: j['targetId'] as String,
      targetName: j['targetName'] as String? ?? '',
      people: j['people'] as int? ?? 1,
      meal: j['meal'] == null
          ? null
          : enumByName(MealType.values, j['meal'], MealType.lunch),
      neededDate: d('neededDate'),
      message: j['message'] as String? ?? '',
      status: enumByName(
        ReviewStatus.values,
        j['status'],
        ReviewStatus.pending,
      ),
      createdAt: d('createdAt'),
      decidedAt: d('decidedAt'),
      rejectReason: j['rejectReason'] as String?,
      arrivalAt: d('arrivalAt'),
      contactPerson: j['contactPerson'] as String?,
      decisionNote: j['decisionNote'] as String?,
      approvedPeople: j['approvedPeople'] as int?,
      bedLabel: j['bedLabel'] as String?,
      category: j['category'] == null
          ? null
          : enumByName(HelpCategory.values, j['category'], HelpCategory.food),
      items: (j['items'] as List?)?.cast<String>() ?? const [],
      allottedUntil: d('allottedUntil'),
      fulfilledAt: d('fulfilledAt'),
      closedAt: d('closedAt'),
      closeNotice: j['closeNotice'] as String?,
      endedAt: d('endedAt'),
      endReason: j['endReason'] as String?,
      arrivalAlertedAt: d('arrivalAlertedAt'),
    );
  }
}
