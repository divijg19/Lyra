import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import 'base_url.dart';
import 'network_client_options.dart';
import 'secure_storage_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);
  final dio = Dio(createLyraApiBaseOptions(baseUrl));

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final authState = ref.read(authNotifierProvider).asData?.value;
        var token = authState?.token;
        if (token == null || token.isEmpty) {
          final storage = ref.read(secureStorageProvider);
          token = await storage.read(key: sessionTokenKey);
        }

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final shouldSkipLogout =
            error.requestOptions.extra['skipLogoutOnUnauthorized'] == true;
        if (!shouldSkipLogout && error.response?.statusCode == 401) {
          await ref.read(authNotifierProvider.notifier).logout();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
