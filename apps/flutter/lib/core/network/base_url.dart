import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

String resolveLyraApiBaseUrl() {
  const configuredBaseUrl = String.fromEnvironment('LYRA_API_BASE_URL');
  if (configuredBaseUrl.isNotEmpty) {
    return configuredBaseUrl;
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }

  if (Platform.isIOS ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isWindows) {
    return 'http://127.0.0.1:8000';
  }

  return 'http://127.0.0.1:8000';
}

final lyraApiBaseUrlProvider = Provider<String>((ref) {
  return resolveLyraApiBaseUrl();
});
