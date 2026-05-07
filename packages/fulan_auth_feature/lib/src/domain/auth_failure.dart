sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([super.message = 'Invalid credentials']);
}

final class NetworkFailure extends AuthFailure {
  const NetworkFailure([super.message = 'Network error']);
}

final class ServerFailure extends AuthFailure {
  const ServerFailure([super.message = 'Server error']);
}

final class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure([super.message = 'Unknown error']);
}
