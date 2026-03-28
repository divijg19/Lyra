import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const lyraApiBaseUrl = String.fromEnvironment(
  'LYRA_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: lyraApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
});
