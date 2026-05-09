import 'web_platform_interface.dart';

final WebPlatform webPlatform = _UnsupportedWebPlatform();

final class _UnsupportedWebPlatform implements WebPlatform {
  @override
  Uri get currentUri => Uri();

  @override
  String? readSessionValue(String key) => null;

  @override
  void redirectTo(String url) {
    throw UnsupportedError('Web platform not available');
  }

  @override
  void removeSessionValue(String key) {}

  @override
  void replaceUrl(String url) {}

  @override
  void writeSessionValue(String key, String value) {}
}
