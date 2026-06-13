// ui/home/home_screen.dart
//
// Personalized home. Sections are backed by REAL signals only — there is no
// trending/home backend endpoint, so nothing is fabricated:
//   • greeting        → local time of day
//   • Recently Played → PlayerController.searchHistory (tracks you've played)
//   • Made For You    → RecommendationService seeded from your latest track
//   • Your Playlists  → LibraryService.getPlaylists()
//   • Liked Songs     → LibraryService.getLiked()
// Playback is delegated to PlayerController.playWithRecommendations / playAll.

import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../../controllers/player_controller.dart';
import '../../services/library_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/thumb_util.dart';
import '../app_theme.dart';
import '../library/library_screen.dart';
import '../theme/glass.dart';
import '../ui_helpers.dart';
import '../widgets/common_widgets.dart';

// ── Controller ───────────────────────────────────────────────────────────────

class HomeController extends GetxController {
  final madeForYou = <RecommendedTrack>[].obs;
  final loadingRecs = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadMadeForYou();
  }

  /// Seeds "Made For You" from the most recent track the user interacted with
  /// (search history first, then liked songs). No seed → nothing to recommend.
  Future<void> loadMadeForYou() async {
    final pc = Get.find<PlayerController>();
    final seed = pc.searchHistory.isNotEmpty
        ? pc.searchHistory.first.videoId
        : (LibraryService.getLiked().isNotEmpty
            ? LibraryService.getLiked().first.videoId
            : null);
    if (seed == null) return;
    loadingRecs.value = true;
    try {
      madeForYou.assignAll(
          await RecommendationService.getRecommendations(seed));
    } finally {
      loadingRecs.value = false;
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final home = Get.put(HomeController());
    final pc = Get.find<PlayerController>();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.card,
      onRefresh: home.loadMadeForYou,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header()),
          // ── Recently Played ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Obx(() {
              final recent = pc.searchHistory;
              if (recent.isEmpty) return const SizedBox.shrink();
              return _Carousel(
                title: 'Recently Played',
                children: recent.take(10).map((t) {
                  return ArtCard(
                    imageUrl: sizedThumb(t.thumbnail, ThumbnailSize.card),
                    title: t.title,
                    subtitle: t.artist,
                    onTap: () => pc.playWithRecommendations(
                      t.videoId,
                      title: t.title,
                      artist: t.artist,
                      thumbnail: t.thumbnail,
                      duration: t.durationValue,
                    ),
                  );
                }).toList(),
              );
            }),
          ),
          // ── Made For You ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Obx(() {
              if (home.loadingRecs.value && home.madeForYou.isEmpty) {
                return const _CarouselSkeleton(title: 'Made For You');
              }
              if (home.madeForYou.isEmpty) return const SizedBox.shrink();
              return _Carousel(
                title: 'Made For You',
                cardSize: 190,
                children: home.madeForYou.map((t) {
                  return ArtCard(
                    imageUrl: sizedThumb(t.thumbnail, ThumbnailSize.card),
                    title: t.title,
                    subtitle: t.artist,
                    overline: 'FOR YOU',
                    size: 190,
                    onTap: () => pc.playWithRecommendations(
                      t.videoId,
                      title: t.title,
                      artist: t.artist,
                      thumbnail: t.thumbnail,
                      duration: t.durationValue,
                    ),
                  );
                }).toList(),
              );
            }),
          ),
          // ── Your Playlists ───────────────────────────────────────────
          SliverToBoxAdapter(child: _PlaylistsRow()),
          // ── Empty fallback for a brand-new install ──────────────────
          SliverToBoxAdapter(child: Obx(() {
            final blank = pc.searchHistory.isEmpty &&
                home.madeForYou.isEmpty &&
                LibraryService.getPlaylists().isEmpty &&
                LibraryService.getLiked().isEmpty;
            if (!blank) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.graphic_eq_rounded,
                title: 'Welcome to Gravity',
                message:
                    'Search for a song to start listening — your home will\nfill up with picks made just for you.',
              ),
            );
          })),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.bottomDock)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          MediaQuery.of(context).padding.top + 16,
          AppSpacing.screenMargin,
          AppSpacing.stackMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greetingForNow(), style: AppText.subtitle(size: 15)),
                const SizedBox(height: 2),
                Text('Gravity', style: AppText.heading(size: 32)),
              ],
            ),
          ),
          GlassIconButton(
            icon: Icons.favorite_rounded,
            iconColor: AppColors.accent,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LikedSongsScreen())),
          ),
        ],
      ),
    );
  }
}

class _PlaylistsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final playlists = LibraryService.getPlaylists();
    if (playlists.isEmpty) return const SizedBox.shrink();
    return _Carousel(
      title: 'Your Playlists',
      children: playlists.map((pl) {
        return ArtCard(
          imageUrl: sizedThumb(pl.thumbnailUrl, ThumbnailSize.card),
          title: pl.name,
          subtitle: '${pl.tracks.length} songs',
          overline: 'PLAYLIST',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(playlistId: pl.id))),
        );
      }).toList(),
    );
  }
}

/// Horizontal scrolling section with a header.
class _Carousel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double cardSize;
  const _Carousel({
    required this.title,
    required this.children,
    this.cardSize = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        SizedBox(
          height: cardSize + 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin),
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.gutter),
            itemBuilder: (_, i) => children[i],
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),
      ],
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  final String title;
  const _CarouselSkeleton({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        SizedBox(
          height: 202,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.gutter),
            itemBuilder: (_, __) => Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),
      ],
    );
  }
}
