import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fulan_auth_feature/fulan_auth_feature.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const clientId = String.fromEnvironment(
    'FULAN_OIDC_CLIENT_ID',
    defaultValue: 'app_ceu1sVKY0I9loOsbkehDGw',
  );
  const webRedirectUrl = String.fromEnvironment(
    'FULAN_OIDC_WEB_REDIRECT_URL',
    defaultValue: 'http://localhost:3000/portal/callback',
  );
  const mobileRedirectUrl = String.fromEnvironment(
    'FULAN_OIDC_MOBILE_REDIRECT_URL',
    defaultValue: 'com.fulan.dawahtours.fulan_auth://oauthredirect',
  );
  final redirectUrl = kIsWeb ? webRedirectUrl : mobileRedirectUrl;

  final sessionStorage = SecureSessionStorage();
  final AuthRepository authRepository;

  final supportsOidc =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  if (supportsOidc && clientId.isNotEmpty && redirectUrl.isNotEmpty) {
    authRepository = OidcAuthRepository(
      config: OidcConfig(
        discoveryUrl: Uri.parse(
          'https://fulan.dawahtours.com/.well-known/openid-configuration',
        ),
        clientId: clientId,
        redirectUrl: redirectUrl,
        scopes: const ['openid'],
      ),
      sessionStorage: sessionStorage,
    );
  } else {
    authRepository = MockAuthRepository(sessionStorage: sessionStorage);
  }

  runApp(MyApp(authRepository: authRepository));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fulan Auth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: FulanAuthGate(
        authRepository: authRepository,
        signedOutBuilder: (context) => FulanLoginPage(
          authRepository: authRepository,
          title: 'Sign in to Fulan',
        ),
        signedInBuilder: (context, session) => SignedInHomePage(
          session: session,
          onSignOut: authRepository.signOut,
        ),
      ),
    );
  }
}

class SignedInHomePage extends StatelessWidget {
  const SignedInHomePage({
    super.key,
    required this.session,
    required this.onSignOut,
  });

  final AuthSession session;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Signed in as'),
            Text(
              session.user.email,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onSignOut, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}
