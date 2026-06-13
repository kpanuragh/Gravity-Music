// ui/widgets/mini_player.dart
//
// Persistent floating glass mini-player (DESIGN.md → Mini-Player). Sits above
// the floating nav, tinted by the current artwork, with a 2px progress line
// at the very bottom of the glass. Tapping expands to NowPlayingScreen via a
// shared-element Hero on the artwork. Drives the existing PlayerController.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../services/thumb_util.dart';
import '../app_theme.dart';
import '../now_playing/now_playing_screen.dart';
import '../theme/dynamic_color_controller.dart';
import '../theme/glass.dart';
import '../ui_helpers.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final colors = Get.find<DynamicColorController>();

    return Obx(() {
      final song = pc.currentSong.value;
      if (song == null) return const SizedBox.shrink();

      final art = sizedThumb(song.artUri?.toString(), ThumbnailSize.micro);
      final bar = pc.progressBarState.value;
      final progress = bar.total.inMilliseconds > 0
          ? (bar.current.inMilliseconds / bar.total.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
        child: GestureDetector(
          onTap: () => _openNowPlaying(context),
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -100) _openNowPlaying(context);
          },
          child: GlassContainer(
            radius: AppRadius.lg,
            blur: 30,
            shadow: kGlassShadow,
            // Subtle artwork tint over the glass fill.
            fill: Color.alphaBlend(
                colors.accent.value.withOpacity(0.14), AppColors.glassFill),
            child: SizedBox(
              height: 62,
              child: Stack(
                // Center the row vertically; default Stack alignment is
                // top-start, which left the thumbnail hugging the top edge.
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Hero(
                        tag: kNowPlayingArtTag,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: art.isEmpty
                              ? Container(
                                  width: 46,
                                  height: 46,
                                  color: AppColors.card,
                                  child: const Icon(Icons.music_note_rounded,
                                      size: 20, color: AppColors.textTertiary))
                              : CachedNetworkImage(
                                  imageUrl: art,
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.title(size: 14)),
                            Text(song.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.subtitle(size: 12)),
                          ],
                        ),
                      ),
                      _MiniButton(
                        builder: () {
                          final state = pc.buttonState.value;
                          if (state == PlayButtonState.loading) {
                            return const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            );
                          }
                          return Icon(
                            state == PlayButtonState.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          );
                        },
                        onTap: () => pc.buttonState.value ==
                                PlayButtonState.playing
                            ? pc.pause()
                            : pc.play(),
                      ),
                      _MiniButton(
                        builder: () => const Icon(Icons.skip_next_rounded,
                            color: Colors.white, size: 26),
                        onTap: pc.next,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  // 2px progress line pinned to the bottom of the glass.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        height: 2,
                        color: colors.accent.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  void _openNowPlaying(BuildContext context) {
    AppHaptics.light();
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
      transitionsBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    ));
  }
}

/// Obx-wrapped tap target for the mini-player transport buttons.
class _MiniButton extends StatelessWidget {
  final Widget Function() builder;
  final VoidCallback onTap;
  const _MiniButton({required this.builder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Obx(() {
          // Touch buttonState so the icon rebuilds on play/pause.
          Get.find<PlayerController>().buttonState.value;
          return builder();
        }),
      ),
    );
  }
}
