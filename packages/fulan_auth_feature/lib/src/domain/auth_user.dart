class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;

  Map<String, Object?> toJson() => {'id': id, 'email': email};

  static AuthUser fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! String || email is! String) {
      throw const FormatException('Invalid AuthUser json');
    }
    return AuthUser(id: id, email: email);
  }
}
