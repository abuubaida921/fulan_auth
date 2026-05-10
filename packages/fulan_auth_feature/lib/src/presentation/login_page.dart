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
  final _identifierValueController = TextEditingController();
  final _otpCodeController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;
  String _identifierType = 'email';
  String? _otpId;

  bool get _isOidc => widget.authRepository is OidcAuthRepository;
  bool get _requiresVerifiedIdentifiers =>
      widget.authRepository is OidcAuthRepository &&
      (widget.authRepository as OidcAuthRepository).requireVerifiedIdentifiers;

  @override
  void initState() {
    super.initState();
    final repo = widget.authRepository;
    if (repo is OidcAuthRepository) {
      final error = repo.consumeLastWebAuthError();
      if (error != null && error.isNotEmpty) {
        _errorText = error;
      }
    }
    _identifierValueController.addListener(() {
      if (_otpId != null) {
        setState(() => _otpId = null);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _identifierValueController.dispose();
    _otpCodeController.dispose();
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

  Future<void> _sendOtp() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final repo = widget.authRepository;
      if (repo is! OidcAuthRepository) {
        throw const InvalidRequestFailure('OTP is only supported for OIDC');
      }

      final identifierValue = _identifierValueController.text.trim();
      if (identifierValue.isEmpty) {
        throw const InvalidRequestFailure('Identifier value is required');
      }

      final result = await repo.requestOtp(
        identifierType: _identifierType,
        identifierValue: identifierValue,
      );
      print('==================================');
      print(result.code);
      print(result.otpId);
      print(result.expiresInSeconds);

      if (!mounted) return;
      setState(() {
        _otpId = result.otpId;
      });
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

  Future<void> _verifyOtpAndContinue() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final repo = widget.authRepository;
      if (repo is! OidcAuthRepository) {
        throw const InvalidRequestFailure('OTP is only supported for OIDC');
      }

      final otpId = _otpId;
      if (otpId == null || otpId.isEmpty) {
        throw const InvalidRequestFailure('Send OTP first');
      }

      final otpCode = _otpCodeController.text.trim();
      if (otpCode.isEmpty) {
        throw const InvalidRequestFailure('OTP code is required');
      }

      await repo.verifyOtp(otpId: otpId, code: otpCode);

      final identifierValue = _identifierValueController.text.trim();
      await repo.signInWithVerifiedIdentifier(
        identifierType: _identifierType,
        identifierValue: identifierValue,
      );

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
                if (_isOidc && _requiresVerifiedIdentifiers) ...[
                  Text('Verify identifier', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _identifierType,
                    items: const [
                      DropdownMenuItem(value: 'email', child: Text('Email')),
                      DropdownMenuItem(
                        value: 'phoneNumber',
                        child: Text('Phone number'),
                      ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _identifierType = value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'Identifier type',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _identifierValueController,
                    keyboardType: _identifierType == 'email'
                        ? TextInputType.emailAddress
                        : TextInputType.phone,
                    autofillHints: _identifierType == 'email'
                        ? const [AutofillHints.email]
                        : const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(
                      labelText: _identifierType == 'email'
                          ? 'Email'
                          : 'Phone number',
                    ),
                    onSubmitted: (_) =>
                        _otpId == null ? _sendOtp() : _verifyOtpAndContinue(),
                  ),
                  const SizedBox(height: 16),
                  if (_otpId != null) ...[
                    TextField(
                      controller: _otpCodeController,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(labelText: 'OTP code'),
                      onSubmitted: (_) => _verifyOtpAndContinue(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
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
                if (_isOidc && _requiresVerifiedIdentifiers)
                  FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : (_otpId == null ? _sendOtp : _verifyOtpAndContinue),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _otpId == null ? 'Send OTP' : 'Verify & Continue',
                          ),
                  )
                else
                  FilledButton(
                    onPressed: _isSubmitting ? null : _signIn,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
