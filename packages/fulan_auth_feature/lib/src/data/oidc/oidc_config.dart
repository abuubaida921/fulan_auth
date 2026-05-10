class OidcConfig {
  const OidcConfig({
    required this.discoveryUrl,
    required this.clientId,
    required this.redirectUrl,
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
    this.requireVerifiedIdentifiers = false,
    this.identifierType,
    this.identifierValue,
  });

  final Uri discoveryUrl;
  final String clientId;
  final String redirectUrl;
  final List<String> scopes;

  final bool requireVerifiedIdentifiers;
  final String? identifierType;
  final String? identifierValue;
}
