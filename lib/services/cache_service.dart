// services/cache_service.dart
//
// Central persistent cache backed by Hive 'CacheBox'.
// Stores JSON strings with a timestamp so we can check staleness.
//
// Keys used:
//   'home'              → HomeData JSON + timestamp
//   'playlist:{id}'     → PlaylistDetail JSON + timestamp
//
// TTLs:
//   Home data           → 2 hours  (120 min)
//   Playlist detail     → 24 hours (1440 min)

import 'dart:convert';
import 'package:hive/hive.dart';

class CacheService {
  static const _boxName         = 'CacheBox';
  static const _homeKey         = 'home';
  static const _homeTtlMinutes  = 120;   // 2 hours
  static const _plTtlMinutes    = 1440;  // 24 hours

  static Box get _box => Hive.box(_boxName);

  // ── Internal helpers ────────────────────────────────────────────────────────

  static void _write(String key, Map<String, dynamic> data) {
    _box.put(key, jsonEncode({
      'data': data,
      'ts': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  /// Returns the decoded data map if the entry exists and is within [ttlMinutes].
  /// Returns null if missing or stale.
  static Map<String, dynamic>? _read(String key, int ttlMinutes) {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final ts      = wrapper['ts'] as int? ?? 0;
      final age     = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > ttlMinutes * 60 * 1000) return null; // stale
      return wrapper['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns data regardless of age (used for stale-while-revalidate pattern).
  static Map<String, dynamic>? _readAny(String key) {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      return wrapper['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns true if a cached entry for [key] exists but is older than [ttlMinutes].
  static bool isStale(String key, int ttlMinutes) {
    final raw = _box.get(key) as String?;
    if (raw == null) return true;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final ts  = wrapper['ts'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age > ttlMinutes * 60 * 1000;
    } catch (_) {
      return true;
    }
  }

  // ── Home data ───────────────────────────────────────────────────────────────

  /// Returns fresh (within 2hr) cached home data, or null if missing/stale.
  static Map<String, dynamic>? getFreshHome() =>
      _read(_homeKey, _homeTtlMinutes);

  /// Returns cached home data regardless of age (stale-while-revalidate).
  static Map<String, dynamic>? getAnyHome() => _readAny(_homeKey);

  /// Returns true if the home cache is older than 2 hours.
  static bool isHomeStale() => isStale(_homeKey, _homeTtlMinutes);

  /// Saves home data to persistent cache.
  static void saveHome(Map<String, dynamic> json) => _write(_homeKey, json);

  // ── Playlist detail ─────────────────────────────────────────────────────────

  static String _plKey(String id) => 'playlist:$id';

  /// Returns fresh (within 24hr) cached playlist, or null if missing/stale.
  static Map<String, dynamic>? getFreshPlaylist(String id) =>
      _read(_plKey(id), _plTtlMinutes);

  /// Returns cached playlist regardless of age.
  static Map<String, dynamic>? getAnyPlaylist(String id) =>
      _readAny(_plKey(id));

  /// Returns true if the playlist cache is older than 24 hours.
  static bool isPlaylistStale(String id) =>
      isStale(_plKey(id), _plTtlMinutes);

  /// Saves playlist detail to persistent cache.
  static void savePlaylist(String id, Map<String, dynamic> json) =>
      _write(_plKey(id), json);

  // ── Utility ─────────────────────────────────────────────────────────────────

  /// Clears all cache entries.
  static void clearAll() => _box.clear();

  /// Clears only the home cache (forces next open to re-fetch).
  static void clearHome() => _box.delete(_homeKey);

  /// Clears a specific playlist cache.
  static void clearPlaylist(String id) => _box.delete(_plKey(id));
}