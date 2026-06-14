// ui/library/library_screen.dart
//
// Library tab + Liked Songs and Playlist detail screens. All data comes from
// the existing LibraryService (Hive-backed liked songs + local playlists) and
// playback is delegated to PlayerController.playAllMedia. No mock data.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../services/library_service.dart';
import '../../services/thumb_util.dart';
import '../app_theme.dart';
import '../theme/glass.dart';
import '../ui_helpers.dart';
import '../widgets/common_widgets.dart';
import '../widgets/mini_player.dart';
import 'import_playlist.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the library box changes (e.g. a playlist created from
    // the Now Playing sheet) — this tab stays mounted, so without this it
    // would show stale data until manually refreshed.
    return ValueListenableBuilder(
      valueListenable: Hive.box('LibraryBox').listenable(),
      builder: (context, _, __) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final liked = LibraryService.getLiked();
    final playlists = LibraryService.getPlaylists();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                MediaQuery.of(context).padding.top + 16,
                AppSpacing.screenMargin,
                AppSpacing.stackMd),
            child: Row(
              children: [
                Expanded(child: Text('Library', style: AppText.heading(size: 32))),
                GlassIconButton(
                  icon: Icons.add_rounded,
                  onTap: () => _createPlaylist(context),
                ),
              ],
            ),
          ),
        ),
        // ── Quick-access rows ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _LibraryRow(
            icon: Icons.favorite_rounded,
            iconColor: AppColors.accent,
            title: 'Liked Songs',
            subtitle: '${liked.length} songs',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LikedSongsScreen())),
          ),
        ),
        SliverToBoxAdapter(
          child: _LibraryRow(
            icon: Icons.download_done_rounded,
            iconColor: Colors.greenAccent,
            title: 'Downloads',
            subtitle: 'Saved for offline',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen())),
          ),
        ),
        // ── Playlists grid ──────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
              AppSpacing.stackMd, AppSpacing.screenMargin, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Playlists',
              actionLabel: 'Import',
              onAction: () => showImportPlaylistSheet(context),
            ),
          ),
        ),
        if (playlists.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.queue_music_rounded,
                title: 'No playlists yet',
                message: 'Tap + to create your first playlist.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.gutter,
                mainAxisSpacing: AppSpacing.gutter,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final pl = playlists[i];
                  return ArtCard(
                    imageUrl: sizedThumb(pl.thumbnailUrl, ThumbnailSize.card),
                    title: pl.name,
                    subtitle: '${pl.tracks.length} songs',
                    size: double.infinity,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailScreen(playlistId: pl.id)));
                      _refresh();
                    },
                  );
                },
                childCount: playlists.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.bottomDock)),
      ],
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('New playlist', style: AppText.title(size: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppText.title(size: 15),
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      LibraryService.createPlaylist(name);
      _refresh();
    }
  }
}

class _LibraryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LibraryRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin, vertical: 6),
      child: GestureDetector(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        child: GlassContainer(
          radius: AppRadius.lg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title(size: 16)),
                    Text(subtitle, style: AppText.subtitle(size: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Liked Songs ────────────────────────────────────────────────────────────

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final liked = LibraryService.getLiked();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ScreenWithMiniPlayer(
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.canvas,
            pinned: true,
            leading: const AppBackButton(),
            title: Text('Liked Songs', style: AppText.title(size: 18)),
            actions: [
              if (liked.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 30),
                  onPressed: () => pc.playAllMedia(
                      liked.map((t) => t.toMediaItem()).toList()),
                ),
            ],
          ),
          if (liked.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'No liked songs',
                message: 'Tap the heart on any track to save it here.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final t = liked[i];
                  return TrackTile(
                    imageUrl: sizedThumb(t.thumbnail, ThumbnailSize.tile),
                    title: t.title,
                    subtitle: t.artist,
                    onTap: () => pc.playAllMedia(
                        liked.map((x) => x.toMediaItem()).toList(),
                        startIndex: i),
                  );
                },
                childCount: liked.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
        ),
      ),
    );
  }
}

// ── Playlist detail ──────────────────────────────────────────────────────────

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  LocalPlaylist? get _playlist {
    final all = LibraryService.getPlaylists();
    final i = all.indexWhere((p) => p.id == widget.playlistId);
    return i == -1 ? null : all[i];
  }

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final pl = _playlist;

    if (pl == null) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: Text('Playlist not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ScreenWithMiniPlayer(
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.canvas,
            pinned: true,
            expandedHeight: 280,
            leading: const AppBackButton(),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white),
                onPressed: () {
                  LibraryService.deletePlaylist(pl.id);
                  Navigator.pop(context);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin, 80, AppSpacing.screenMargin, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ArtImage(
                        url: sizedThumb(pl.thumbnailUrl, ThumbnailSize.card),
                        size: 150,
                        radius: AppRadius.lg),
                    const SizedBox(height: 12),
                    Text(pl.name,
                        style: AppText.heading(size: 24),
                        textAlign: TextAlign.center),
                    Text('${pl.tracks.length} songs',
                        style: AppText.subtitle(size: 13)),
                  ],
                ),
              ),
            ),
          ),
          if (pl.tracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.playlist_add_rounded,
                title: 'Empty playlist',
                message: 'Add songs from the player’s “…” menu.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, 8,
                    AppSpacing.screenMargin, AppSpacing.gutter),
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Play',
                        icon: Icons.play_arrow_rounded,
                        onTap: () => pc.playAllMedia(
                            pl.tracks.map((t) => t.toMediaItem()).toList()),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gutter),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Shuffle',
                        icon: Icons.shuffle_rounded,
                        onTap: () => pc.playShuffledMedia(
                            pl.tracks.map((t) => t.toMediaItem()).toList()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final t = pl.tracks[i];
                  return TrackTile(
                    imageUrl: sizedThumb(t.thumbnail, ThumbnailSize.tile),
                    title: t.title,
                    subtitle: t.artist,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: AppColors.textTertiary),
                      onPressed: () {
                        LibraryService.removeTrackFromPlaylist(
                            pl.id, t.videoId);
                        setState(() {});
                      },
                    ),
                    onTap: () => pc.playAllMedia(
                        pl.tracks.map((x) => x.toMediaItem()).toList(),
                        startIndex: i),
                  );
                },
                childCount: pl.tracks.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.bottomDock)),
        ],
        ),
      ),
    );
  }
}

// ── Downloads ────────────────────────────────────────────────────────────────

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final dc = Get.find<DownloadController>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ScreenWithMiniPlayer(
        child: Obx(() {
          final downloads = dc.downloads;
          final downloading = dc.downloading;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.canvas,
                pinned: true,
                leading: const AppBackButton(),
                title: Text('Downloads', style: AppText.title(size: 18)),
                actions: [
                  if (downloads.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 30),
                      onPressed: () => pc.playAllMedia(
                          downloads.map((t) => t.toMediaItem()).toList()),
                    ),
                ],
              ),

              // ── Play / Shuffle ──────────────────────────────────────────
              if (downloads.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                        8, AppSpacing.screenMargin, AppSpacing.gutter),
                    child: Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Play',
                            icon: Icons.play_arrow_rounded,
                            onTap: () => pc.playAllMedia(downloads
                                .map((t) => t.toMediaItem())
                                .toList()),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.gutter),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Shuffle',
                            icon: Icons.shuffle_rounded,
                            onTap: () => pc.playShuffledMedia(downloads
                                .map((t) => t.toMediaItem())
                                .toList()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── In-progress downloads ───────────────────────────────────
              if (downloading.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final t = downloading[i];
                      return Obx(() {
                        final p = dc.progress[t.videoId] ?? 0.0;
                        return TrackTile(
                          imageUrl: sizedThumb(t.thumbnail, ThumbnailSize.tile),
                          title: t.title,
                          subtitle:
                              'Downloading… ${(p * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          trailing: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: p == 0 ? null : p,
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          onTap: () {},
                        );
                      });
                    },
                    childCount: downloading.length,
                  ),
                ),

              // ── Completed downloads / empty state ───────────────────────
              if (downloads.isEmpty && downloading.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.download_rounded,
                    title: 'No downloads yet',
                    message:
                        'Tap the “…” menu on a song and choose Download to\nsave it for offline listening.',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final t = downloads[i];
                      return TrackTile(
                        imageUrl: sizedThumb(t.thumbnail, ThumbnailSize.tile),
                        title: t.title,
                        subtitle: t.artist,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.textTertiary),
                          onPressed: () => dc.delete(t.videoId),
                        ),
                        onTap: () => pc.playAllMedia(
                            downloads.map((x) => x.toMediaItem()).toList(),
                            startIndex: i),
                      );
                    },
                    childCount: downloads.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        }),
      ),
    );
  }
}
