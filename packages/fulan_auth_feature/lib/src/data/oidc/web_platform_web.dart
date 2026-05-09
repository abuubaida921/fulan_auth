import 'package:web/web.dart' as web;

import 'web_platform_interface.dart';

final WebPlatform webPlatform = _WebPlatform();

final class _WebPlatform implements WebPlatform {
  @override
  Uri get currentUri => Uri.parse(web.window.location.href);

  @override
  void redirectTo(String url) {
    web.window.location.assign(url);
  }

  @override
  void replaceUrl(String url) {
    web.window.history.replaceState(null, '', url);
  }

  @override
  String? readSessionValue(String key) =>
      web.window.sessionStorage.getItem(key);

  @override
  void writeSessionValue(String key, String value) {
    web.window.sessionStorage.setItem(key, value);
  }

  @override
  void removeSessionValue(String key) {
    web.window.sessionStorage.removeItem(key);
  }
}
