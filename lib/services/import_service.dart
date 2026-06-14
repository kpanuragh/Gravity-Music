// services/import_service.dart
//
// Imports external (Spotify / Apple Music) playlists via the saragama API and
// converts them into Gravity Music songs. Two stages:
//   • details — validate the URL + preview song names and an import-time estimate
//   • import  — resolve every song into full Gravity Music metadata
//
// NOTE: both endpoints take `url` as a QUERY parameter on a POST request
// (verified against the live API), not a JSON body.
//
// The /import response items share SearchResult's exact JSON shape
// (title / video_url / artist[] / thumbnail / duration), so we reuse
// SearchResult here rather than introduce a parallel model.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'search_service.dart';

/// Friendly, user-facing failure during import (shown verbatim in the UI).
class ImportException implements Exception {
  final String message;
  const ImportException(this.message);
  @override
  String toString() => message;
}

/// Preview info returned by /import-playlist/details.
class PlaylistImportDetails {
  final int songCount;
  final int estimatedSeconds;
  final double estimatedMinutes;
  final List<String> songs;

  /// Optional playlist name if the backend ever supplies one (it currently
  /// doesn't) — used to pre-fill the "Playlist Name" dialog.
  final String? name;

  const PlaylistImportDetails({
    required this.songCount,
    required this.estimatedSeconds,
    required this.estimatedMinutes,
    required this.songs,
    this.name,
  });

  factory PlaylistImportDetails.fromJson(Map<String, dynamic> json) =>
      PlaylistImportDetails(
        songCount: json['song_count'] ?? 0,
        estimatedSeconds: json['estimated_import_time_seconds'] ?? 0,
        estimatedMinutes:
            (json['estimated_import_time_minutes'] as num?)?.toDouble() ?? 0,
        songs: List<String>.from(json['songs'] ?? const []),
        name: json['name'] ?? json['title'] ?? json['playlist_name'],
      );
}

class ImportService {
  static const _base = 'https://saragama-render.onrender.com';

  /// Stage 1: validate + preview. Fast (song names only).
  static Future<PlaylistImportDetails> fetchDetails(String url) async {
    final uri = Uri.parse('$_base/import-playlist/details')
        .replace(queryParameters: {'url': url});
    try {
      final res = await http.post(uri).timeout(const Duration(seconds: 90));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        return PlaylistImportDetails.fromJson(body);
      }
      throw ImportException(_messageForStatus(res.statusCode));
    } on ImportException {
      rethrow;
    } catch (_) {
      throw const ImportException(
          'Couldn’t reach the import service. Check your connection and try again.');
    }
  }

  /// Stage 2: full resolution. Can take a while (≈ one second per song), so the
  /// timeout scales with the previewed song count.
  static Future<List<SearchResult>> importPlaylist(String url,
      {int estimatedSeconds = 60}) async {
    final uri = Uri.parse('$_base/import-playlist/import')
        .replace(queryParameters: {'url': url});
    final timeout = Duration(seconds: (estimatedSeconds * 3).clamp(120, 600));
    try {
      final res = await http.post(uri).timeout(timeout);
      if (res.statusCode == 200) {
        final List data = json.decode(res.body) as List;
        return data
            .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.videoId.isNotEmpty)
            .toList();
      }
      throw ImportException(_messageForStatus(res.statusCode));
    } on ImportException {
      rethrow;
    } catch (_) {
      throw const ImportException(
          'Import failed. The playlist may be private or the service is busy — try again.');
    }
  }

  static String _messageForStatus(int code) {
    if (code == 404 || code == 400 || code == 422) {
      return 'That doesn’t look like a valid Spotify or Apple Music playlist link.';
    }
    return 'The import service returned an error ($code). Please try again later.';
  }
}
