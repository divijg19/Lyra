import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/library_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(libraryNotifierProvider);
    final tracksState = ref.watch(tracksNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lyra Library'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton(
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
              child: syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sync Library'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(tracksNotifierProvider.notifier).fetchTracks(),
        child: tracksState.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 240),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Failed to load tracks.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('$error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(tracksNotifierProvider.notifier).fetchTracks();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (tracks) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return ListTile(
                title: Text(track.title),
                subtitle: Text(track.artist),
              );
            },
          ),
        ),
      ),
    );
  }
}
