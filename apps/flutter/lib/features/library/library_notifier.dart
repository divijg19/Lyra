import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/network/lyra_endpoints.dart';
import 'models/track_filters.dart';
import 'models/track.dart';

final libraryNotifierProvider = NotifierProvider<LibraryNotifier, bool>(
  LibraryNotifier.new,
);

class LibraryNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> startSync() async {
    state = true;
    try {
      final dio = ref.read(dioProvider);
      final uri = ref.read(librarySyncUriProvider);
      await dio.post(uri.toString());
    } finally {
      // Keep spinner visible briefly so the user receives immediate feedback.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      state = false;
    }
  }
}

final tracksNotifierProvider =
    AsyncNotifierProvider<TracksNotifier, List<Track>>(TracksNotifier.new);

class TracksNotifier extends AsyncNotifier<List<Track>> {
  String? _currentSearchQuery;
  TrackFilters _currentFilters = TrackFilters.empty;

  TrackFilters get currentFilters => _currentFilters;

  bool get hasActiveFilters => _currentFilters.hasAnyFilter;

  @override
  Future<List<Track>> build() async {
    return fetchTracks(skip: 0, limit: 100);
  }

  Future<List<Track>> fetchTracks({
    int skip = 0,
    int limit = 100,
    String? query,
  }) async {
    state = const AsyncLoading();

    final effectiveQuery = query ?? _currentSearchQuery;
    final dio = ref.read(dioProvider);
    final queryParameters = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      if (effectiveQuery != null && effectiveQuery.isNotEmpty)
        'q': effectiveQuery,
      if (_currentFilters.minBpm != null) 'min_bpm': _currentFilters.minBpm,
      if (_currentFilters.maxBpm != null) 'max_bpm': _currentFilters.maxBpm,
      if (_currentFilters.minEnergy != null)
        'min_energy': _currentFilters.minEnergy,
      if (_currentFilters.maxEnergy != null)
        'max_energy': _currentFilters.maxEnergy,
      if (_currentFilters.minValence != null)
        'min_valence': _currentFilters.minValence,
      if (_currentFilters.maxValence != null)
        'max_valence': _currentFilters.maxValence,
    };

    final response = await dio.get(
      '/library/tracks',
      queryParameters: queryParameters,
    );
    final rawList = response.data as List<dynamic>;
    final tracks = rawList
        .map((item) => Track.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    state = AsyncData(tracks);
    return tracks;
  }

  Future<void> searchTracks(String query) async {
    final normalized = query.trim();
    _currentSearchQuery = normalized.isEmpty ? null : normalized;

    // Clear current list before fetching fresh search results from page start.
    state = const AsyncData(<Track>[]);
    await fetchTracks(skip: 0, limit: 100, query: _currentSearchQuery);
  }

  Future<void> applyFilters(TrackFilters filters) async {
    _currentFilters = filters;
    state = const AsyncData(<Track>[]);
    await fetchTracks(skip: 0, limit: 100, query: _currentSearchQuery);
  }
}
