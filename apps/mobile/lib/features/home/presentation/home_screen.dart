import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../library/library_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(dioProvider);
    final baseUrl = client.options.baseUrl;
    final syncing = ref.watch(libraryNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lyra')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Music intelligence, not playback.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'v0.0.2 sets up the contract and state layer so auth, sync, and playlist flows can plug into a stable app foundation.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'API base URL: $baseUrl',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: syncing
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(libraryNotifierProvider.notifier)
                                .startSync();
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sync started...')),
                            );
                          } catch (_) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to start sync.'),
                              ),
                            );
                          }
                        },
                  child: const Text('Sync Spotify Library'),
                ),
                if (syncing)
                  const Padding(
                    padding: EdgeInsets.only(top: 12.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
