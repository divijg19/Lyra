import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import 'models/playlist.dart';

final playlistsNotifierProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(
      PlaylistsNotifier.new,
    );

class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    return fetchPlaylists();
  }

  Future<List<Playlist>> fetchPlaylists() async {
    state = const AsyncLoading();

    final dio = ref.read(dioProvider);
    final response = await dio.get('/playlists');
    final rawList = response.data as List<dynamic>;
    final playlists = rawList
        .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    state = AsyncData(playlists);
    return playlists;
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
    } on DioException {
      rethrow;
    }
  }
}
