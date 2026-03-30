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
      // Keep spinner visible briefly so the user receives immediate feedback.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      state = false;
    }
  }
}
