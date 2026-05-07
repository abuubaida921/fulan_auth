import 'dart:convert';

import 'package:http/http.dart' as http;

final class OidcDiscoveryDocument {
  const OidcDiscoveryDocument({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.jwksUri,
    required this.userinfoEndpoint,
  });

  final Uri issuer;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri jwksUri;
  final Uri userinfoEndpoint;

  static Future<OidcDiscoveryDocument> fetch({
    required Uri discoveryUrl,
    required http.Client client,
  }) async {
    final response = await client.get(
      discoveryUrl,
      headers: const {'accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OidcDiscoveryException('Discovery failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const OidcDiscoveryException('Malformed discovery document');
    }

    Uri requireUri(String key) {
      final value = decoded[key];
      if (value is! String) {
        throw OidcDiscoveryException('Missing $key');
      }
      return Uri.parse(value.trim().replaceAll('`', ''));
    }

    return OidcDiscoveryDocument(
      issuer: requireUri('issuer'),
      authorizationEndpoint: requireUri('authorization_endpoint'),
      tokenEndpoint: requireUri('token_endpoint'),
      jwksUri: requireUri('jwks_uri'),
      userinfoEndpoint: requireUri('userinfo_endpoint'),
    );
  }
}

final class OidcDiscoveryException implements Exception {
  const OidcDiscoveryException(this.message);
  final String message;

  @override
  String toString() => 'OidcDiscoveryException($message)';
}
