import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_provider.dart';

final spotifyLoginUriProvider = Provider<Uri>((ref) {
  final baseUrl = ref.watch(lyraApiBaseUrlProvider);
  return Uri.parse('$baseUrl/auth/spotify/login');
});
