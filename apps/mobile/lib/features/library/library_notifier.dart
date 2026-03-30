import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/network/lyra_endpoints.dart';

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
      // briefly keep a small delay so UI can show spinner; callers may show snackbars
      state = false;
    }
  }
}
