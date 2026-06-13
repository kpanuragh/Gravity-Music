// services/search_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'thumb_util.dart';

class SearchResult {
  final String title;
  final String videoId;
  final List<String> artists;
  final String thumbnail;
  final String duration;

  const SearchResult({
    required this.title,
    required this.videoId,
    required this.artists,
    required this.thumbnail,
    required this.duration,
  });

  String get artistLine => artists.join(', ');

  Duration get durationValue {
    try {
      final parts = duration.split(':').map(int.parse).toList();
      if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
      if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } catch (_) {}
    return Duration.zero;
  }

  /// Sizes thumbnail for list-tile display (96px — 6× smaller than 544px).
  static String _upgradeThumb(String url) =>
      ThumbUtil.get(url, ThumbnailSize.tile);

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] ?? '',
        videoId: json['video_url'] ?? '',
        artists: List<String>.from(json['artist'] ?? []),
        thumbnail: _upgradeThumb(json['thumbnail'] ?? ''),
        duration: json['duration'] ?? '',
      );
}

class SearchService {
  static const _base        = 'https://saragama-render.onrender.com';
  static const _maxCacheSize = 30;         // max distinct queries kept
  static const _ttlMinutes   = 15;         // cache entries expire after 15 min

  // LRU cache: query → (results, timestamp)
  // Using a LinkedHashMap to maintain insertion order for LRU eviction.
  static final _cache =
      <String, ({List<SearchResult> results, DateTime ts})>{};

  static Future<List<SearchResult>> autocomplete(String query) async {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) return [];

    // 1. Cache hit — return instantly if still fresh
    final cached = _cache[key];
    if (cached != null) {
      final age = DateTime.now().difference(cached.ts).inMinutes;
      if (age < _ttlMinutes) {
        // Move to end (most recently used)
        _cache.remove(key);
        _cache[key] = cached;
        return cached.results;
      } else {
        _cache.remove(key); // expired
      }
    }

    // 2. Cache miss — fetch from API
    try {
      final uri = Uri.parse('$_base/autocomplete')
          .replace(queryParameters: {'q': query.trim()});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        final results = data
            .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // 3. Store in cache, evict oldest if over limit
        if (_cache.length >= _maxCacheSize) {
          _cache.remove(_cache.keys.first); // remove LRU (first = oldest)
        }
        _cache[key] = (results: results, ts: DateTime.now());
        return results;
      }
    } catch (_) {}
    return [];
  }

  /// Clear all cached search results (e.g. on low memory).
  static void clearCache() => _cache.clear();
}