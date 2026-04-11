import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../library/models/track.dart';
import 'models/playlist.dart';

final playlistsNotifierProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(
      PlaylistsNotifier.new,
    );

class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  CancelToken? _fetchCancelToken;
  int _fetchVersion = 0;

  @override
  Future<List<Playlist>> build() async {
    ref.onDispose(() {
      _fetchCancelToken?.cancel();
    });
    return fetchPlaylists();
  }

  Future<List<Playlist>> fetchPlaylists() async {
    final fetchVersion = ++_fetchVersion;
    _fetchCancelToken?.cancel();
    final cancelToken = CancelToken();
    _fetchCancelToken = cancelToken;
    state = const AsyncLoading();

    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/playlists', cancelToken: cancelToken);
      final playlists = _parsePlaylists(response.data);
      if (_isStaleFetch(fetchVersion, cancelToken)) {
        return state.asData?.value ?? const <Playlist>[];
      }

      state = AsyncData(playlists);
      return playlists;
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        return state.asData?.value ?? const <Playlist>[];
      }

      if (!_isStaleFetch(fetchVersion, cancelToken)) {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    } catch (error, stackTrace) {
      if (!_isStaleFetch(fetchVersion, cancelToken)) {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    } finally {
      if (identical(_fetchCancelToken, cancelToken)) {
        _fetchCancelToken = null;
      }
    }
  }

  Future<Playlist> createPlaylist({
    required String name,
    String? description,
  }) async {
    final dio = ref.read(dioProvider);

    final response = await dio.post(
      '/playlists',
      data: {'name': name, 'description': description},
    );

    final created = Playlist.fromJson(response.data as Map<String, dynamic>);
    final current = state.asData?.value ?? const <Playlist>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> addTrackToPlaylist({
    required String playlistId,
    required String trackId,
  }) async {
    final dio = ref.read(dioProvider);

    try {
      await dio.post(
        '/playlists/$playlistId/tracks',
        data: {'track_id': trackId},
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        throw 'Track already in playlist';
      }
      rethrow;
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/playlists/$playlistId');

    final current = state.asData?.value ?? const <Playlist>[];
    state = AsyncData(
      current.where((playlist) => playlist.id != playlistId).toList(),
    );
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/playlists/$playlistId/tracks/$trackId');
  }

  Future<List<Track>> fetchPlaylistTracks(String playlistId) async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/playlists/$playlistId/tracks');
    final rawList = response.data as List<dynamic>;
    return rawList
        .map((item) => Track.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  bool _isStaleFetch(int fetchVersion, CancelToken cancelToken) {
    return fetchVersion != _fetchVersion ||
        !identical(_fetchCancelToken, cancelToken);
  }

  List<Playlist> _parsePlaylists(Object? rawData) {
    final rawList = rawData as List<dynamic>;
    return rawList
        .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final playlistTracksProvider = FutureProvider.family<List<Track>, String>((
  ref,
  playlistId,
) async {
  return ref
      .read(playlistsNotifierProvider.notifier)
      .fetchPlaylistTracks(playlistId);
});
