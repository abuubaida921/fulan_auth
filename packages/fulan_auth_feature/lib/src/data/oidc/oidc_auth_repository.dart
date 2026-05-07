import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;

import '../../domain/auth_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import '../../domain/auth_user.dart';
import '../session_storage.dart';
import 'oidc_app_auth.dart';
import 'oidc_config.dart';
import 'oidc_discovery_document.dart';

final class OidcAuthRepository implements AuthRepository {
  OidcAuthRepository({
    required OidcConfig config,
    required SessionStorage sessionStorage,
    OidcAppAuth? appAuth,
    http.Client? httpClient,
    DateTime Function()? now,
  }) : _config = config,
       _sessionStorage = sessionStorage,
       _appAuth = appAuth ?? FlutterOidcAppAuth(),
       _httpClient = httpClient ?? http.Client(),
       _now = now ?? DateTime.now;

  final OidcConfig _config;
  final SessionStorage _sessionStorage;
  final OidcAppAuth _appAuth;
  final http.Client _httpClient;
  final DateTime Function() _now;

  final _controller = StreamController<AuthSession?>.broadcast();
  AuthSession? _current;
  bool _initialized = false;
  OidcDiscoveryDocument? _discovery;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _current = await _sessionStorage.read();
    _controller.add(_current);
  }

  @override
  Stream<AuthSession?> watchSession() {
    unawaited(initialize());
    return _controller.stream.asyncMap((session) async {
      if (session == null) return null;
      return _ensureFreshSession(session);
    });
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    await initialize();
    final session = _current;
    if (session == null) return null;
    return _ensureFreshSession(session);
  }

  @override
  Future<AuthSession> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    throw UnsupportedError(
      'OIDC flow does not use email/password directly. Use signIn() instead.',
    );
  }

  Future<AuthSession> signIn() async {
    await initialize();
    if (kIsWeb) {
      throw const UnknownAuthFailure('OIDC sign-in is not supported on web');
    }

    final response = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _config.clientId,
        _config.redirectUrl,
        discoveryUrl: _config.discoveryUrl.toString(),
        scopes: _config.scopes,
      ),
    );

    if (response == null ||
        response.accessToken == null ||
        response.refreshToken == null ||
        response.accessTokenExpirationDateTime == null) {
      throw const UnknownAuthFailure('Sign-in failed');
    }

    final discovery = await _getDiscovery();
    final user = await _fetchUserInfo(
      userinfoEndpoint: discovery.userinfoEndpoint,
      accessToken: response.accessToken!,
    );

    final session = AuthSession(
      user: user,
      accessToken: response.accessToken!,
      refreshToken: response.refreshToken!,
      expiresAt: response.accessTokenExpirationDateTime!,
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
    _httpClient.close();
    await _controller.close();
  }

  Future<OidcDiscoveryDocument> _getDiscovery() async {
    final cached = _discovery;
    if (cached != null) return cached;
    try {
      final doc = await OidcDiscoveryDocument.fetch(
        discoveryUrl: _config.discoveryUrl,
        client: _httpClient,
      );
      _discovery = doc;
      return doc;
    } catch (e) {
      throw UnknownAuthFailure(e.toString());
    }
  }

  Future<AuthUser> _fetchUserInfo({
    required Uri userinfoEndpoint,
    required String accessToken,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.get(
        userinfoEndpoint,
        headers: {
          'accept': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
    } catch (_) {
      throw const NetworkFailure();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerFailure('Userinfo error (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UnknownAuthFailure('Malformed userinfo response');
    }

    final sub = decoded['sub'];
    final email = decoded['email'];

    if (sub is! String) {
      throw const UnknownAuthFailure('Missing sub in userinfo');
    }

    return AuthUser(id: sub, email: email is String ? email : '');
  }

  Future<AuthSession> _ensureFreshSession(AuthSession session) async {
    if (!session.isExpired) return session;

    final refreshed = await _refresh(session);
    _current = refreshed;
    await _sessionStorage.write(refreshed);
    _controller.add(refreshed);
    return refreshed;
  }

  Future<AuthSession> _refresh(AuthSession session) async {
    final response = await _appAuth.token(
      TokenRequest(
        _config.clientId,
        _config.redirectUrl,
        discoveryUrl: _config.discoveryUrl.toString(),
        refreshToken: session.refreshToken,
        scopes: _config.scopes,
      ),
    );

    if (response == null ||
        response.accessToken == null ||
        response.accessTokenExpirationDateTime == null) {
      throw const UnknownAuthFailure('Token refresh failed');
    }

    final accessToken = response.accessToken!;
    final refreshToken = response.refreshToken ?? session.refreshToken;
    final expiresAt = response.accessTokenExpirationDateTime!;

    return AuthSession(
      user: session.user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.isAfter(_now()) ? expiresAt : _now(),
    );
  }
}
