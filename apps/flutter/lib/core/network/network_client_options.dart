import 'package:dio/dio.dart';

BaseOptions createLyraApiBaseOptions(String baseUrl) {
  return BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    responseType: ResponseType.json,
  );
}
