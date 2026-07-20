import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyra/core/auth/auth_notifier.dart';
import 'package:lyra/features/home/presentation/home_screen.dart';
import 'package:lyra/features/library/library_notifier.dart';
import 'package:lyra/features/library/models/track.dart';
import 'package:lyra/features/library/models/track_filters.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async {
    return const AuthState.authenticated('test-token');
  }
}

class _TestLibraryNotifier extends LibraryNotifier {
  _TestLibraryNotifier(this._initialState);

  final LibrarySyncState _initialState;

  @override
  LibrarySyncState build() => _initialState;
}

class _TestTracksNotifier extends TracksNotifier {
  _TestTracksNotifier({
    required this.initialTracks,
    this.activeFilters = false,
    this.activeQuery = false,
  });

  final List<Track> initialTracks;
  final bool activeFilters;
  final bool activeQuery;

  @override
  TrackFilters get currentFilters => activeFilters
      ? const TrackFilters(minBpm: 120)
      : TrackFilters.empty;

  @override
  bool get hasActiveFilters => activeFilters;

  @override
  bool get hasActiveQuery => activeQuery;

  @override
  Future<List<Track>> build() async => initialTracks;

  @override
  Future<List<Track>> fetchTracks({
    int skip = 0,
    int limit = 100,
    String? query,
  }) async {
    state = AsyncData(initialTracks);
    return initialTracks;
  }
}

Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required LibrarySyncState syncState,
  required List<Track> tracks,
  bool activeFilters = false,
  bool activeQuery = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
        libraryNotifierProvider.overrideWith(
          () => _TestLibraryNotifier(syncState),
        ),
        tracksNotifierProvider.overrideWith(
          () => _TestTracksNotifier(
            initialTracks: tracks,
            activeFilters: activeFilters,
            activeQuery: activeQuery,
          ),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('HomeScreen shows the empty library state', (
    WidgetTester tester,
  ) async {
    await _pumpHomeScreen(
      tester,
      syncState: const LibrarySyncState(syncStatus: 'IDLE'),
      tracks: const <Track>[],
    );

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Tap Sync to import from Spotify.'), findsOneWidget);
  });

  testWidgets('HomeScreen shows sync progress and disables sync action', (
    WidgetTester tester,
  ) async {
    await _pumpHomeScreen(
      tester,
      syncState: const LibrarySyncState(syncStatus: 'IN_PROGRESS'),
      tracks: const <Track>[],
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final syncButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(syncButton.onPressed, isNull);
  });
}
