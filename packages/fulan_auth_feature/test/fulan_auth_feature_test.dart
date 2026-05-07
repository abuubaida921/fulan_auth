import 'package:flutter_test/flutter_test.dart';
import 'package:fulan_auth_feature/fulan_auth_feature.dart';

void main() {
  test('AuthSession round-trips json', () {
    final session = AuthSession(
      user: const AuthUser(id: 'u1', email: 'a@b.com'),
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: DateTime.parse('2030-01-01T00:00:00.000Z'),
    );

    final restored = AuthSession.fromJson(session.toJson());
    expect(restored.user.id, 'u1');
    expect(restored.user.email, 'a@b.com');
    expect(restored.accessToken, 'access');
    expect(restored.refreshToken, 'refresh');
    expect(
      restored.expiresAt.toUtc().toIso8601String(),
      '2030-01-01T00:00:00.000Z',
    );
  });

  test('MockAuthRepository persists and restores session', () async {
    final storage = InMemorySessionStorage();
    final repo1 = MockAuthRepository(sessionStorage: storage);

    final session1 = await repo1.signInWithEmailPassword(
      email: 'user@example.com',
      password: 'pw',
    );
    expect(session1.user.email, 'user@example.com');

    final repo2 = MockAuthRepository(sessionStorage: storage);
    final restored = await repo2.getCurrentSession();
    expect(restored?.user.email, 'user@example.com');
  });

  test('MockAuthRepository signOut clears session', () async {
    final storage = InMemorySessionStorage();
    final repo = MockAuthRepository(sessionStorage: storage);

    await repo.signInWithEmailPassword(
      email: 'user@example.com',
      password: 'pw',
    );
    await repo.signOut();

    expect(await repo.getCurrentSession(), isNull);
  });
}
