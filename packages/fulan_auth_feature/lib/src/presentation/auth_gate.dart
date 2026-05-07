import 'package:flutter/material.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

class FulanAuthGate extends StatelessWidget {
  const FulanAuthGate({
    super.key,
    required this.authRepository,
    required this.signedOutBuilder,
    required this.signedInBuilder,
  });

  final AuthRepository authRepository;
  final WidgetBuilder signedOutBuilder;
  final Widget Function(BuildContext context, AuthSession session)
  signedInBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: authRepository.watchSession(),
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) {
          return signedOutBuilder(context);
        }
        return signedInBuilder(context, session);
      },
    );
  }
}
