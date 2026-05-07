import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_session.dart';
import 'session_storage.dart';

final class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({
    FlutterSecureStorage? secureStorage,
    String key = _defaultKey,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _key = key;

  static const _defaultKey = 'fulan_auth_feature.session.v1';

  final FlutterSecureStorage _secureStorage;
  final String _key;

  @override
  Future<AuthSession?> read() async {
    final raw = await _secureStorage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid stored session json');
    }
    return AuthSession.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<void> write(AuthSession session) async {
    final raw = jsonEncode(session.toJson());
    await _secureStorage.write(key: _key, value: raw);
  }

  @override
  Future<void> clear() => _secureStorage.delete(key: _key);
}
