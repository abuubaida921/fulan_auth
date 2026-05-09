abstract interface class WebPlatform {
  Uri get currentUri;

  void redirectTo(String url);

  void replaceUrl(String url);

  String? readSessionValue(String key);

  void writeSessionValue(String key, String value);

  void removeSessionValue(String key);
}
