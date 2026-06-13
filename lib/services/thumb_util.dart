// services/thumb_util.dart
// Global thumbnail URL quality manager.
// YouTube CDN URLs end with size params like =w60-h60-l90-rj
// We swap them based on exactly where the thumbnail is displayed.
//
// Size tiers (matched to actual render sizes):
//   micro  —  48px  → notification, mini-player bar          (~4 KB)
//   tile   —  96px  → queue tiles, search tiles, track lists (~10 KB)
//   card   — 226px  → home grid cards, playlist headers      (~30 KB)
//   art    — 544px  → now-playing artwork only               (~65 KB)
//
// Rule: request the smallest size that still looks sharp at render size.
// On a 3× screen a 46px widget = 138 physical px → 96px server thumb
// is fine (slight upscale), 226px is safe, 544px is wasteful by 15×.

enum ThumbnailSize {
  micro,   //  48px — notification, mini-player bar
  tile,    //  96px — list tiles (queue, search, track lists, history)
  card,    // 226px — grid cards (home, playlist headers)
  art,     // 544px — now-playing full artwork ONLY
}

class ThumbUtil {
  static String get(String url, ThumbnailSize size) {
    if (url.isEmpty) return url;
    final params = _params(size);
    final upgraded = url
        .replaceAll(RegExp(r'=w\d+-h\d+[^&\s]*$'), '=$params')
        .replaceAll(RegExp(r'=s\d+[^&\s]*$'), '=$params');
    if (upgraded == url && !url.contains('=$params')) {
      return '$url=$params';
    }
    return upgraded;
  }

  // Convenience: upgrade a URL that was already sized for a different context.
  // Use this when you have a stored tile URL but need to display it as art.
  static String upgrade(String url, ThumbnailSize to) => get(url, to);

  static String _params(ThumbnailSize size) {
    switch (size) {
      case ThumbnailSize.micro:
        return 'w48-h48-l90-rj';
      case ThumbnailSize.tile:
        return 'w96-h96-l90-rj';
      case ThumbnailSize.card:
        return 'w226-h226-l90-rj';
      case ThumbnailSize.art:
        return 'w544-h544-l90-rj';
    }
  }
}