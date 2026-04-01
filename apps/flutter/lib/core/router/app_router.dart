import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../../features/auth/presentation/auth_callback_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/main_tabs_screen.dart';
import '../../features/playlists/models/playlist.dart';
import '../../features/playlists/ui/playlist_details_screen.dart';
import '../../features/playlists/ui/playlists_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier<int>(0);
  ref.onDispose(refreshListenable.dispose);
  ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (_, _) {
    refreshListenable.value++;
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);
      final uri = state.uri;
      final atSplash = state.matchedLocation == '/splash';
      final atLogin = state.matchedLocation == '/login';
      final atCallback = state.matchedLocation == '/callback';

      if (uri.scheme == 'lyra' && uri.host == 'callback') {
        ref
            .read(authNotifierProvider.notifier)
            .parseAndPersistTokenFromUri(uri);
        return '/';
      }

      if (authState.isLoading) {
        if (!atSplash) {
          return '/splash';
        }
        return null;
      }

      final isAuthenticated = authState.asData?.value.isAuthenticated == true;

      if (!isAuthenticated && !atLogin && !atCallback) {
        return '/login';
      }

      if (isAuthenticated && (atLogin || atCallback || atSplash)) {
        return '/';
      }

      if (!isAuthenticated && atSplash) {
        return '/login';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainTabsScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (BuildContext context, GoRouterState state) {
                  return const HomeScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playlists',
                name: 'playlists',
                builder: (BuildContext context, GoRouterState state) {
                  return const PlaylistsScreen();
                },
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'playlist-details',
                    builder: (BuildContext context, GoRouterState state) {
                      final maybePlaylist = state.extra is Playlist
                          ? state.extra as Playlist
                          : null;
                      return PlaylistDetailsScreen(
                        playlistId: state.pathParameters['id']!,
                        playlistName: maybePlaylist?.name,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
