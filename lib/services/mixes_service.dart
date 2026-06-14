// services/mixes_service.dart
//
// Curated "mixes" (mood/activity playlists) from the saragama API's /mixes
// endpoint. Each mix arrives with its full track list inline, so opening a
// mix needs no second request. Powers the home "Made For You" section.
//
// Response shape:
//   { "updated_at": "...",
//     "mixes": {
//       "focus": { "title": "...", "image": "...", "trackCount": 20,
//                  "tracks": [ {video_id,title,artist,duration,thumbnail}, ... ] },
//       ...
//     } }

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cache_service.dart';
import 'thumb_util.dart';

class MixTrack {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final String duration;

  const MixTrack({
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
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return Duration.zero;
  }

  factory MixTrack.fromJson(Map<String, dynamic> json) => MixTrack(
        videoId: json['video_id'] ?? '',
        title: json['title'] ?? '',
        artist: json['artist'] ?? '',
        thumbnail: ThumbUtil.get(json['thumbnail'] ?? '', ThumbnailSize.tile),
        duration: json['duration'] ?? '',
      );
}

class Mix {
  final String id; // the map key, e.g. "focus"
  final String title;
  final String image; // saragama mood image URL (used as-is)
  final int trackCount;
  final List<MixTrack> tracks;

  const Mix({
    required this.id,
    required this.title,
    required this.image,
    required this.trackCount,
    required this.tracks,
  });

  factory Mix.fromEntry(String key, Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List? ?? [])
        .map((e) => MixTrack.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.videoId.isNotEmpty)
        .toList();
    return Mix(
      id: key,
      title: json['title'] ?? key,
      image: json['image'] ?? '',
      trackCount: json['trackCount'] ?? rawTracks.length,
      tracks: rawTracks,
    );
  }
}

class MixesService {
  static const _base = 'https://saragama-render.onrender.com';

  /// Returns the curated mixes.
  ///
  /// Caching strategy (persistent, survives app restarts via CacheService):
  ///   1. If a cached payload < 24h old exists, return it — no network call.
  ///   2. Otherwise fetch fresh, persist it, and return it.
  ///   3. If the fetch fails, fall back to the last cached payload (any age)
  ///      so the section still renders offline / when the server is asleep.
  ///
  /// Pass [forceRefresh] (e.g. pull-to-refresh) to skip step 1 and re-fetch,
  /// still falling back to cache on failure.
  static Future<List<Mix>> getMixes({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final fresh = CacheService.getFreshMixes();
      if (fresh != null) return _parse(fresh);
    }

    try {
      final uri = Uri.parse('$_base/mixes');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        CacheService.saveMixes(body);
        return _parse(body);
      }
    } catch (_) {}

    final any = CacheService.getAnyMixes();
    if (any != null) return _parse(any);
    return [];
  }

  /// Parses a raw /mixes payload into a list of Mix objects.
  static List<Mix> _parse(Map<String, dynamic> body) {
    final mixesMap = (body['mixes'] as Map?) ?? {};
    final mixes = <Mix>[];
    mixesMap.forEach((key, value) {
      if (value is Map) {
        final mix =
            Mix.fromEntry(key.toString(), Map<String, dynamic>.from(value));
        if (mix.tracks.isNotEmpty) mixes.add(mix);
      }
    });
    return mixes;
  }

  static void clearCache() => CacheService.clearMixes();
}
