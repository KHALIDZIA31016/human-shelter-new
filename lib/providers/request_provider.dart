import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../data/local/local_store.dart';
import '../data/models/approval_report.dart';
import '../data/models/enums.dart';
import '../data/models/registration.dart';
import '../data/models/service_request.dart';
import 'notification_provider.dart';
import 'registration_provider.dart';

/// Reject reason written when the user cancels at the check-in prompt.
const String kUserCancelledNote = 'Cancelled by user at check-in';

/// How long a user must wait to apply again after cancelling a check-in.
const Duration kReapplyAfterCancel = Duration(hours: 1);

/// Details a shelter supplies when approving a request.
class Decision {
  const Decision({
    required this.arrivalAt,
    required this.contactPerson,
    this.note = '',
    this.approvedPeople,
    this.allottedUntil,
  });

  final DateTime arrivalAt;
  final String contactPerson;
  final String note;
  final int? approvedPeople;
  final DateTime? allottedUntil;
}

class RequestProvider extends ChangeNotifier {
  RequestProvider(this._store, this._notifs, this._registrations) {
    _items = _store.readList(_key).map(ServiceRequest.fromJson).toList();
    // Tell shelters when an approved arrival time is up.
    _arrivalTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _alertDueArrivals(),
    );
  }

  Timer? _arrivalTimer;
  bool _alerting = false;

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    super.dispose();
  }

  /// One alert per approved request whose arrival time has passed and who
  /// has not been checked in yet: "time is up, check them in".
  Future<void> _alertDueArrivals() async {
    if (_alerting) return;
    final now = DateTime.now();
    final due = _items
        .where(
          (r) =>
              r.status == ReviewStatus.approved &&
              r.arrivalAt != null &&
              !r.arrivalAt!.isAfter(now) &&
              r.arrivalAlertedAt == null &&
              r.fulfilledAt == null &&
              r.closedAt == null &&
              r.endedAt == null,
        )
        .toList();
    if (due.isEmpty) return;
    _alerting = true;
    try {
      for (final r in due) {
        _replace(r.copyWith(arrivalAlertedAt: now));
      }
      await _persist();
      for (final r in due) {
        await _notifs.push(
          to: r.targetId,
          title: 'Time is up · check in ${r.requesterName}',
          body:
              '${r.requesterName} was due at ${fmtDateTime(r.arrivalAt!)} '
              '(${r.title}). Open the request and tap Delivered to check '
              'them in.',
          kind: NotifKind.request,
          refId: r.id,
        );
      }
    } finally {
      _alerting = false;
    }
  }

  static const _key = 'requests_v1';

  final LocalStore _store;
  final NotificationProvider _notifs;
  final RegistrationProvider _registrations;
  List<ServiceRequest> _items = [];

  // ---- queries -----------------------------------------------------------

  List<ServiceRequest> get all =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  ServiceRequest? byId(String? id) {
    for (final r in _items) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<ServiceRequest> sentBy(String deviceId) =>
      all.where((r) => r.requesterId == deviceId).toList();

  List<ServiceRequest> sentTo(String targetId) =>
      all.where((r) => r.targetId == targetId).toList();

  /// People currently placed in a shelter (sum of approved stay requests).
  int enrolledAt(String shelterId) => _items
      .where(
        (r) =>
            r.targetId == shelterId &&
            r.type == RequestType.stay &&
            r.status == ReviewStatus.approved &&
            r.fulfilledAt != null &&
            r.closedAt == null &&
            r.endedAt == null &&
            (r.allottedUntil == null ||
                r.allottedUntil!.isAfter(DateTime.now())),
      )
      .fold(0, (sum, r) => sum + (r.approvedPeople ?? r.people));

  /// A person's own visits (meals, stays, help), newest first.
  List<ServiceRequest> visitsOf(String deviceId) =>
      sentBy(deviceId).where((r) => r.type != RequestType.donation).toList();

  /// Current stay of this person: only once the shelter has checked them in.
  ServiceRequest? activeStay(String deviceId) {
    final s = awaitingStay(deviceId, checkedIn: true);
    return s;
  }

  /// Set while the person is on hold: the arrival time they were given has
  /// passed and the shelter has not checked them in.
  ServiceRequest? frozenBy(String deviceId) {
    final s = awaitingStay(deviceId);
    final at = s?.arrivalAt;
    return (s != null && at != null && !at.isAfter(DateTime.now())) ? s : null;
  }

  /// The stay a person can chat about: approved, whether or not the arrival
  /// time has passed or they were checked in yet.
  ServiceRequest? chatStay(String deviceId) =>
      activeStay(deviceId) ?? awaitingStay(deviceId);

  /// People a shelter can chat with: checked-in residents plus approved
  /// people who are still on their way.
  List<ServiceRequest> chatPartnersOf(String shelterId) {
    final out = residentsOf(shelterId);
    final seen = {for (final r in out) r.requesterId};
    for (final r in all) {
      if (r.targetId == shelterId &&
          r.type == RequestType.stay &&
          r.status == ReviewStatus.approved &&
          r.closedAt == null &&
          r.endedAt == null &&
          seen.add(r.requesterId)) {
        out.add(r);
      }
    }
    return out;
  }

  /// An approved stay the person has not arrived at yet (not checked in).
  ServiceRequest? awaitingStay(String deviceId, {bool checkedIn = false}) {
    for (final r in sentBy(deviceId)) {
      if (r.type == RequestType.stay &&
          r.status == ReviewStatus.approved &&
          (r.fulfilledAt != null) == checkedIn &&
          r.closedAt == null &&
          r.endedAt == null &&
          (r.allottedUntil == null ||
              r.allottedUntil!.isAfter(DateTime.now()))) {
        return r;
      }
    }
    return null;
  }

  /// Requests this person already sent to [shelterId] for [c] in the last 24h.
  List<ServiceRequest> recentFor(
    String requesterId,
    String shelterId,
    HelpCategory c,
  ) {
    final since = DateTime.now().subtract(kLimitWindow);
    return _items
        .where(
          (r) =>
              r.requesterId == requesterId &&
              r.targetId == shelterId &&
              r.helpCategory == c &&
              r.createdAt.isAfter(since),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// When the next request in this category becomes possible, or null if free.
  DateTime? nextSlot(String requesterId, String shelterId, HelpCategory c) {
    final recent = recentFor(requesterId, shelterId, c);
    if (recent.length < kCategoryLimit) return null;
    return recent[recent.length - kCategoryLimit].createdAt.add(kLimitWindow);
  }

  int countWhere(ReviewStatus s) => _items.where((r) => r.status == s).length;

  // ---- commands ----------------------------------------------------------

  /// Returns an error message, or null on success.
  Future<String?> create(ServiceRequest r) async {
    final hold = frozenBy(r.requesterId);
    if (hold != null) {
      return 'Your account is on hold: you were due at ${hold.targetName} '
          'at ${fmtDateTime(hold.arrivalAt!)} and are not checked in. '
          'Ask the shelter to check you in, then you can continue.';
    }
    final cat = r.helpCategory;
    if (cat != null) {
      final next = nextSlot(r.requesterId, r.targetId, cat);
      if (next != null) {
        return 'Limit reached: only $kCategoryLimit ${cat.label} requests to '
            '${r.targetName} are allowed per 24 hours. Try again after '
            '${fmtDateTime(next)}.';
      }
    }
    // Help requests may repeat; other types may not have a pending twin.
    final duplicate =
        r.type != RequestType.help &&
        _items.any(
          (e) =>
              e.isPending &&
              e.requesterId == r.requesterId &&
              e.targetId == r.targetId &&
              e.type == r.type &&
              (r.type == RequestType.stay ||
                  (e.meal == r.meal && e.neededDate == r.neededDate)),
        );
    if (duplicate) {
      return 'You already have a pending ${r.type.label.toLowerCase()} with this shelter.';
    }

    if (r.type == RequestType.stay) {
      final wait = reapplyAllowedAt(r.requesterId);
      if (wait != null) {
        return 'You cancelled a check-in. You can apply for a stay again '
            'after ${fmtDateTime(wait)}.';
      }
      final current = activeStay(r.requesterId);
      if (current != null) {
        return 'You are already registered at ${current.targetName}. '
            'Withdraw or request a shelter change first.';
      }
      final shelter = _registrations.byId(r.targetId);
      if (shelter == null || shelter.availableBeds < 1) {
        return 'This shelter has no free beds right now.';
      }
    }

    _items.add(r);
    notifyListeners();
    await _persist();

    // To the shelter (NOT admin).
    await _notifs.push(
      to: r.targetId,
      title: 'New ${r.type.label.toLowerCase()}',
      body: _incomingBody(r),
      kind: NotifKind.request,
      refId: r.id,
    );
    // Admin only gets a heads-up; the shelter decides.
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'New ${r.type.label.toLowerCase()}',
      body:
          '${r.requesterName} → ${r.targetName}: ${r.title}. '
          'The shelter will decide.',
      kind: NotifKind.request,
      refId: r.id,
    );
    await _notifs.push(
      to: r.requesterId,
      title: 'Request sent',
      body:
          '${r.type.label} (${r.title}) was sent to ${r.targetName}. '
          'You will be notified when they respond.',
      kind: NotifKind.request,
      refId: r.id,
    );
    return null;
  }

  Future<void> cancel(String id) async {
    final r = byId(id);
    if (r == null || !r.isPending) return;
    _replace(
      r.copyWith(status: ReviewStatus.cancelled, decidedAt: DateTime.now()),
    );
    await _persist();
    await _notifs.push(
      to: r.targetId,
      title: 'Request cancelled',
      body: '${r.requesterName} cancelled ${r.title}.',
      kind: NotifKind.request,
      refId: r.id,
    );
  }

  /// Returns an error message, or null on success.
  Future<String?> approve(String id, Decision d) async {
    final r = byId(id);
    if (r == null || !r.isPending) return 'This request was already handled.';

    String? bed;
    if (r.type == RequestType.stay) {
      bed = await _registrations.consumeBed(r.targetId);
      if (bed == null)
        return 'No free bed left. Reject the request with a reason instead.';
    }

    final approved = r.copyWith(
      status: ReviewStatus.approved,
      decidedAt: DateTime.now(),
      arrivalAt: d.arrivalAt,
      contactPerson: d.contactPerson,
      decisionNote: d.note,
      approvedPeople: d.approvedPeople ?? r.people,
      bedLabel: bed,
      allottedUntil: d.allottedUntil,
    );
    _replace(approved);
    await _persist();

    final detail = _approvedBody(approved);
    await _notifs.push(
      to: r.requesterId,
      title: '${r.type.label} approved ✅',
      body: detail,
      kind: NotifKind.decision,
      refId: r.id,
    );
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: r.type == RequestType.stay
          ? 'Approval report · ${r.requesterName}'
          : 'Approved by ${r.targetName}',
      body: r.type == RequestType.stay
          ? approvalReportText(
              approved,
              _registrations.individualOf(r.requesterId),
            )
          : '${r.requesterName} · ${r.title}. $detail',
      kind: NotifKind.decision,
      refId: r.id,
    );
    return null;
  }

  /// When the user may apply for a stay again after cancelling a check-in,
  /// or null when no cooldown applies.
  DateTime? reapplyAllowedAt(String deviceId) {
    for (final r in sentBy(deviceId)) {
      if (r.type == RequestType.stay &&
          r.status == ReviewStatus.rejected &&
          r.rejectReason == kUserCancelledNote) {
        final at = (r.decidedAt ?? r.createdAt).add(kReapplyAfterCancel);
        return at.isAfter(DateTime.now()) ? at : null;
      }
    }
    return null;
  }

  /// User confirms they arrived: the stay becomes "Registered" for both
  /// the user and the shelter.
  Future<String?> userCheckIn(String id) async {
    final r = byId(id);
    if (r == null ||
        r.type != RequestType.stay ||
        r.status != ReviewStatus.approved ||
        r.fulfilledAt != null ||
        r.closedAt != null ||
        r.endedAt != null) {
      return 'This check-in is no longer available.';
    }
    _replace(r.copyWith(fulfilledAt: DateTime.now()));
    await _persist();
    await _notifs.push(
      to: r.targetId,
      title: '${r.requesterName} checked in ✅',
      body: '${r.requesterName} confirmed arrival. Registration is complete.',
      kind: NotifKind.request,
      refId: r.id,
    );
    await _notifs.push(
      to: r.requesterId,
      title: 'Registration complete ✅',
      body: 'You are registered at ${r.targetName}. Welcome!',
      kind: NotifKind.decision,
      refId: r.id,
    );
    return null;
  }

  /// User declines the check-in: the request turns Rejected, the bed is
  /// freed and a one-hour wait applies before the next application.
  Future<String?> userCancelCheckIn(String id) async {
    final r = byId(id);
    if (r == null ||
        r.type != RequestType.stay ||
        r.status != ReviewStatus.approved ||
        r.fulfilledAt != null ||
        r.closedAt != null ||
        r.endedAt != null) {
      return 'This check-in is no longer available.';
    }
    _replace(
      r.copyWith(
        status: ReviewStatus.rejected,
        decidedAt: DateTime.now(),
        rejectReason: kUserCancelledNote,
      ),
    );
    await _registrations.releaseBed(r.targetId);
    await _persist();
    await _notifs.push(
      to: r.targetId,
      title: '${r.requesterName} cancelled check-in',
      body:
          '${r.requesterName} declined the check-in. The request is now '
          'rejected and the bed is free again.',
      kind: NotifKind.request,
      refId: r.id,
    );
    await _notifs.push(
      to: r.requesterId,
      title: 'Check-in cancelled',
      body:
          'Your request at ${r.targetName} was cancelled. You can apply '
          'again in 1 hour.',
      kind: NotifKind.decision,
      refId: r.id,
    );
    return null;
  }

  /// After approval the shelter may change only the check-in time and the
  /// person allowed to check in. Returns an error message, or null.
  Future<String?> editApproval(
    String id, {
    required DateTime arrivalAt,
    required String contactPerson,
  }) async {
    final r = byId(id);
    if (r == null ||
        r.status != ReviewStatus.approved ||
        r.fulfilledAt != null ||
        r.closedAt != null ||
        r.endedAt != null) {
      return 'This request can no longer be edited.';
    }
    final updated = r.copyWith(
      arrivalAt: arrivalAt,
      contactPerson: contactPerson.trim(),
    );
    _replace(updated);
    await _persist();
    await _notifs.push(
      to: r.requesterId,
      title: 'Check-in details updated',
      body:
          '${r.targetName} changed your check-in: '
          '${fmtDateTime(arrivalAt)}, ask for ${contactPerson.trim()}.',
      kind: NotifKind.decision,
      refId: r.id,
    );
    return null;
  }

  /// A stay application still waiting for the shelter's answer.
  ServiceRequest? pendingStay(String deviceId) {
    for (final r in sentBy(deviceId)) {
      if (r.type == RequestType.stay && r.status == ReviewStatus.pending) {
        return r;
      }
    }
    return null;
  }

  /// Active stays at a shelter (its current residents), one per person.
  List<ServiceRequest> residentsOf(String shelterId) {
    final seen = <String>{};
    final out = <ServiceRequest>[];
    for (final r in all) {
      if (r.targetId == shelterId &&
          r.type == RequestType.stay &&
          r.status == ReviewStatus.approved &&
          r.fulfilledAt != null &&
          r.closedAt == null &&
          r.endedAt == null &&
          (r.allottedUntil == null ||
              r.allottedUntil!.isAfter(DateTime.now())) &&
          seen.add(r.requesterId)) {
        out.add(r);
      }
    }
    return out;
  }

  /// The stay that commits this person to a shelter other than [shelterId].
  ServiceRequest? commitmentBlock(String deviceId, String shelterId) {
    // Approved but not yet checked in still commits the person.
    final s = activeStay(deviceId) ?? awaitingStay(deviceId);
    return (s != null && s.targetId != shelterId) ? s : null;
  }

  /// A committed user tried to apply elsewhere: tell the admin and the
  /// current shelter (never the shelter they tried to apply to).
  Future<void> reportCommitmentConflict({
    required ServiceRequest current,
    required String userName,
    required String attemptedShelterName,
  }) async {
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'Resident tried to register elsewhere',
      body:
          '$userName is registered at ${current.targetName} but tried to '
          'register at $attemptedShelterName. The request was blocked.',
      kind: NotifKind.request,
      refId: current.id,
    );
    await _notifs.push(
      to: current.targetId,
      title: 'Admin notice: resident registering elsewhere',
      body:
          'Admin noticed that your registered resident $userName tried to '
          'register at another shelter. No action was taken; they were told '
          'to request a change through you.',
      kind: NotifKind.request,
      refId: current.id,
    );
  }

  /// User leaves their shelter. Frees the bed and tells the shelter.
  Future<String?> withdrawStay(String id, {String reason = ''}) async {
    final r = byId(id);
    if (r == null || r.type != RequestType.stay) return 'Stay not found.';
    if (r.status != ReviewStatus.approved || r.endedAt != null) {
      return 'This stay is not active.';
    }
    _replace(
      r.copyWith(
        endedAt: DateTime.now(),
        endReason: reason.isEmpty
            ? 'Withdrawn by resident'
            : 'Withdrawn: $reason',
      ),
    );
    await _registrations.releaseBed(r.targetId);
    await _persist();
    await _notifs.push(
      to: r.targetId,
      title: 'Resident withdrew',
      body:
          '${r.requesterName} withdrew from your shelter'
          '${reason.isEmpty ? '' : ': "$reason"'}. The bed is free again.',
      kind: NotifKind.request,
      refId: r.id,
    );
    await _notifs.push(
      to: r.requesterId,
      title: 'You withdrew from ${r.targetName}',
      body: 'Your stay was ended. You can apply to any shelter again.',
      kind: NotifKind.request,
      refId: r.id,
    );
    return null;
  }

  /// Moves a resident: ends the old stay and starts an approved stay at
  /// [to]. Returns an error message, or null on success.
  Future<String?> completeTransfer({
    required String oldStayId,
    required Registration to,
    required DateTime? allottedUntil,
    String? reservedBed,
    int? people,
    String? message,
  }) async {
    final old = byId(oldStayId);
    if (old == null || old.endedAt != null) {
      return 'The old stay is not active.';
    }
    // The target shelter may already have set a bed aside for this person.
    final bed = reservedBed ?? await _registrations.consumeBed(to.id);
    if (bed == null) return '${to.displayName} has no free bed.';
    final now = DateTime.now();
    _replace(
      old.copyWith(endedAt: now, endReason: 'Moved to ${to.displayName}'),
    );
    await _registrations.releaseBed(old.targetId);
    _items.add(
      ServiceRequest(
        id: newId(),
        type: RequestType.stay,
        requesterId: old.requesterId,
        requesterName: old.requesterName,
        phone: old.phone,
        targetId: to.id,
        targetName: to.displayName,
        people: people ?? old.approvedPeople ?? old.people,
        message: message == null || message.isEmpty
            ? 'Transferred from ${old.targetName}'
            : 'Transferred from ${old.targetName}. $message',
        status: ReviewStatus.approved,
        decidedAt: now,
        arrivalAt: now,
        fulfilledAt: now,
        contactPerson: to.name,
        approvedPeople: people ?? old.approvedPeople ?? old.people,
        bedLabel: bed,
        allottedUntil: allottedUntil,
      ),
    );
    notifyListeners();
    await _persist();
    return null;
  }

  /// Shelter confirms the order was handed over / the person arrived.
  Future<void> markDelivered(String id) async {
    final r = byId(id);
    if (r == null || r.status != ReviewStatus.approved) return;
    if (r.fulfilledAt != null || r.closedAt != null) return;
    // Only once the arrival time the shelter set has been reached.
    if (r.arrivalAt != null && r.arrivalAt!.isAfter(DateTime.now())) return;
    _replace(r.copyWith(fulfilledAt: DateTime.now()));
    await _persist();
    await _notifs.push(
      to: r.requesterId,
      title: '${r.type == RequestType.stay ? 'Check-in' : 'Order'} completed ✅',
      body:
          '${r.targetName} marked "${r.title}" as done. '
          'Thank you for visiting.',
      kind: NotifKind.decision,
      refId: r.id,
    );
  }

  /// Shelter closes a no-show after [kNoShowGrace] and releases the slot.
  /// Returns an error message, or null on success.
  Future<String?> closeNoShow(String id) async {
    final r = byId(id);
    if (r == null) return 'Request not found.';
    if (!r.canCloseNoShow) {
      return 'You can close this order ${kNoShowGrace.inHours} hours after the '
          'scheduled time.';
    }
    final notice =
        '${r.targetName} waited ${kNoShowGrace.inHours} hours after your '
        'scheduled time (${fmtDateTime(r.arrivalAt!)}) and tried to contact '
        'you. Because we could not reach you, your order "${r.title}" was '
        'given to another person in need. If you still need help, you are '
        'welcome to place a new request at any time.';
    _replace(r.copyWith(closedAt: DateTime.now(), closeNotice: notice));
    if (r.type == RequestType.stay) await _registrations.releaseBed(r.targetId);
    await _persist();
    await _notifs.push(
      to: r.requesterId,
      title: 'Order closed with a notice',
      body: notice,
      kind: NotifKind.decision,
      refId: r.id,
    );
    return null;
  }

  Future<void> reject(String id, String reason) async {
    final r = byId(id);
    if (r == null || !r.isPending) return;
    _replace(
      r.copyWith(
        status: ReviewStatus.rejected,
        decidedAt: DateTime.now(),
        rejectReason: reason,
      ),
    );
    await _persist();
    await _notifs.push(
      to: r.requesterId,
      title: '${r.type.label} rejected',
      body: '${r.targetName} could not accept "${r.title}". Reason: $reason',
      kind: NotifKind.decision,
      refId: r.id,
    );
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'Rejected by ${r.targetName}',
      body: '${r.requesterName} · ${r.title}. Reason: $reason',
      kind: NotifKind.decision,
      refId: r.id,
    );
  }

  // ---- text builders -----------------------------------------------------

  String _incomingBody(ServiceRequest r) {
    final when = r.neededDate == null ? '' : ' for ${dayLabel(r.neededDate!)}';
    return switch (r.type) {
      RequestType.stay =>
        '${r.requesterName} needs a stay for ${r.people} (${r.phone}).',
      RequestType.food =>
        '${r.requesterName} needs ${r.meal?.label.toLowerCase()}$when for '
            '${r.people} people (${r.phone}).',
      RequestType.donation =>
        '${r.requesterName} offers ${r.people} ${r.meal?.label.toLowerCase()} '
            'meals$when (${r.phone}).',
      RequestType.help =>
        '${r.requesterName} asks for ${r.title} for ${r.people} '
            '${r.people == 1 ? 'person' : 'people'} (${r.phone}).',
    };
  }

  String _approvedBody(ServiceRequest r) {
    final b = StringBuffer();
    switch (r.type) {
      case RequestType.stay:
        b.write(
          '${r.targetName} approved a stay for ${r.approvedPeople} '
          '(${r.bedLabel}). You are registered at the shelter once it checks '
          'you in on arrival. ',
        );
      case RequestType.food:
        b.write(
          '${r.targetName} approved ${r.meal?.label.toLowerCase()} for '
          '${r.approvedPeople} people. ',
        );
      case RequestType.donation:
        b.write(
          '${r.targetName} accepted your donation of '
          '${r.approvedPeople} ${r.meal?.label.toLowerCase()} meals. ',
        );
      case RequestType.help:
        b.write('${r.targetName} approved your request for ${r.title}. ');
    }
    b.write(
      '${r.type.whenLabel}: ${fmtDateTime(r.arrivalAt!)}. '
      '${r.type.contactLabel}: ${r.contactPerson}.',
    );
    if ((r.decisionNote ?? '').isNotEmpty) b.write(' Note: ${r.decisionNote}');
    return b.toString();
  }

  void _replace(ServiceRequest r) {
    final i = _items.indexWhere((e) => e.id == r.id);
    if (i >= 0) _items[i] = r;
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
