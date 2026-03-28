import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/base_url.dart';
import '../network/secure_storage_provider.dart';

const sessionTokenKey = 'lyra_session_token';

class AuthState {
  const AuthState({required this.isAuthenticated, this.token});

  const AuthState.unauthenticated() : isAuthenticated = false, token = null;

  const AuthState.authenticated(this.token) : isAuthenticated = true;

  final bool isAuthenticated;
  final String? token;
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    return validateSessionOnStart();
  }

  Future<AuthState> validateSessionOnStart() async {
    state = const AsyncLoading();

    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: sessionTokenKey);

    if (token == null || token.isEmpty) {
      const unauthenticated = AuthState.unauthenticated();
      state = const AsyncData(unauthenticated);
      return unauthenticated;
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: ref.read(lyraApiBaseUrlProvider),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    try {
      await dio.get(
        '/auth/session',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final authenticated = AuthState.authenticated(token);
      state = AsyncData(authenticated);
      return authenticated;
    } on DioException {
      const unauthenticated = AuthState.unauthenticated();
      await storage.delete(key: sessionTokenKey);
      state = const AsyncData(unauthenticated);
      return unauthenticated;
    } catch (_) {
      await storage.delete(key: sessionTokenKey);
      const unauthenticated = AuthState.unauthenticated();
      state = const AsyncData(unauthenticated);
      return unauthenticated;
    }
  }

  void parseAndPersistTokenFromUri(Uri uri) {
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return;
    }

    state = AsyncData(AuthState.authenticated(token));
    unawaited(_persistToken(token));
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: sessionTokenKey);
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> _persistToken(String token) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: sessionTokenKey, value: token);
  }
}
