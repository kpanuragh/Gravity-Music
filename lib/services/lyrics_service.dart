import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

enum LyricsLanguage { english, hindi, telugu, tamil, malayalam, other }

class SyncedLine {
  final Duration time;
  final String text;

  SyncedLine(this.time, this.text);
}

class LyricsObject {
  final LyricsLanguage language;
  final String plain;
  final List<SyncedLine>? synced;

  LyricsObject({
    required this.language,
    required this.plain,
    this.synced,
  });

  bool get hasSynced => synced != null && synced!.isNotEmpty;
}

class LyricsService {
  static const _baseUrl = 'https://lrclib.net/api/search';

  // Cache per "title|artist" key.
  static final Map<String, Map<LyricsLanguage, LyricsObject>> _cache = {};

  static String _key(String title, String artist) =>
      '${title.toLowerCase().trim()}|${artist.toLowerCase().trim()}';

  static Future<Map<LyricsLanguage, LyricsObject>> fetchLyrics(
      String title, String artist) async {
    if (title.trim().isEmpty || artist.trim().isEmpty) {
      return {};
    }

    final key = _key(title, artist);
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'track_name': title,
        'artist_name': artist,
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {};

      final List list = json.decode(res.body) as List;
      if (list.isEmpty) return {};

      final Map<LyricsLanguage, LyricsObject> perLanguage = {};

      for (final item in list) {
        final map = Map<String, dynamic>.from(item as Map);
        final plain = (map['plainLyrics'] as String? ?? '').trim();
        final syncedRaw = (map['syncedLyrics'] as String? ?? '').trim();
        if (plain.isEmpty && syncedRaw.isEmpty) continue;

        final combined = '$plain\n$syncedRaw';
        final lang = _detectLanguage(combined);
        final synced = syncedRaw.isNotEmpty ? _parseSynced(syncedRaw) : null;

        final candidate = LyricsObject(
          language: lang,
          plain: plain,
          synced: synced,
        );

        final existing = perLanguage[lang];
        if (existing == null) {
          perLanguage[lang] = candidate;
          continue;
        }

        final sim = _similarity(existing.plain, candidate.plain);
        if (sim >= 0.9) {
          // Dedup: prefer synced, else longer.
          final existingScore =
              (existing.hasSynced ? 2 : 0) + existing.plain.length;
          final candScore =
              (candidate.hasSynced ? 2 : 0) + candidate.plain.length;
          if (candScore > existingScore) {
            perLanguage[lang] = candidate;
          }
        } else {
          // Different enough; keep the better quality one.
          final existingScore =
              (existing.hasSynced ? 2 : 0) + existing.plain.length;
          final candScore =
              (candidate.hasSynced ? 2 : 0) + candidate.plain.length;
          if (candScore > existingScore) {
            perLanguage[lang] = candidate;
          }
        }
      }

      _cache[key] = perLanguage;
      return perLanguage;
    } catch (_) {
      return {};
    }
  }

  static LyricsLanguage _detectLanguage(String text) {
    int hindi = 0, telugu = 0, tamil = 0, malayalam = 0, english = 0;
    for (final codeUnit in text.runes) {
      if (codeUnit >= 0x0900 && codeUnit <= 0x097F) {
        hindi++;
      } else if (codeUnit >= 0x0C00 && codeUnit <= 0x0C7F) {
        telugu++;
      } else if (codeUnit >= 0x0B80 && codeUnit <= 0x0BFF) {
        tamil++;
      } else if (codeUnit >= 0x0D00 && codeUnit <= 0x0D7F) {
        malayalam++;
      } else if (_isAsciiLetter(codeUnit)) {
        english++;
      }
    }

    final counts = <LyricsLanguage, int>{
      LyricsLanguage.hindi: hindi,
      LyricsLanguage.telugu: telugu,
      LyricsLanguage.tamil: tamil,
      LyricsLanguage.malayalam: malayalam,
      LyricsLanguage.english: english,
    };

    final best = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    if (best.value == 0) return LyricsLanguage.other;
    return best.key;
  }

  static bool _isAsciiLetter(int code) =>
      (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);

  static List<SyncedLine> _parseSynced(String raw) {
    final lines = <SyncedLine>[];
    final regex = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]\s*(.*)');
    for (final line in raw.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match == null) continue;
      final mm = int.tryParse(match.group(1) ?? '') ?? 0;
      final ss = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = int.tryParse(match.group(3) ?? '') ?? 0;
      final ms = fraction * (fraction.toString().length == 2 ? 10 : 1);
      final text = (match.group(4) ?? '').trim();
      if (text.isEmpty) continue;
      lines.add(SyncedLine(Duration(minutes: mm, seconds: ss, milliseconds: ms), text));
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final maxLen = max(a.length, b.length).toDouble();
    final minLen = min(a.length, b.length);
    int same = 0;
    for (var i = 0; i < minLen; i++) {
      if (a.codeUnitAt(i) == b.codeUnitAt(i)) same++;
    }
    return same / maxLen;
  }
}

