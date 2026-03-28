import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../../features/auth/presentation/auth_callback_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier<int>(0);
  ref.onDispose(refreshListenable.dispose);
  ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (_, _) {
    refreshListenable.value++;
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);
      final uri = state.uri;

      if (uri.scheme == 'lyra' && uri.host == 'callback') {
        ref
            .read(authNotifierProvider.notifier)
            .parseAndPersistTokenFromUri(uri);
        return '/';
      }

      if (authState.isLoading) {
        return null;
      }

      final isAuthenticated = authState.valueOrNull?.isAuthenticated == true;
      final atLogin = state.matchedLocation == '/login';
      final atCallback = state.matchedLocation == '/callback';

      if (!isAuthenticated && !atLogin && !atCallback) {
        return '/login';
      }

      if (isAuthenticated && (atLogin || atCallback)) {
        return '/';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/callback',
        name: 'callback',
        builder: (BuildContext context, GoRouterState state) {
          return AuthCallbackScreen(uri: state.uri);
        },
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
      ),
    ],
  );
});
