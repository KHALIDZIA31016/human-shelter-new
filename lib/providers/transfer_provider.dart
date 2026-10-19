import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../data/local/local_store.dart';
import '../data/models/enums.dart';
import '../data/models/service_request.dart';
import '../data/models/shelter_transfer.dart';
import 'chat_provider.dart';
import 'notification_provider.dart';
import 'registration_provider.dart';
import 'request_provider.dart';

/// Shelter change, in five steps:
///  1. the user asks (reason) -> goes to their CURRENT shelter
///  2. the current shelter cannot decide; it only notifies the admin with a
///     full resident report
///  3. the admin cross-checks beds, then approves the requested shelter or
///     recommends another one with a free bed
///  4. that shelter confirms a bed is now occupied for the user
///  5. the user submits the new form; they are moved and the old bed is
///     free for someone else
class TransferProvider extends ChangeNotifier {
  TransferProvider(
    this._store,
    this._notifs,
    this._registrations,
    this._requests,
    this._chat,
  ) {
    _items = _store.readList(_key).map(ShelterTransfer.fromJson).toList();
  }

  static const _key = 'transfers_v1';

  final LocalStore _store;
  final NotificationProvider _notifs;
  final RegistrationProvider _registrations;
  final RequestProvider _requests;
  final ChatProvider _chat;
  List<ShelterTransfer> _items = [];

  List<ShelterTransfer> get all =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  ShelterTransfer? byId(String? id) {
    for (final t in _items) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<ShelterTransfer> by(String userId) =>
      all.where((t) => t.userId == userId).toList();

  /// Cases a shelter is part of: as the current shelter, or (once the admin
  /// picked it) as the shelter that must confirm a bed.
  List<ShelterTransfer> forShelter(String shelterId) => all
      .where(
        (t) =>
            t.fromShelterId == shelterId ||
            (t.toShelterId == shelterId &&
                (t.status == TransferStatus.pendingNew ||
                    t.status == TransferStatus.confirmed ||
                    t.status == TransferStatus.completed)),
      )
      .toList();

  ShelterTransfer? openOf(String userId) {
    for (final t in by(userId)) {
      if (t.status.isOpen) return t;
    }
    return null;
  }

  /// Open cases waiting for this shelter to act.
  int actionableFor(String shelterId) => _items
      .where(
        (t) =>
            (t.fromShelterId == shelterId &&
                t.status == TransferStatus.pendingCurrent) ||
            (t.toShelterId == shelterId &&
                t.status == TransferStatus.pendingNew),
      )
      .length;

  int get adminOpenCount =>
      _items.where((t) => t.status == TransferStatus.pendingAdmin).length;

  /// Full picture of the resident, as sent to the admin and the new shelter.
  String buildReport(ShelterTransfer t) {
    final reg = _registrations.individualOf(t.userId);
    final stay = _requests.byId(t.stayRequestId);
    final mine = _requests.sentBy(t.userId);
    final since = stay?.arrivalAt ?? stay?.decidedAt ?? stay?.createdAt;
    final days = since == null ? null : DateTime.now().difference(since).inDays;
    final done = mine.where((r) => r.fulfilledAt != null).length;
    final missed = mine.where((r) => r.closedAt != null).length;
    final lines = <String>[
      'Name: ${reg?.name ?? t.userName}',
      'Age: ${reg?.age ?? 'not provided'}',
      'Phone: ${reg?.phone ?? stay?.phone ?? '—'}',
      if ((reg?.email ?? '').isNotEmpty) 'Email: ${reg!.email}',
      'Location: ${reg == null ? '—' : '${reg.city} · ${reg.address}'}',
      'People with them: ${reg?.familyMembers ?? stay?.people ?? 1}',
      'Issue / needs: ${(reg?.needs.isEmpty ?? true) ? '—' : reg!.needs.join(', ')}',
      if ((reg?.notes ?? '').isNotEmpty) 'Situation: ${reg!.notes}',
      if (reg != null) 'Registered with admin: ${fmtDate(reg.createdAt)}',
      'Current shelter: ${t.fromName}',
      if (since != null)
        'Staying since: ${fmtDate(since)} ($days day${days == 1 ? '' : 's'})',
      if (stay?.bedLabel != null) 'Bed: ${stay!.bedLabel}',
      if (stay?.allottedUntil != null)
        'Allotted until: ${fmtDate(stay!.allottedUntil!)}',
      'Requests made: ${mine.length} ($done delivered, $missed missed)',
      'Wants to move to: ${t.toName}',
      'Reason for change: ${t.reason}',
    ];
    return lines.join('\n');
  }

  /// Returns an error message, or null on success.
  Future<String?> request({
    required ServiceRequest stay,
    required String toShelterId,
    required String reason,
  }) async {
    if (openOf(stay.requesterId) != null) {
      return 'You already have a shelter change in progress.';
    }
    final to = _registrations.byId(toShelterId);
    if (to == null || to.id == stay.targetId) {
      return 'Choose a different shelter.';
    }
    final t = ShelterTransfer(
      id: newId(),
      userId: stay.requesterId,
      userName: stay.requesterName,
      stayRequestId: stay.id,
      fromShelterId: stay.targetId,
      fromName: stay.targetName,
      toShelterId: to.id,
      toName: to.displayName,
      reason: reason,
    );
    _items.add(t);
    notifyListeners();
    await _persist();

    // To the CURRENT shelter and the admin. The new shelter hears nothing yet.
    await _notifs.push(
      to: t.fromShelterId,
      title: 'Shelter change requested',
      body:
          '${t.userName} asks to move to ${t.toName}. Reason: "$reason". '
          'You cannot decide this; please send the resident report to the '
          'admin (Notify admin).',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'Resident requested a shelter change',
      body:
          '${t.userName}: ${t.fromName} → ${t.toName}. Reason: "$reason". '
          'Waiting for ${t.fromName} to send the full report.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _chat.system(
      userId: t.userId,
      shelterId: t.fromShelterId,
      text:
          'Your shelter change request was received. The shelter forwards '
          'it to the admin, and you will get feedback within 24 hours.',
    );
    await _notifs.push(
      to: t.userId,
      title: 'Change request received',
      body:
          '${t.fromName} received your request to move to ${t.toName}. '
          'It goes to the admin, with feedback within 24 hours.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    return null;
  }

  /// Current shelter's ONLY action: send the full resident report to admin.
  Future<void> notifyAdmin(String id, {String remarks = ''}) async {
    final t = byId(id);
    if (t == null || t.status != TransferStatus.pendingCurrent) return;
    final report = buildReport(t);
    _replace(
      t.copyWith(
        status: TransferStatus.pendingAdmin,
        report: report,
        currentRemarks: remarks,
      ),
    );
    await _persist();
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'Resident report from ${t.fromName}',
      body:
          '${t.fromName} sent the full report for ${t.userName} '
          '(${t.fromName} → ${t.toName}). Please check bed availability and '
          'decide.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _chat.system(
      userId: t.userId,
      shelterId: t.fromShelterId,
      text: '${t.fromName} sent your request and report to the admin.',
    );
    await _notifs.push(
      to: t.userId,
      title: 'Sent to admin',
      body: '${t.fromName} forwarded your request to the admin for review.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
  }

  /// Admin: approve moving to [toShelterId] (may differ from the requested
  /// one = recommendation) or reject. Returns an error message or null.
  Future<String?> adminDecision(
    String id, {
    required bool approve,
    String? toShelterId,
    required String note,
  }) async {
    final t = byId(id);
    if (t == null || t.status != TransferStatus.pendingAdmin) {
      return 'Not available.';
    }
    if (!approve) {
      _replace(t.copyWith(status: TransferStatus.rejected, adminNote: note));
      await _persist();
      for (final to in {t.userId, t.fromShelterId}) {
        await _notifs.push(
          to: to,
          title: 'Shelter change rejected',
          body:
              'Admin could not approve moving ${t.userName} to ${t.toName}: '
              '"$note". They stay at ${t.fromName}.',
          kind: NotifKind.transfer,
          refId: t.id,
        );
      }
      return null;
    }
    final target = _registrations.byId(toShelterId ?? t.toShelterId);
    if (target == null || target.id == t.fromShelterId) {
      return 'Choose another shelter.';
    }
    if (target.availableBeds < 1) {
      return '${target.displayName} has no free bed. Pick a shelter with one.';
    }
    final changed = target.id != t.toShelterId;
    _replace(
      t.copyWith(
        status: TransferStatus.pendingNew,
        toShelterId: target.id,
        toName: target.displayName,
        recommended: changed || t.recommended,
        adminNote: note,
      ),
    );
    await _persist();
    final cur = byId(id)!;
    await _notifs.push(
      to: target.id,
      title: 'Admin: confirm a bed for ${t.userName}',
      body:
          'Admin cross-checked and approved ${t.userName} for your shelter '
          '(moving from ${t.fromName}). Please confirm that a bed is now '
          'reserved for them. Open the case for the full report.',
      kind: NotifKind.transfer,
      refId: cur.id,
    );
    await _notifs.push(
      to: t.userId,
      title: changed
          ? 'Admin recommends ${target.displayName}'
          : 'Change approved by admin',
      body: changed
          ? 'Admin recommends ${target.displayName} instead of ${t.toName} '
                '(it has a free bed). ${target.displayName} is confirming your bed.'
          : 'Admin approved your move to ${target.displayName}. They are '
                'confirming your bed now.',
      kind: NotifKind.transfer,
      refId: cur.id,
    );
    return null;
  }

  /// New shelter confirms: a bed is now occupied for the user.
  Future<String?> newConfirm(String id) async {
    final t = byId(id);
    if (t == null || t.status != TransferStatus.pendingNew)
      return 'Not available.';
    final bed = await _registrations.consumeBed(t.toShelterId);
    if (bed == null) return '${t.toName} has no free bed. Decline instead.';
    _replace(
      t.copyWith(
        status: TransferStatus.confirmed,
        reservedBed: bed,
        newReply: 'Confirmed',
      ),
    );
    await _persist();
    await _notifs.push(
      to: t.userId,
      title: 'Your bed at ${t.toName} is ready',
      body:
          '${t.toName} confirmed $bed for you. Open the case and submit the '
          'new form to complete your move.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _notifs.push(
      to: t.fromShelterId,
      title: 'Resident will be leaving',
      body:
          '${t.userName} will move to ${t.toName} once they submit the new '
          'form. Their bed here becomes free for a new resident.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: '${t.toName} confirmed a bed',
      body:
          '$bed is now occupied for ${t.userName}. Waiting for them to '
          'submit the form.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    return null;
  }

  /// New shelter cannot take the user: back to the admin to pick another.
  Future<void> newDecline(String id, String reply) async {
    final t = byId(id);
    if (t == null || t.status != TransferStatus.pendingNew) return;
    _replace(t.copyWith(status: TransferStatus.pendingAdmin, newReply: reply));
    await _persist();
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: '${t.toName} cannot take ${t.userName}',
      body: '"$reply". Please recommend another shelter.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _notifs.push(
      to: t.userId,
      title: 'Looking for another shelter',
      body: '${t.toName} could not take you. The admin will recommend another.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
  }

  /// User submits the new form: moved, old bed freed.
  Future<String?> userComplete(
    String id, {
    required int people,
    String message = '',
  }) async {
    final t = byId(id);
    if (t == null || t.status != TransferStatus.confirmed)
      return 'Not ready yet.';
    final old = _requests.byId(t.stayRequestId);
    final to = _registrations.byId(t.toShelterId);
    if (old == null || to == null) return 'Records not found.';
    final err = await _requests.completeTransfer(
      oldStayId: old.id,
      to: to,
      allottedUntil: old.allottedUntil,
      reservedBed: t.reservedBed,
      people: people,
      message: message,
    );
    if (err != null) return err;
    _replace(t.copyWith(status: TransferStatus.completed));
    await _persist();
    await _notifs.push(
      to: t.userId,
      title: 'You moved to ${t.toName} ✅',
      body:
          'Welcome to ${t.toName} (${t.reservedBed ?? 'your bed'}). '
          '${t.fromName} was removed as your shelter.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _notifs.push(
      to: t.fromShelterId,
      title: 'Resident left · bed is empty',
      body:
          '${t.userName} moved to ${t.toName}. Their bed is free for a '
          'new resident.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _notifs.push(
      to: t.toShelterId,
      title: 'Resident arrived',
      body:
          '${t.userName} submitted the form and is now registered with you '
          '(${t.reservedBed ?? 'bed'}).',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'Shelter change completed',
      body: '${t.userName} moved from ${t.fromName} to ${t.toName}.',
      kind: NotifKind.transfer,
      refId: t.id,
    );
    return null;
  }

  /// User gives up. A bed already set aside is released again.
  Future<void> userCancel(String id) async {
    final t = byId(id);
    if (t == null || !t.status.isOpen) return;
    if (t.status == TransferStatus.confirmed) {
      await _registrations.releaseBed(t.toShelterId);
    }
    _replace(t.copyWith(status: TransferStatus.cancelled));
    await _persist();
    for (final to in {
      t.fromShelterId,
      NotificationProvider.adminId,
      if (t.status == TransferStatus.confirmed) t.toShelterId,
    }) {
      await _notifs.push(
        to: to,
        title: 'Shelter change cancelled',
        body: '${t.userName} cancelled the move to ${t.toName}.',
        kind: NotifKind.transfer,
        refId: t.id,
      );
    }
  }

  void _replace(ShelterTransfer t) {
    final i = _items.indexWhere((e) => e.id == t.id);
    if (i >= 0) _items[i] = t;
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
