import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/library_notifier.dart';
import '../../library/models/track.dart';
import '../../playlists/playlists_notifier.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(tracksNotifierProvider.notifier).searchTracks(value);
    });
  }

  Future<void> _showAddToPlaylistSheet(Track track) async {
    await ref.read(playlistsNotifierProvider.notifier).fetchPlaylists();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer(
            builder: (_, ref, _) {
              final playlistsState = ref.watch(playlistsNotifierProvider);

              return playlistsState.when(
                loading: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Failed to load playlists.'),
                      const SizedBox(height: 8),
                      Text('$error'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          ref
                              .read(playlistsNotifierProvider.notifier)
                              .fetchPlaylists();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text(
                          'No playlists available. Create one first.',
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        title: Text(playlist.name),
                        subtitle: playlist.description == null
                            ? null
                            : Text(playlist.description!),
                        onTap: () async {
                          try {
                            await ref
                                .read(playlistsNotifierProvider.notifier)
                                .addTrackToPlaylist(
                                  playlistId: playlist.id,
                                  trackId: track.id,
                                );
                            if (!mounted || !sheetContext.mounted) {
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added "${track.title}" to ${playlist.name}.',
                                ),
                              ),
                            );
                          } catch (_) {
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to add track to playlist.',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search by title or artist',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
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
                      trailing: const Icon(Icons.playlist_add),
                      onTap: () => _showAddToPlaylistSheet(track),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
