// services/recommendation_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'thumb_util.dart';

class RecommendedTrack {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final String duration;

  const RecommendedTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.duration,
  });

  Duration get durationValue {
    try {
      final parts = duration.split(':').map(int.parse).toList();
      if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
      if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } catch (_) {}
    return Duration.zero;
  }

  factory RecommendedTrack.fromJson(Map<String, dynamic> json) {
    final rawThumb = json['thumbnail'] ?? '';
    return RecommendedTrack(
      videoId: json['video_id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      // Always store a high-quality thumbnail for recommendations so
      // now playing + notification art look sharp.
      thumbnail: ThumbUtil.get(rawThumb, ThumbnailSize.tile),
      duration: json['duration'] ?? '',
    );
  }
}

class RecommendationService {
  static const _base       = 'https://saragama-render.onrender.com';
  static const _ttlMinutes = 60; // recommendations don't change within an hour

  // In-memory cache: videoId → (tracks, timestamp)
  // Recommendations are per-video so a simple map is sufficient — no LRU
  // needed since the number of unique played videos per session is small.
  static final _cache =
      <String, ({List<RecommendedTrack> tracks, DateTime ts})>{};

  static Future<List<RecommendedTrack>> getRecommendations(
      String videoId) async {
    if (videoId.isEmpty) return [];

    // 1. Return cached recommendations if still fresh
    final cached = _cache[videoId];
    if (cached != null) {
      final age = DateTime.now().difference(cached.ts).inMinutes;
      if (age < _ttlMinutes) return cached.tracks;
      _cache.remove(videoId); // stale, remove
    }

    // 2. Fetch from API
    try {
      final uri = Uri.parse('$_base/recommendation')
          .replace(queryParameters: {'video_id': videoId});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        final tracks = data
            .map((e) => RecommendedTrack.fromJson(Map<String, dynamic>.from(e)))
            .where((t) => t.videoId.isNotEmpty)
            .toList();
        _cache[videoId] = (tracks: tracks, ts: DateTime.now());
        return tracks;
      }
    } catch (_) {}
    return [];
  }

  static void clearCache() => _cache.clear();
}