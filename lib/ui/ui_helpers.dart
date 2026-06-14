// ui/ui_helpers.dart
// Small UI-layer glue: maps between the existing data models and the
// audio_service MediaItem used by the player, plus a few formatters.
// No business logic lives here — it only adapts existing models for the UI.

import 'package:audio_service/audio_service.dart';

import '../services/library_service.dart';
import '../services/mixes_service.dart';
import '../services/recommendation_service.dart';
import '../services/search_service.dart';
import '../services/thumb_util.dart';

/// Builds the `extras: {'url': ''}` MediaItem shape the audio handler expects
/// (URL is resolved lazily by `checkNGetUrl` at play time).
MediaItem _mediaItem({
  required String id,
  required String title,
  String? artist,
  String? thumbnail,
  Duration? duration,
}) =>
    MediaItem(
      id: id,
      title: title,
      artist: artist,
      // High-res so the media notification / lockscreen art stays sharp;
      // small surfaces downsize this URL again via ThumbUtil.
      artUri: (thumbnail != null && thumbnail.isNotEmpty)
          ? Uri.tryParse(ThumbUtil.get(thumbnail, ThumbnailSize.art))
          : null,
      duration: duration,
      // NOT const: the audio handler writes the resolved stream URL back into
      // this map (extras['url'] = …) at play time. A const map is unmodifiable
      // and would throw, leaving the track stuck loading forever.
      extras: {'url': ''},
    );

extension LibraryTrackMedia on LibraryTrack {
  MediaItem toMediaItem() => _mediaItem(
        id: videoId,
        title: title,
        artist: artist,
        thumbnail: thumbnail,
        duration: durationValue == Duration.zero ? null : durationValue,
      );
}

extension SearchResultMedia on SearchResult {
  MediaItem toMediaItem() => _mediaItem(
        id: videoId,
        title: title,
        artist: artistLine,
        thumbnail: thumbnail,
        duration: durationValue == Duration.zero ? null : durationValue,
      );

  LibraryTrack toLibraryTrack() => LibraryTrack(
        videoId: videoId,
        title: title,
        artist: artistLine,
        thumbnail: thumbnail,
        duration: duration,
      );
}

extension RecommendedTrackMedia on RecommendedTrack {
  MediaItem toMediaItem() => _mediaItem(
        id: videoId,
        title: title,
        artist: artist,
        thumbnail: thumbnail,
        duration: durationValue == Duration.zero ? null : durationValue,
      );
}

extension MixTrackMedia on MixTrack {
  MediaItem toMediaItem() => _mediaItem(
        id: videoId,
        title: title,
        artist: artist,
        thumbnail: thumbnail,
        duration: durationValue == Duration.zero ? null : durationValue,
      );
}

/// Upgrades any stored thumbnail URL to the requested render size.
String sizedThumb(String? url, ThumbnailSize size) =>
    (url == null || url.isEmpty) ? '' : ThumbUtil.get(url, size);

/// mm:ss / h:mm:ss formatter for durations and positions.
String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${mm.padLeft(2, '0')}:$ss' : '$mm:$ss';
}

/// Some YouTube uploads are titled in ALL CAPS. The app never transforms text,
/// so those render "shouty" next to normally-cased titles. This converts a
/// fully-uppercase (Latin) string to Title Case for display only — mixed-case
/// titles and non-Latin scripts (e.g. Malayalam, which has no letter case) are
/// returned unchanged, so we never mangle text that's already fine.
String prettyTitle(String raw) {
  if (raw.isEmpty) return raw;
  final hasUpper = RegExp(r'[A-Z]').hasMatch(raw);
  final hasLower = RegExp(r'[a-z]').hasMatch(raw);
  // Only act on strings that have uppercase Latin letters AND no lowercase
  // ones — i.e. genuinely shouty. Anything else is left exactly as-is.
  if (!hasUpper || hasLower) return raw;
  return raw
      .split(' ')
      .map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Time-of-day greeting for the home header.
String greetingForNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Good Morning';
  if (h < 17) return 'Good Afternoon';
  return 'Good Evening';
}
