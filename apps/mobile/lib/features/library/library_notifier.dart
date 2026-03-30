import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/network/lyra_endpoints.dart';
import 'models/track.dart';

final libraryNotifierProvider = StateNotifierProvider<LibraryNotifier, bool>((
  ref,
) {
  return LibraryNotifier(ref);
});

class LibraryNotifier extends StateNotifier<bool> {
  LibraryNotifier(this.ref) : super(false);

  final Ref ref;

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
  @override
  Future<List<Track>> build() async {
    return fetchTracks(limit: 100);
  }

  Future<List<Track>> fetchTracks({int skip = 0, int limit = 100}) async {
    state = const AsyncLoading();

    final dio = ref.read(dioProvider);
    final uri = ref.read(libraryTracksUriProvider((skip: skip, limit: limit)));

    final response = await dio.getUri(uri);
    final rawList = response.data as List<dynamic>;
    final tracks = rawList
        .map((item) => Track.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    state = AsyncData(tracks);
    return tracks;
  }
}
