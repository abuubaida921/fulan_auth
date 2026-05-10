import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fulan_auth_feature/fulan_auth_feature.dart';
import 'package:http/http.dart' as http;

void main() {
  test('OtpSendResult parses response json', () {
    final result = OtpSendResult.fromJson(const {
      'code': '123456',
      'expires_in_seconds': 60,
      'otp_id': 'otp_1',
    });

    expect(result.code, '123456');
    expect(result.expiresInSeconds, 60);
    expect(result.otpId, 'otp_1');
  });

  test('OidcAuthRepository requestOtp uses json and parses response', () async {
    final calls = <_Call>[];
    final client = _FakeClient((request) async {
      calls.add(_Call(request.method, request.url, request));

      if (request.method == 'GET' &&
          request.url.path == '/.well-known/openid-configuration') {
        return _jsonResponse({
          'issuer': 'https://fulan.dawahtours.com',
          'authorization_endpoint': 'https://fulan.dawahtours.com/authorize',
          'token_endpoint': 'https://fulan.dawahtours.com/token',
          'jwks_uri': 'https://fulan.dawahtours.com/.well-known/jwks.json',
          'userinfo_endpoint': 'https://fulan.dawahtours.com/userinfo',
        });
      }

      if (request.method == 'POST' && request.url.path == '/otp/send') {
        expect(request.headers['content-type'], 'application/json');
        final body = _readJsonBody(request);
        expect(body['client_id'], 'app_test');
        expect(body['identifier_type'], 'email');
        expect(body['identifier_value'], 'a@b.com');
        return _jsonResponse({
          'code': '123456',
          'expires_in_seconds': 60,
          'otp_id': 'otp_1',
        });
      }

      return _textResponse(404, 'not found');
    });

    final repo = OidcAuthRepository(
      config: OidcConfig(
        discoveryUrl: Uri.parse(
          'https://fulan.dawahtours.com/.well-known/openid-configuration',
        ),
        clientId: 'app_test',
        redirectUrl: 'com.example.app://oauthredirect',
        scopes: const ['openid'],
        requireVerifiedIdentifiers: true,
      ),
      sessionStorage: InMemorySessionStorage(),
      httpClient: client,
    );

    final result = await repo.requestOtp(
      identifierType: 'email',
      identifierValue: 'a@b.com',
    );

    expect(result.otpId, 'otp_1');
    expect(result.expiresInSeconds, 60);
    expect(result.code, '123456');

    expect(calls.map((c) => '${c.method} ${c.url.path}').toList(), [
      'GET /.well-known/openid-configuration',
      'POST /otp/send',
    ]);
  });

  test('OidcAuthRepository verifyOtp maps invalid OTP (400)', () async {
    final client = _FakeClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/.well-known/openid-configuration') {
        return _jsonResponse({
          'issuer': 'https://fulan.dawahtours.com',
          'authorization_endpoint': 'https://fulan.dawahtours.com/authorize',
          'token_endpoint': 'https://fulan.dawahtours.com/token',
          'jwks_uri': 'https://fulan.dawahtours.com/.well-known/jwks.json',
          'userinfo_endpoint': 'https://fulan.dawahtours.com/userinfo',
        });
      }
      if (request.method == 'POST' && request.url.path == '/otp/verify') {
        return _textResponse(400, '');
      }
      return _textResponse(404, 'not found');
    });

    final repo = OidcAuthRepository(
      config: OidcConfig(
        discoveryUrl: Uri.parse(
          'https://fulan.dawahtours.com/.well-known/openid-configuration',
        ),
        clientId: 'app_test',
        redirectUrl: 'com.example.app://oauthredirect',
        scopes: const ['openid'],
        requireVerifiedIdentifiers: true,
      ),
      sessionStorage: InMemorySessionStorage(),
      httpClient: client,
    );

    await expectLater(
      () => repo.verifyOtp(otpId: 'otp_1', code: '000000'),
      throwsA(isA<OtpInvalidFailure>()),
    );
  });

  test('OidcAuthRepository verifyOtp maps rate limited (429)', () async {
    final client = _FakeClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/.well-known/openid-configuration') {
        return _jsonResponse({
          'issuer': 'https://fulan.dawahtours.com',
          'authorization_endpoint': 'https://fulan.dawahtours.com/authorize',
          'token_endpoint': 'https://fulan.dawahtours.com/token',
          'jwks_uri': 'https://fulan.dawahtours.com/.well-known/jwks.json',
          'userinfo_endpoint': 'https://fulan.dawahtours.com/userinfo',
        });
      }
      if (request.method == 'POST' && request.url.path == '/otp/verify') {
        return _textResponse(429, '');
      }
      return _textResponse(404, 'not found');
    });

    final repo = OidcAuthRepository(
      config: OidcConfig(
        discoveryUrl: Uri.parse(
          'https://fulan.dawahtours.com/.well-known/openid-configuration',
        ),
        clientId: 'app_test',
        redirectUrl: 'com.example.app://oauthredirect',
        scopes: const ['openid'],
        requireVerifiedIdentifiers: true,
      ),
      sessionStorage: InMemorySessionStorage(),
      httpClient: client,
    );

    await expectLater(
      () => repo.verifyOtp(otpId: 'otp_1', code: '000000'),
      throwsA(isA<OtpRateLimitedFailure>()),
    );
  });
}

typedef _Handler = Future<http.Response> Function(http.BaseRequest request);

final class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final _Handler _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    final stream = Stream<List<int>>.value(response.bodyBytes);
    return http.StreamedResponse(
      stream,
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

final class _Call {
  const _Call(this.method, this.url, this.request);

  final String method;
  final Uri url;
  final http.BaseRequest request;
}

http.Response _jsonResponse(Map<String, Object?> json, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(json),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

http.Response _textResponse(int statusCode, String body) {
  return http.Response(body, statusCode);
}

Map<String, Object?> _readJsonBody(http.BaseRequest request) {
  if (request is! http.Request) {
    throw StateError('Unexpected request type: ${request.runtimeType}');
  }
  return Map<String, Object?>.from(jsonDecode(request.body) as Map);
}
