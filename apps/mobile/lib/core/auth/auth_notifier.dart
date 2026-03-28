import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/secure_storage_provider.dart';

const _sessionTokenKey = 'lyra_session_token';

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
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: _sessionTokenKey);

    if (token == null || token.isEmpty) {
      return const AuthState.unauthenticated();
    }

    return AuthState.authenticated(token);
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
    await storage.delete(key: _sessionTokenKey);
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> _persistToken(String token) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: _sessionTokenKey, value: token);
  }
}
