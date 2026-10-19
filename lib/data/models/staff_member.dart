enum StaffState { upcoming, current, former }

/// A person who works (or worked) at a shelter.
class StaffMember {
  StaffMember({
    required this.id,
    required this.shelterId,
    required this.name,
    required this.role,
    this.duties = '',
    this.salary = 0,
    this.shift = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.emergencyContact = '',
    this.imageUrl,
    this.notes = '',
    required this.joinedAt,
    this.leftAt,
    this.leaveReason = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String shelterId;
  final String name;

  /// Job title, e.g. "Cook" or "Night warden".
  final String role;

  /// What the person does / did day to day.
  final String duties;

  /// Monthly salary (Rs).
  final int salary;
  final String shift;
  final String phone;
  final String email;
  final String address;
  final String emergencyContact;
  final String? imageUrl;
  final String notes;

  /// Start date. In the future = new hire who has not started yet.
  final DateTime joinedAt;

  /// Last working day, if the person has left (or is leaving).
  final DateTime? leftAt;
  final String leaveReason;
  final DateTime createdAt;

  StaffState get state {
    final now = DateTime.now();
    if (leftAt != null && !leftAt!.isAfter(now)) return StaffState.former;
    if (joinedAt.isAfter(now)) return StaffState.upcoming;
    return StaffState.current;
  }

  StaffMember copyWith({
    String? name,
    String? role,
    String? duties,
    int? salary,
    String? shift,
    String? phone,
    String? email,
    String? address,
    String? emergencyContact,
    String? imageUrl,
    String? notes,
    DateTime? joinedAt,
    DateTime? leftAt,
    bool clearLeft = false,
    String? leaveReason,
  }) => StaffMember(
    id: id,
    shelterId: shelterId,
    name: name ?? this.name,
    role: role ?? this.role,
    duties: duties ?? this.duties,
    salary: salary ?? this.salary,
    shift: shift ?? this.shift,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    emergencyContact: emergencyContact ?? this.emergencyContact,
    imageUrl: imageUrl ?? this.imageUrl,
    notes: notes ?? this.notes,
    joinedAt: joinedAt ?? this.joinedAt,
    leftAt: clearLeft ? null : (leftAt ?? this.leftAt),
    leaveReason: clearLeft ? '' : (leaveReason ?? this.leaveReason),
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'shelterId': shelterId,
    'name': name,
    'role': role,
    'duties': duties,
    'salary': salary,
    'shift': shift,
    'phone': phone,
    'email': email,
    'address': address,
    'emergencyContact': emergencyContact,
    'imageUrl': imageUrl,
    'notes': notes,
    'joinedAt': joinedAt.toIso8601String(),
    'leftAt': leftAt?.toIso8601String(),
    'leaveReason': leaveReason,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    id: j['id'] as String,
    shelterId: j['shelterId'] as String? ?? '',
    name: j['name'] as String? ?? '',
    role: j['role'] as String? ?? '',
    duties: j['duties'] as String? ?? '',
    salary: j['salary'] as int? ?? 0,
    shift: j['shift'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    email: j['email'] as String? ?? '',
    address: j['address'] as String? ?? '',
    emergencyContact: j['emergencyContact'] as String? ?? '',
    imageUrl: j['imageUrl'] as String?,
    notes: j['notes'] as String? ?? '',
    joinedAt:
        DateTime.tryParse(j['joinedAt'] as String? ?? '') ?? DateTime.now(),
    leftAt: DateTime.tryParse(j['leftAt'] as String? ?? ''),
    leaveReason: j['leaveReason'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
  );
}

extension StaffStateX on StaffState {
  String get label => switch (this) {
    StaffState.upcoming => 'Joining soon',
    StaffState.current => 'Working',
    StaffState.former => 'Left',
  };
}
