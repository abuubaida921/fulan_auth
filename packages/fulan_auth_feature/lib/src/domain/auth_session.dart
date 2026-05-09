import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  });

  final AuthUser user;
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, Object?> toJson() => {
    'user': user.toJson(),
    'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  static AuthSession fromJson(Map<String, Object?> json) {
    final userJson = json['user'];
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresAt = json['expiresAt'];

    if (userJson is! Map) {
      throw const FormatException('Invalid AuthSession json (user)');
    }
    if (accessToken is! String || expiresAt is! String) {
      throw const FormatException('Invalid AuthSession json');
    }
    if (refreshToken != null && refreshToken is! String) {
      throw const FormatException('Invalid AuthSession json');
    }

    return AuthSession(
      user: AuthUser.fromJson(Map<String, Object?>.from(userJson)),
      accessToken: accessToken,
      refreshToken: refreshToken as String?,
      expiresAt: DateTime.parse(expiresAt),
    );
  }
}
