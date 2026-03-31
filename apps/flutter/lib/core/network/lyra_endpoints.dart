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
