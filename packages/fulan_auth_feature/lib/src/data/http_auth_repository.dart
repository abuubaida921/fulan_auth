import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'session_storage.dart';

final class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required Uri baseUrl,
    required SessionStorage sessionStorage,
    http.Client? client,
  }) : _baseUrl = baseUrl,
       _sessionStorage = sessionStorage,
       _client = client ?? http.Client();

  final Uri _baseUrl;
  final SessionStorage _sessionStorage;
  final http.Client _client;

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
    final uri = _baseUrl.resolve('/auth/login');
    late final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
    } catch (_) {
      throw const NetworkFailure();
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const InvalidCredentialsFailure();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerFailure('Server error (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UnknownAuthFailure('Malformed response');
    }

    final session = AuthSession.fromJson(Map<String, Object?>.from(decoded));
    _current = session;
    await _sessionStorage.write(session);
    _controller.add(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await initialize();
    final current = _current;
    if (current != null) {
      final uri = _baseUrl.resolve('/auth/logout');
      try {
        await _client.post(
          uri,
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer ${current.accessToken}',
          },
        );
      } catch (_) {}
    }
    _current = null;
    await _sessionStorage.clear();
    _controller.add(null);
  }

  Future<void> dispose() async {
    _client.close();
    await _controller.close();
  }
}
