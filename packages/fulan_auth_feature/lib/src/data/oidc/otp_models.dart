class OtpSendResult {
  const OtpSendResult({
    required this.otpId,
    required this.expiresInSeconds,
    required this.code,
  });

  final String otpId;
  final int expiresInSeconds;
  final String code;

  static OtpSendResult fromJson(Map<String, Object?> json) {
    final otpId = json['otp_id'];
    final expiresInSeconds = json['expires_in_seconds'];
    final code = json['code'];

    if (otpId is! String || expiresInSeconds is! int || code is! String) {
      throw const FormatException('Invalid otp/send response');
    }

    return OtpSendResult(
      otpId: otpId,
      expiresInSeconds: expiresInSeconds,
      code: code,
    );
  }
}
