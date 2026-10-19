import 'package:flutter/foundation.dart';

import '../data/local/local_store.dart';
import '../data/models/complaint.dart';
import '../data/models/enums.dart';
import 'notification_provider.dart';

/// Complaint flow: user -> admin (confidential) -> admin asks shelter to
/// verify -> shelter replies -> admin upholds (notice) or dismisses.
class ComplaintProvider extends ChangeNotifier {
  ComplaintProvider(this._store, this._notifs) {
    _items = _store.readList(_key).map(Complaint.fromJson).toList();
  }

  static const _key = 'complaints_v1';

  final LocalStore _store;
  final NotificationProvider _notifs;
  List<Complaint> _items = [];

  List<Complaint> get all =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Complaint? byId(String? id) {
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Complaint> by(String complainantId) =>
      all.where((c) => c.complainantId == complainantId).toList();

  /// What a shelter may see: only cases the admin sent it to verify.
  List<Complaint> forShelter(String shelterId) =>
      all.where((c) => c.shelterId == shelterId && c.askedAt != null).toList();

  int get openCount => _items.where((c) => !c.status.isClosed).length;

  int awaitingShelter(String shelterId) => _items
      .where(
        (c) =>
            c.shelterId == shelterId && c.status == ComplaintStatus.verifying,
      )
      .length;

  Future<void> submit(Complaint c) async {
    _items.add(c);
    notifyListeners();
    await _persist();
    // Admin only. The shelter is deliberately NOT notified.
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'New complaint',
      body:
          '${c.complainantName} reported ${c.shelterName}: '
          '${c.reason.label}.',
      kind: NotifKind.complaint,
      refId: c.id,
    );
    await _notifs.push(
      to: c.complainantId,
      title: 'Complaint received',
      body:
          'Your complaint about ${c.shelterName} reached the admin. '
          'The shelter has not been told who complained.',
      kind: NotifKind.complaint,
      refId: c.id,
    );
  }

  /// Admin asks the shelter to confirm whether the work was really done.
  Future<void> askShelter(String id, String question) async {
    final c = byId(id);
    if (c == null || c.status != ComplaintStatus.open) return;
    _replace(
      c.copyWith(
        status: ComplaintStatus.verifying,
        question: question,
        askedAt: DateTime.now(),
      ),
    );
    await _persist();
    // Neutral wording: no complainant name, no word "complaint".
    await _notifs.push(
      to: c.shelterId,
      title: 'Admin verification needed',
      body:
          'Please confirm a service record'
          '${c.requestSummary.isEmpty ? '' : ' (${c.requestSummary})'}. '
          '${question.isEmpty ? '' : question}',
      kind: NotifKind.complaint,
      refId: c.id,
    );
    await _notifs.push(
      to: c.complainantId,
      title: 'Complaint under review',
      body: 'Admin is verifying your complaint about ${c.shelterName}.',
      kind: NotifKind.complaint,
      refId: c.id,
    );
  }

  Future<void> shelterReply(
    String id, {
    required bool confirmed,
    required String note,
  }) async {
    final c = byId(id);
    if (c == null || c.status != ComplaintStatus.verifying) return;
    _replace(
      c.copyWith(
        status: ComplaintStatus.shelterReplied,
        shelterConfirmed: confirmed,
        shelterNote: note,
        repliedAt: DateTime.now(),
      ),
    );
    await _persist();
    await _notifs.push(
      to: NotificationProvider.adminId,
      title: 'Shelter replied',
      body:
          '${c.shelterName} says the service was '
          '${confirmed ? 'provided' : 'NOT provided'}. "$note"',
      kind: NotifKind.complaint,
      refId: c.id,
    );
  }

  /// Admin closes the case. [upheld] = complaint is valid -> notice to shelter.
  Future<void> resolve(
    String id, {
    required bool upheld,
    required String note,
  }) async {
    final c = byId(id);
    if (c == null || c.status.isClosed) return;
    _replace(
      c.copyWith(
        status: upheld ? ComplaintStatus.upheld : ComplaintStatus.dismissed,
        adminNote: note,
        resolvedAt: DateTime.now(),
      ),
    );
    await _persist();
    await _notifs.push(
      to: c.complainantId,
      title: upheld ? 'Complaint upheld' : 'Complaint closed',
      body: upheld
          ? 'Admin found your complaint about ${c.shelterName} valid and '
                'issued a notice. "$note"'
          : 'Admin reviewed your complaint about ${c.shelterName} and found '
                'no violation. "$note"',
      kind: NotifKind.complaint,
      refId: c.id,
    );
    if (upheld) {
      await _notifs.push(
        to: c.shelterId,
        title: 'Notice from admin',
        body:
            'After verification, admin has issued a notice to your '
            'shelter. "$note"',
        kind: NotifKind.complaint,
        refId: c.id,
      );
    } else if (c.askedAt != null) {
      await _notifs.push(
        to: c.shelterId,
        title: 'Verification closed',
        body: 'Thank you. Admin closed the verification; no action needed.',
        kind: NotifKind.complaint,
        refId: c.id,
      );
    }
  }

  void _replace(Complaint c) {
    final i = _items.indexWhere((e) => e.id == c.id);
    if (i >= 0) _items[i] = c;
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _items.map((e) => e.toJson()).toList());
}
