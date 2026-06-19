// On-device artist-affinity model. Built from liked songs (strong, explicit),
// play history (behavioural, recency-weighted), and playlist tracks (noisier).
// Feeds the recommendation re-ranker and the personalized mixes. Pure Dart —
// no Hive/Get access here, so it is fully unit-testable; see TasteProfile.current()
// (added in Task 2) for the wiring that reads real on-device sources.

import 'library_service.dart';

/// Splits a (possibly multi-artist) field like "A, B & C" into trimmed names.
List<String> splitArtists(String field) => field
    .split(RegExp(r'[,&]|\bfeat\.?\b|\bx\b', caseSensitive: false))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

class ArtistSeed {
  final String artist;
  final String seedVideoId;
  final double score;
  const ArtistSeed(
      {required this.artist, required this.seedVideoId, required this.score});
}

class TasteProfile {
  /// Artist → affinity, normalized so the strongest artist is 1.0.
  final Map<String, double> artistAffinity;
  // Artist → a representative videoId by that artist (for radio seeding).
  final Map<String, String> _seedByArtist;

  const TasteProfile._(this.artistAffinity, this._seedByArtist);

  Set<String> get knownArtists => artistAffinity.keys.toSet();
  bool get isEmpty => artistAffinity.isEmpty;

  /// Affinity for a candidate's (possibly multi-artist) field: the max over
  /// its member artists, 0 if none are known.
  double scoreFor(String artistField) {
    double best = 0.0;
    for (final a in splitArtists(artistField)) {
      final s = artistAffinity[a] ?? 0.0;
      if (s > best) best = s;
    }
    return best;
  }

  /// Top-N artists by affinity, each with a seed videoId.
  List<ArtistSeed> topArtists(int n) {
    final entries = artistAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(n)
        .where((e) => (_seedByArtist[e.key] ?? '').isNotEmpty)
        .map((e) => ArtistSeed(
            artist: e.key, seedVideoId: _seedByArtist[e.key]!, score: e.value))
        .toList();
  }

  factory TasteProfile.build({
    required List<LibraryTrack> liked,
    required List<LibraryTrack> history, // most-recent first
    required List<LibraryTrack> playlistTracks,
  }) {
    final raw = <String, double>{};
    final seed = <String, String>{};

    void credit(LibraryTrack tr, double weight) {
      for (final a in splitArtists(tr.artist)) {
        raw[a] = (raw[a] ?? 0.0) + weight;
        // Prefer the first seed seen; liked is processed first so it wins.
        if (tr.videoId.isNotEmpty) seed.putIfAbsent(a, () => tr.videoId);
      }
    }

    for (final tr in liked) {
      credit(tr, 3.0);
    }
    for (var i = 0; i < history.length; i++) {
      // Recency decay: most-recent ~1.0 down to a 0.5 floor.
      final recency = (1.0 - i * 0.05).clamp(0.5, 1.0);
      credit(history[i], 2.0 * recency);
    }
    for (final tr in playlistTracks) {
      credit(tr, 1.0);
    }

    if (raw.isEmpty) return const TasteProfile._({}, {});

    final max = raw.values.reduce((a, b) => a > b ? a : b);
    final norm = {for (final e in raw.entries) e.key: e.value / max};
    return TasteProfile._(norm, seed);
  }
}
