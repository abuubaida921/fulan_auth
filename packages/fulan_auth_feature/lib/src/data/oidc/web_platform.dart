import 'web_platform_interface.dart';
import 'web_platform_stub.dart'
    if (dart.library.html) 'web_platform_web.dart'
    as impl;

export 'web_platform_interface.dart';

WebPlatform get webPlatform => impl.webPlatform;
