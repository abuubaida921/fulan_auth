import 'auth_session.dart';

abstract interface class AuthRepository {
  Stream<AuthSession?> watchSession();

  Future<AuthSession?> getCurrentSession();

  Future<AuthSession> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
