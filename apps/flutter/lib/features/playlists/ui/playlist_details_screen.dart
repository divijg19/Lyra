import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/track.dart';
import '../playlists_notifier.dart';

class PlaylistDetailsScreen extends ConsumerWidget {
  const PlaylistDetailsScreen({
    super.key,
    required this.playlistId,
    this.playlistName,
  });

  final String playlistId;
  final String? playlistName;

  Future<bool?> _confirmRemoveTrack(BuildContext context, Track track) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Track?'),
          content: Text('Remove "${track.title}" from this playlist?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksState = ref.watch(playlistTracksProvider(playlistId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          playlistName == null || playlistName!.isEmpty
              ? 'Playlist'
              : playlistName!,
        ),
      ),
      body: tracksState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed to load playlist tracks.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('$error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(playlistTracksProvider(playlistId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('No tracks in this playlist yet.'));
          }

          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];

              return Dismissible(
                key: ValueKey('playlist-$playlistId-track-${track.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => _confirmRemoveTrack(context, track),
                onDismissed: (_) async {
                  try {
                    await ref
                        .read(playlistsNotifierProvider.notifier)
                        .removeTrackFromPlaylist(playlistId, track.id);
                    ref.invalidate(playlistTracksProvider(playlistId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Removed "${track.title}" from playlist.',
                          ),
                        ),
                      );
                    }
                  } catch (_) {
                    ref.invalidate(playlistTracksProvider(playlistId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to remove track.'),
                        ),
                      );
                    }
                  }
                },
                child: ListTile(
                  title: Text(track.title),
                  subtitle: Text(track.artist),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
