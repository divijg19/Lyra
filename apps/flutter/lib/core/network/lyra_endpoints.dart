import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_url.dart';

final spotifyLoginUriProvider = Provider<Uri>((ref) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);
  return Uri.parse('$baseUrl/auth/spotify/login');
});

final librarySyncUriProvider = Provider<Uri>((ref) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);
  return Uri.parse('$baseUrl/library/sync');
});

final librarySyncStatusUriProvider = Provider<Uri>((ref) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);
  return Uri.parse('$baseUrl/library/sync/status');
});

final libraryTracksUriProvider = Provider.family<Uri, ({int skip, int limit})>((
  ref,
  pagination,
) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);
  return Uri.parse('$baseUrl/library/tracks').replace(
    queryParameters: {
      'skip': '${pagination.skip}',
      'limit': '${pagination.limit}',
    },
  );
});

final playlistUriProvider = Provider.family<Uri, String>((ref, playlistId) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);
  return Uri.parse('$baseUrl/playlists/$playlistId');
});

final playlistTrackUriProvider =
    Provider.family<Uri, ({String playlistId, String trackId})>((ref, params) {
      final baseUrl = ref.watch(lyraApiBaseUrlProvider);
      return Uri.parse(
        '$baseUrl/playlists/${params.playlistId}/tracks/${params.trackId}',
      );
    });
