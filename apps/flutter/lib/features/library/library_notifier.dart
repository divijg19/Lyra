import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/network/lyra_endpoints.dart';
import 'models/track_filters.dart';
import 'models/track.dart';

final libraryNotifierProvider = NotifierProvider<LibraryNotifier, bool>(
  LibraryNotifier.new,
);

final semanticSearchModeProvider =
    NotifierProvider<SemanticSearchNotifier, bool>(SemanticSearchNotifier.new);

class SemanticSearchNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

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
  CancelToken? _activeCancelToken;
  int _requestVersion = 0;

  TrackFilters get currentFilters => _currentFilters;

  bool get hasActiveFilters => _currentFilters.hasAnyFilter;

  @override
  Future<List<Track>> build() async {
    ref.onDispose(() {
      _activeCancelToken?.cancel();
    });
    return fetchTracks(skip: 0, limit: 100);
  }

  Future<List<Track>> fetchTracks({
    int skip = 0,
    int limit = 100,
    String? query,
  }) async {
    final requestVersion = ++_requestVersion;
    _activeCancelToken?.cancel();
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    state = const AsyncLoading();

    final effectiveQuery = query ?? _currentSearchQuery;
    final dio = ref.read(dioProvider);
    final isSemanticSearch = ref.read(semanticSearchModeProvider);

    try {
      if (isSemanticSearch &&
          effectiveQuery != null &&
          effectiveQuery.isNotEmpty) {
        final response = await dio.get(
          '/library/search/semantic',
          queryParameters: {'q': effectiveQuery},
          cancelToken: cancelToken,
        );
        final tracks = _parseTracks(response.data);
        if (_isStaleRequest(requestVersion, cancelToken)) {
          return state.asData?.value ?? const <Track>[];
        }

        state = AsyncData(tracks);
        return tracks;
      }

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
        cancelToken: cancelToken,
      );
      final tracks = _parseTracks(response.data);
      if (_isStaleRequest(requestVersion, cancelToken)) {
        return state.asData?.value ?? const <Track>[];
      }

      state = AsyncData(tracks);
      return tracks;
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        return state.asData?.value ?? const <Track>[];
      }

      if (!_isStaleRequest(requestVersion, cancelToken)) {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    } catch (error, stackTrace) {
      if (!_isStaleRequest(requestVersion, cancelToken)) {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    } finally {
      if (identical(_activeCancelToken, cancelToken)) {
        _activeCancelToken = null;
      }
    }
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

  Future<void> setSemanticSearch(bool enabled) async {
    ref.read(semanticSearchModeProvider.notifier).setEnabled(enabled);
    state = const AsyncData(<Track>[]);
    await fetchTracks(skip: 0, limit: 100, query: _currentSearchQuery);
  }

  bool _isStaleRequest(int requestVersion, CancelToken cancelToken) {
    return requestVersion != _requestVersion ||
        !identical(_activeCancelToken, cancelToken);
  }

  List<Track> _parseTracks(Object? rawData) {
    final rawList = rawData as List<dynamic>;
    return rawList
        .map((item) => Track.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
