import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/network/lyra_endpoints.dart';
import 'models/track.dart';
import 'models/track_filters.dart';

const _unset = Object();

final libraryNotifierProvider =
    NotifierProvider<LibraryNotifier, LibrarySyncState>(LibraryNotifier.new);

final semanticSearchModeProvider =
    NotifierProvider<SemanticSearchNotifier, bool>(SemanticSearchNotifier.new);

class LibrarySyncState {
  const LibrarySyncState({
    this.syncStatus = 'IDLE',
    this.lastSyncedAt,
    this.errorMessage,
  });

  final String syncStatus;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  bool get isSyncing => syncStatus == 'IN_PROGRESS';

  LibrarySyncState copyWith({
    String? syncStatus,
    Object? lastSyncedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return LibrarySyncState(
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: identical(lastSyncedAt, _unset)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class SemanticSearchNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

class LibraryNotifier extends Notifier<LibrarySyncState> {
  Timer? _pollingTimer;
  bool _isPollingRequestInFlight = false;
  bool _didLoadInitialStatus = false;

  @override
  LibrarySyncState build() {
    ref.onDispose(_cancelPolling);
    if (!_didLoadInitialStatus) {
      _didLoadInitialStatus = true;
      unawaited(_loadCurrentStatus());
    }
    return const LibrarySyncState();
  }

  Future<void> syncLibrary() async {
    _cancelPolling();
    state = state.copyWith(syncStatus: 'IN_PROGRESS', errorMessage: null);

    try {
      final dio = ref.read(dioProvider);
      final uri = ref.read(librarySyncUriProvider);
      await dio.post(uri.toString());
      _startPolling();
    } on DioException catch (error) {
      _setError(_extractSyncErrorMessage(error));
      rethrow;
    } catch (_) {
      _setError('Failed to start sync.');
      rethrow;
    }
  }

  void _startPolling() {
    _cancelPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollSyncStatus());
    });
    unawaited(_pollSyncStatus());
  }

  void _cancelPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadCurrentStatus() async {
    try {
      await _pollSyncStatus(triggerRefreshOnIdle: false);
    } catch (_) {
      // Keep the library usable even if the sync status probe fails.
    }
  }

  Future<void> _pollSyncStatus({bool triggerRefreshOnIdle = true}) async {
    if (_isPollingRequestInFlight) {
      return;
    }

    _isPollingRequestInFlight = true;
    try {
      final dio = ref.read(dioProvider);
      final uri = ref.read(librarySyncStatusUriProvider);
      final response = await dio.get(uri.toString());
      final nextState = _parseSyncState(response.data as Map<String, dynamic>);
      state = state.copyWith(
        syncStatus: nextState.syncStatus,
        lastSyncedAt: nextState.lastSyncedAt,
        errorMessage: nextState.errorMessage,
      );

      if (nextState.syncStatus == 'IN_PROGRESS') {
        if (_pollingTimer == null) {
          _startPolling();
        }
        return;
      }

      _cancelPolling();

      if (nextState.syncStatus == 'IDLE' && triggerRefreshOnIdle) {
        unawaited(ref.read(tracksNotifierProvider.notifier).fetchTracks());
      }
    } on DioException {
      // If polling hits a transient connectivity issue, keep the current state
      // and allow the next timer tick to retry.
    } finally {
      _isPollingRequestInFlight = false;
    }
  }

  LibrarySyncState _parseSyncState(Map<String, dynamic> json) {
    final rawStatus = (json['sync_status'] as String? ?? 'IDLE').toUpperCase();
    final lastSyncedAtRaw = json['last_synced_at'] as String?;
    final lastSyncedAt = lastSyncedAtRaw == null
        ? null
        : DateTime.tryParse(lastSyncedAtRaw);

    if (rawStatus == 'ERROR') {
      return LibrarySyncState(
        syncStatus: rawStatus,
        lastSyncedAt: lastSyncedAt,
        errorMessage: 'Library sync failed. Try syncing again.',
      );
    }

    return LibrarySyncState(
      syncStatus: rawStatus,
      lastSyncedAt: lastSyncedAt,
      errorMessage: null,
    );
  }

  void _setError(String message) {
    _cancelPolling();
    state = state.copyWith(syncStatus: 'ERROR', errorMessage: message);
  }

  String _extractSyncErrorMessage(DioException error) {
    final responseMessage = error.response?.data;
    if (responseMessage case {'detail': final String detail}) {
      return detail;
    }
    return 'Failed to start sync.';
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

  bool get hasActiveQuery => _currentSearchQuery?.isNotEmpty == true;

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
