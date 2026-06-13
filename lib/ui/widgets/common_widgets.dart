// ui/widgets/common_widgets.dart
// Reusable, theme-driven building blocks shared across screens:
// section headers, artwork cards, track rows, and empty states.
// All styling pulls from AppColors / AppText / AppRadius — no magic values.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

/// "PLAYLIST" / "RECENTLY PLAYED" style section heading with optional action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.stackSm + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: AppText.heading(size: 20))),
          if (actionLabel != null)
            GestureDetector(
              onTap: () {
                AppHaptics.selection();
                onAction?.call();
              },
              child: Text(actionLabel!,
                  style: AppText.caption(color: AppColors.textSecondaryHi)),
            ),
        ],
      ),
    );
  }
}

/// Rounded artwork with a subtle inner glow so it never disappears into the
/// black canvas (DESIGN.md → Cards). Falls back to a music-note placeholder.
class ArtImage extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final BoxFit fit;

  const ArtImage({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = AppRadius.md,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: br,
        color: AppColors.card,
        boxShadow: const [
          BoxShadow(color: Color(0x33FFFFFF), blurRadius: 18, spreadRadius: -8),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.music_note_rounded,
              color: AppColors.textTertiary, size: size * 0.38)
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: fit,
              placeholder: (_, __) => Container(color: AppColors.card),
              errorWidget: (_, __, ___) => Icon(Icons.music_note_rounded,
                  color: AppColors.textTertiary, size: size * 0.38),
            ),
    );
  }
}

/// Square card with title + subtitle below — used in horizontal carousels.
class ArtCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final double size;
  final String? overline; // e.g. "PLAYLIST"
  final VoidCallback onTap;

  const ArtCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.overline,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ArtImage(url: imageUrl, size: size, radius: AppRadius.lg),
                if (overline != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Text(overline!,
                        style: AppText.label(color: Colors.white70)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title(size: 14)),
            if (subtitle != null)
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle(size: 12)),
          ],
        ),
      ),
    );
  }
}

/// Standard track row used in lists, queue, search results.
class TrackTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? trailingText;
  final Widget? trailing;
  final bool active;
  final VoidCallback onTap;

  const TrackTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
    this.trailing,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin, vertical: 8),
          child: Row(
            children: [
              ArtImage(url: imageUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(
                            size: 15,
                            color: active
                                ? AppColors.white
                                : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subtitle(size: 13)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (trailing == null && trailingText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(trailingText!, style: AppText.caption()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered, elegant empty state for screens with no content yet.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.stackLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.gutter),
            Text(title, style: AppText.heading(size: 18)),
            const SizedBox(height: AppSpacing.stackSm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.subtitle(size: 14)),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.stackMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
