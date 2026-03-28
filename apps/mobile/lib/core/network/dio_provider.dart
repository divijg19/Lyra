import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String resolveLyraApiBaseUrl() {
  const configuredBaseUrl = String.fromEnvironment('LYRA_API_BASE_URL');
  if (configuredBaseUrl.isNotEmpty) {
    return configuredBaseUrl;
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }

  return 'http://localhost:8000';
}

final lyraApiBaseUrlProvider = Provider<String>((ref) {
  return resolveLyraApiBaseUrl();
});

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);

  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
});
