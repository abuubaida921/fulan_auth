class OidcConfig {
  const OidcConfig({
    required this.discoveryUrl,
    required this.clientId,
    required this.redirectUrl,
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
  });

  final Uri discoveryUrl;
  final String clientId;
  final String redirectUrl;
  final List<String> scopes;
}
