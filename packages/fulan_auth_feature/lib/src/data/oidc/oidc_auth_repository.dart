import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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
import 'web_platform.dart';

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

  static const _pkceStateKey = 'fulan.oidc.pkce.state';
  static const _pkceVerifierKey = 'fulan.oidc.pkce.verifier';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _current = await _sessionStorage.read();
    _controller.add(_current);
    if (kIsWeb) {
      await _tryCompleteWebRedirect();
    }
  }

  @override
  Stream<AuthSession?> watchSession() {
    unawaited(initialize());
    return _controller.stream.asyncMap((session) async {
      if (session == null) return null;
      return _ensureFreshSessionOrNull(session);
    });
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    await initialize();
    final session = _current;
    if (session == null) return null;
    return _ensureFreshSessionOrNull(session);
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
      await _startWebSignIn();
      throw const UnknownAuthFailure('Redirecting to sign-in');
    }

    final discovery = await _getDiscovery();
    final serviceConfiguration = AuthorizationServiceConfiguration(
      authorizationEndpoint: discovery.authorizationEndpoint.toString(),
      tokenEndpoint: discovery.tokenEndpoint.toString(),
    );

    late final AuthorizationTokenResponse? response;
    try {
      response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _config.clientId,
          _config.redirectUrl,
          serviceConfiguration: serviceConfiguration,
          scopes: _config.scopes,
        ),
      );
    } on FlutterAppAuthUserCancelledException catch (_) {
      throw const UnknownAuthFailure('Sign-in cancelled');
    } on FlutterAppAuthPlatformException catch (e) {
      final details = e.platformErrorDetails;
      throw UnknownAuthFailure(
        details.errorDescription ??
            details.error ??
            e.message ??
            'Sign-in failed',
      );
    }

    if (response == null ||
        response.accessToken == null ||
        response.accessTokenExpirationDateTime == null) {
      throw const UnknownAuthFailure('Sign-in failed');
    }

    final user = await _fetchUserInfo(
      userinfoEndpoint: discovery.userinfoEndpoint,
      accessToken: response.accessToken!,
    );

    final session = AuthSession(
      user: user,
      accessToken: response.accessToken!,
      refreshToken: response.refreshToken,
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

  Future<AuthSession?> _ensureFreshSessionOrNull(AuthSession session) async {
    if (!session.isExpired) return session;

    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await signOut();
      return null;
    }

    final refreshed = await _refresh(session, refreshToken: refreshToken);
    _current = refreshed;
    await _sessionStorage.write(refreshed);
    _controller.add(refreshed);
    return refreshed;
  }

  Future<AuthSession> _refresh(
    AuthSession session, {
    required String refreshToken,
  }) async {
    final discovery = await _getDiscovery();
    final serviceConfiguration = AuthorizationServiceConfiguration(
      authorizationEndpoint: discovery.authorizationEndpoint.toString(),
      tokenEndpoint: discovery.tokenEndpoint.toString(),
    );

    late final TokenResponse? response;
    try {
      response = await _appAuth.token(
        TokenRequest(
          _config.clientId,
          _config.redirectUrl,
          serviceConfiguration: serviceConfiguration,
          refreshToken: refreshToken,
          scopes: _config.scopes,
        ),
      );
    } on FlutterAppAuthPlatformException catch (e) {
      final details = e.platformErrorDetails;
      throw UnknownAuthFailure(
        details.errorDescription ??
            details.error ??
            e.message ??
            'Token refresh failed',
      );
    }

    if (response == null ||
        response.accessToken == null ||
        response.accessTokenExpirationDateTime == null) {
      throw const UnknownAuthFailure('Token refresh failed');
    }

    final accessToken = response.accessToken!;
    final newRefreshToken = response.refreshToken ?? refreshToken;
    final expiresAt = response.accessTokenExpirationDateTime!;

    return AuthSession(
      user: session.user,
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      expiresAt: expiresAt.isAfter(_now()) ? expiresAt : _now(),
    );
  }

  Future<void> _startWebSignIn() async {
    final discovery = await _getDiscovery();

    final verifier = _randomUrlSafeString(48);
    final challenge = _codeChallengeS256(verifier);
    final state = _randomUrlSafeString(24);

    webPlatform.writeSessionValue(_pkceVerifierKey, verifier);
    webPlatform.writeSessionValue(_pkceStateKey, state);

    final authorizeUri = discovery.authorizationEndpoint.replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _config.clientId,
        'redirect_uri': _config.redirectUrl,
        'scope': _config.scopes.join(' '),
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );

    webPlatform.redirectTo(authorizeUri.toString());
  }

  Future<void> _tryCompleteWebRedirect() async {
    final currentUri = webPlatform.currentUri;
    final params = currentUri.queryParameters;
    final code = params['code'];
    final returnedState = params['state'];
    final error = params['error'];

    if (code == null && error == null) return;

    final expectedState = webPlatform.readSessionValue(_pkceStateKey);
    final verifier = webPlatform.readSessionValue(_pkceVerifierKey);

    webPlatform.removeSessionValue(_pkceStateKey);
    webPlatform.removeSessionValue(_pkceVerifierKey);

    final cleaned = currentUri.replace(queryParameters: const {});
    webPlatform.replaceUrl(cleaned.toString());

    if (error != null) {
      return;
    }

    if (code == null ||
        returnedState == null ||
        expectedState == null ||
        verifier == null ||
        returnedState != expectedState) {
      return;
    }

    final discovery = await _getDiscovery();
    final tokenResponse = await _exchangeCodeForTokensWeb(
      tokenEndpoint: discovery.tokenEndpoint,
      code: code,
      codeVerifier: verifier,
    );

    final accessToken = tokenResponse.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    late final AuthUser user;
    try {
      user = await _fetchUserInfo(
        userinfoEndpoint: discovery.userinfoEndpoint,
        accessToken: accessToken,
      );
    } catch (_) {
      user = const AuthUser(id: 'unknown', email: '');
    }

    final expiresAt =
        tokenResponse.expiresAt ?? _now().add(const Duration(hours: 1));

    final session = AuthSession(
      user: user,
      accessToken: accessToken,
      refreshToken: tokenResponse.refreshToken,
      expiresAt: expiresAt,
    );

    _current = session;
    await _sessionStorage.write(session);
    _controller.add(session);
  }

  Future<_WebTokenResponse> _exchangeCodeForTokensWeb({
    required Uri tokenEndpoint,
    required String code,
    required String codeVerifier,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient.post(
        tokenEndpoint,
        headers: const {'content-type': 'application/x-www-form-urlencoded'},
        body: Uri(
          queryParameters: {
            'grant_type': 'authorization_code',
            'client_id': _config.clientId,
            'code': code,
            'redirect_uri': _config.redirectUrl,
            'code_verifier': codeVerifier,
          },
        ).query,
      );
    } catch (_) {
      throw const NetworkFailure();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerFailure('Token exchange error (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UnknownAuthFailure('Malformed token response');
    }

    final accessToken = decoded['access_token'];
    final refreshToken = decoded['refresh_token'];
    final expiresIn = decoded['expires_in'];

    DateTime? expiresAt;
    if (expiresIn is int) {
      expiresAt = _now().add(Duration(seconds: expiresIn));
    } else if (expiresIn is String) {
      final parsed = int.tryParse(expiresIn);
      if (parsed != null) {
        expiresAt = _now().add(Duration(seconds: parsed));
      }
    }

    return _WebTokenResponse(
      accessToken: accessToken is String ? accessToken : null,
      refreshToken: refreshToken is String ? refreshToken : null,
      expiresAt: expiresAt,
    );
  }

  String _randomUrlSafeString(int length) {
    late final Random rng;
    try {
      rng = Random.secure();
    } catch (_) {
      rng = Random();
    }
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  String _codeChallengeS256(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes).bytes;
    return base64Url.encode(digest).replaceAll('=', '');
  }
}

final class _WebTokenResponse {
  const _WebTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
}
