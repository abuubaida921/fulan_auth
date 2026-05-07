import 'dart:async';
import 'dart:math';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import 'session_storage.dart';

final class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    required SessionStorage sessionStorage,
    DateTime Function()? now,
  }) : _sessionStorage = sessionStorage,
       _now = now ?? DateTime.now;

  final SessionStorage _sessionStorage;
  final DateTime Function() _now;

  final _controller = StreamController<AuthSession?>.broadcast();
  AuthSession? _current;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _current = await _sessionStorage.read();
    _controller.add(_current);
  }

  @override
  Stream<AuthSession?> watchSession() {
    unawaited(initialize());
    return _controller.stream;
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    await initialize();
    return _current;
  }

  @override
  Future<AuthSession> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await initialize();
    if (email.trim().isEmpty || password.isEmpty) {
      throw const InvalidCredentialsFailure();
    }

    final rng = Random();
    final user = AuthUser(
      id: 'user_${rng.nextInt(1 << 32)}',
      email: email.trim(),
    );

    final session = AuthSession(
      user: user,
      accessToken: _randomToken(rng),
      refreshToken: _randomToken(rng),
      expiresAt: _now().add(const Duration(hours: 1)),
    );

    _current = session;
    await _sessionStorage.write(session);
    _controller.add(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await initialize();
    _current = null;
    await _sessionStorage.clear();
    _controller.add(null);
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  String _randomToken(Random rng) {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer();
    for (var i = 0; i < 48; i++) {
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }
}
