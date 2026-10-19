enum RegistrationKind { individual, shelter, restaurant, company }

enum ReviewStatus { pending, approved, rejected, cancelled }

enum RequestType { stay, food, donation, help }

enum MealType { breakfast, lunch, dinner }

enum NotifKind {
  registration,
  request,
  decision,
  complaint,
  chat,
  transfer,
  system,
}

/// Shelter change: the current shelter reports to admin -> admin reviews and
/// picks the shelter -> that shelter confirms a bed -> the user submits the
/// new form and is moved.
enum TransferStatus {
  pendingCurrent,
  pendingAdmin,
  pendingNew,
  confirmed,
  completed,
  rejected,
  cancelled,
}

/// open -> verifying (admin asked the shelter) -> shelterReplied -> upheld / dismissed.
enum ComplaintStatus { open, verifying, shelterReplied, upheld, dismissed }

enum Persona { needy, partner, admin }

/// Life of a request as the user sees it on the status screen.
enum VisitState {
  pending,
  upcoming,
  due,
  delayed,
  delivered,
  registered,
  missed,
  ended,
  rejected,
  cancelled,
}

/// How long a shelter waits after the scheduled time before it may close
/// the order and give it to someone else.
const Duration kNoShowGrace = Duration(hours: 2);

extension VisitStateX on VisitState {
  String get label => switch (this) {
    VisitState.pending => 'Awaiting reply',
    VisitState.upcoming => 'Upcoming',
    VisitState.due => 'Ready now',
    VisitState.delayed => 'Delayed',
    VisitState.delivered => 'Delivered',
    VisitState.registered => 'Registered',
    VisitState.missed => 'Closed · missed',
    VisitState.ended => 'Ended',
    VisitState.rejected => 'Rejected',
    VisitState.cancelled => 'Cancelled',
  };
}

extension RegistrationKindX on RegistrationKind {
  bool get isPartner => this != RegistrationKind.individual;

  String get label => switch (this) {
    RegistrationKind.individual => 'Individual',
    RegistrationKind.shelter => 'Shelter',
    RegistrationKind.restaurant => 'Restaurant',
    RegistrationKind.company => 'Company',
  };
}

extension ReviewStatusX on ReviewStatus {
  String get label => switch (this) {
    ReviewStatus.pending => 'Pending',
    ReviewStatus.approved => 'Approved',
    ReviewStatus.rejected => 'Rejected',
    ReviewStatus.cancelled => 'Cancelled',
  };
}

extension RequestTypeX on RequestType {
  String get label => switch (this) {
    RequestType.stay => 'Shelter stay',
    RequestType.food => 'Food request',
    RequestType.donation => 'Food donation',
    RequestType.help => 'Help request',
  };

  /// What the shelter calls the person to meet / collect from.
  String get contactLabel => switch (this) {
    RequestType.stay => 'Meet / report to',
    RequestType.food => 'Collect food from',
    RequestType.donation => 'Deliver to',
    RequestType.help => 'Collect from',
  };

  String get whenLabel => switch (this) {
    RequestType.stay => 'Arrive on',
    RequestType.food => 'Come at',
    RequestType.donation => 'Deliver at',
    RequestType.help => 'Come at',
  };
}

extension MealTypeX on MealType {
  String get label => switch (this) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
  };
}

/// Kinds of help a person can ask a shelter for.
enum HelpCategory {
  food,
  clothes,
  education,
  shelter,
  hygiene,
  medical,
  utilities,
  technology,
  activities,
  financial,
  volunteer,
  transport,
}

/// Max requests per person, per shelter, per category, inside [kLimitWindow].
const int kCategoryLimit = 2;
const Duration kLimitWindow = Duration(hours: 24);

extension HelpCategoryX on HelpCategory {
  String get label => switch (this) {
    HelpCategory.food => 'Food',
    HelpCategory.clothes => 'Clothes',
    HelpCategory.education => 'Education',
    HelpCategory.shelter => 'Shelter',
    HelpCategory.hygiene => 'Hygiene',
    HelpCategory.medical => 'Medical',
    HelpCategory.utilities => 'Utilities',
    HelpCategory.technology => 'Technology',
    HelpCategory.activities => 'Activities',
    HelpCategory.financial => 'Financial',
    HelpCategory.volunteer => 'Volunteer',
    HelpCategory.transport => 'Transport',
  };

  String get emoji => switch (this) {
    HelpCategory.food => '🍚',
    HelpCategory.clothes => '👕',
    HelpCategory.education => '📚',
    HelpCategory.shelter => '🛏️',
    HelpCategory.hygiene => '🧼',
    HelpCategory.medical => '🏥',
    HelpCategory.utilities => '💡',
    HelpCategory.technology => '🖥️',
    HelpCategory.activities => '⚽',
    HelpCategory.financial => '💰',
    HelpCategory.volunteer => '🤝',
    HelpCategory.transport => '🚐',
  };

  /// What can be asked for in this category (multi-select).
  List<String> get items => switch (this) {
    HelpCategory.food => ['Ration', 'Rice', 'Flour', 'Milk', 'Fruits', 'Meals'],
    HelpCategory.clothes => ['Seasonal clothes', 'Shoes', 'Uniforms'],
    HelpCategory.education => ['Books', 'Stationery', 'School bags', 'Fees'],
    HelpCategory.shelter => ['Beds', 'Mattresses', 'Blankets', 'Furniture'],
    HelpCategory.hygiene => ['Soap', 'Shampoo', 'Toothpaste', 'Sanitary items'],
    HelpCategory.medical => [
      'Medicines',
      'Doctor visit',
      'Basic medical supplies',
    ],
    HelpCategory.utilities => ['Electricity bill', 'Gas bill', 'Water bill'],
    HelpCategory.technology => [
      'Computer',
      'Tablet',
      'Internet',
      'Educational equipment',
    ],
    HelpCategory.activities => [
      'Sports equipment',
      'Toys',
      'Recreational activities',
    ],
    HelpCategory.financial => ['General fund (most urgent needs)'],
    HelpCategory.volunteer => [
      'Teaching',
      'Mentoring',
      'Events',
      'Maintenance',
      'Skills training',
    ],
    HelpCategory.transport => [
      'School transport',
      'Event transport',
      'Medical transport',
    ],
  };
}

extension TransferStatusX on TransferStatus {
  String get label => switch (this) {
    TransferStatus.pendingCurrent => 'Shelter preparing report',
    TransferStatus.pendingAdmin => 'Admin reviewing',
    TransferStatus.pendingNew => 'New shelter confirming a bed',
    TransferStatus.confirmed => 'Bed confirmed · submit your form',
    TransferStatus.completed => 'Moved',
    TransferStatus.rejected => 'Rejected',
    TransferStatus.cancelled => 'Cancelled',
  };

  bool get isOpen =>
      this == TransferStatus.pendingCurrent ||
      this == TransferStatus.pendingAdmin ||
      this == TransferStatus.pendingNew ||
      this == TransferStatus.confirmed;
}

extension ComplaintStatusX on ComplaintStatus {
  String get label => switch (this) {
    ComplaintStatus.open => 'Submitted',
    ComplaintStatus.verifying => 'Verifying with shelter',
    ComplaintStatus.shelterReplied => 'Shelter replied',
    ComplaintStatus.upheld => 'Upheld',
    ComplaintStatus.dismissed => 'Dismissed',
  };

  bool get isClosed =>
      this == ComplaintStatus.upheld || this == ComplaintStatus.dismissed;
}

/// Safe enum decoding for persisted JSON.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
