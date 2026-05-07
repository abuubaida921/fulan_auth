import 'package:flutter/material.dart';

import '../data/oidc/oidc_auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';

class FulanLoginPage extends StatefulWidget {
  const FulanLoginPage({
    super.key,
    required this.authRepository,
    this.onSignedIn,
    this.title = 'Sign in',
  });

  final AuthRepository authRepository;
  final VoidCallback? onSignedIn;
  final String title;

  @override
  State<FulanLoginPage> createState() => _FulanLoginPageState();
}

class _FulanLoginPageState extends State<FulanLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  bool get _isOidc => widget.authRepository is OidcAuthRepository;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      final repo = widget.authRepository;
      if (repo is OidcAuthRepository) {
        await repo.signIn();
      } else {
        await repo.signInWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      widget.onSignedIn?.call();
    } on AuthFailure catch (e) {
      setState(() => _errorText = e.message);
    } catch (_) {
      setState(() => _errorText = const UnknownAuthFailure().message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isOidc) ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_errorText case final String msg)
                  Text(
                    msg,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                if (_errorText != null) const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isSubmitting ? null : _signIn,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isOidc ? 'Continue' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
