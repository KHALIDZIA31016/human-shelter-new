import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../data/local/local_store.dart';
import '../data/models/enums.dart';
import 'notification_provider.dart';

/// A person-in-need account on this device (demo: no login yet).
class AppUser {
  const AppUser(this.id, this.label, {this.needsRegistration = false});

  final String id;
  final String label;

  /// Created through "Register myself": cannot enter the app until the admin
  /// has approved a registration.
  final bool needsRegistration;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'needsRegistration': needsRegistration,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    j['id'] as String,
    j['label'] as String? ?? 'User',
    needsRegistration: j['needsRegistration'] as bool? ?? false,
  );
}

/// Who is using the app right now.
///
/// There is no login yet, so one device can hold several person-in-need
/// accounts plus act as a partner or the admin (switchable from the Switch
/// mode screen). Every record is keyed by the active user's id, so each user
/// only ever sees their own requests, chats, notifications and complaints.
/// When real auth is added, only this class needs to change.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._store) {
    var legacy = _store.getString(_kDevice);
    if (legacy == null) {
      legacy = newId();
      _store.setString(_kDevice, legacy);
    }
    _users = _readUsers();
    if (_users.isEmpty) {
      // The original single user keeps their id, so their data is kept.
      _users = [AppUser(legacy, 'User 1')];
      _saveUsers();
    }
    final saved = _store.getString(_kActive);
    _activeId = _users.any((u) => u.id == saved) ? saved! : _users.first.id;
    persona = enumByName(
      Persona.values,
      _store.getString(_kPersona),
      Persona.needy,
    );
    final partner = _store.getString(_kPartner);
    activePartnerId = (partner == null || partner.isEmpty) ? null : partner;
  }

  static const _kDevice = 'device_id';
  static const _kUsers = 'users_v1';
  static const _kActive = 'active_user';
  static const _kPersona = 'persona';
  static const _kPartner = 'active_partner';

  final LocalStore _store;
  late List<AppUser> _users;
  late String _activeId;
  late Persona persona;
  String? activePartnerId;

  List<AppUser> get users => List.unmodifiable(_users);

  /// Id of the active person-in-need user. All of their data is keyed by it.
  String get deviceId => _activeId;

  AppUser get activeUser => _users.firstWhere((u) => u.id == _activeId);

  /// Ids whose notifications the current view should see.
  Set<String> get recipientIds => switch (persona) {
    Persona.admin => {NotificationProvider.adminId},
    Persona.partner => {?activePartnerId},
    Persona.needy => {deviceId},
  };

  /// Switches to the person-in-need view, optionally as another user.
  Future<void> useNeedy({String? userId}) async {
    if (userId != null && _users.any((u) => u.id == userId)) {
      _activeId = userId;
      await _store.setString(_kActive, userId);
    }
    await _set(Persona.needy, null);
  }

  /// Creates a new empty user and makes them the active one.
  Future<AppUser> addUser({String? id}) async {
    final user = AppUser(
      id ?? newId(),
      'User ${_users.length + 1}',
      needsRegistration: true,
    );
    _users = [..._users, user];
    await _saveUsers();
    await useNeedy(userId: user.id);
    return user;
  }

  Future<void> useAdmin() => _set(Persona.admin, null);
  Future<void> usePartner(String registrationId) =>
      _set(Persona.partner, registrationId);

  Future<void> _set(Persona p, String? partnerId) async {
    persona = p;
    activePartnerId = partnerId;
    notifyListeners();
    await _store.setString(_kPersona, p.name);
    await _store.setString(_kPartner, partnerId ?? '');
  }

  List<AppUser> _readUsers() {
    final raw = _store.getString(_kUsers);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(AppUser.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveUsers() => _store.setString(
    _kUsers,
    jsonEncode(_users.map((u) => u.toJson()).toList()),
  );
}
