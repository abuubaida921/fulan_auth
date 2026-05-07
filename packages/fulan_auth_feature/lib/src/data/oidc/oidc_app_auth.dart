import 'package:flutter_appauth/flutter_appauth.dart';

abstract interface class OidcAppAuth {
  Future<AuthorizationTokenResponse?> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  );

  Future<TokenResponse?> token(TokenRequest request);
}

final class FlutterOidcAppAuth implements OidcAppAuth {
  FlutterOidcAppAuth({FlutterAppAuth? appAuth})
    : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  @override
  Future<AuthorizationTokenResponse?> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) => _appAuth.authorizeAndExchangeCode(request);

  @override
  Future<TokenResponse?> token(TokenRequest request) => _appAuth.token(request);
}
