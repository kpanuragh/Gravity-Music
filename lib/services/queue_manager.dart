// services/queue_manager.dart
//
// Pure-Dart helper for queue navigation, shuffle bookkeeping, and queue
// loop mode. Has NO dependency on just_audio or the audio engine — only
// on MediaItem (a data class from audio_service). Designed so queue
// logic can be unit-tested without booting the audio handler.
//
// MyAudioHandler keeps ownership of the `queue` BehaviorSubject (mandated
// by audio_service) and the `_playList` ConcatenatingAudioSource (just_audio
// playback orchestration). QueueManager handles the in-memory shuffle
// permutation, queue-loop wraparound, and prev/next index computation.

import 'dart:math';

import 'package:audio_service/audio_service.dart';

class QueueManager {
  final Random _rng = Random();

  // ── Modes ────────────────────────────────────────────────────────────
  bool shuffleEnabled = false;
  bool queueLoopEnabled = false;

  // ── Shuffle bookkeeping ──────────────────────────────────────────────
  // _shuffledIds is the permutation of track IDs that defines play order
  // when shuffle is on. _shuffleIndex tracks where we are in it.
  // Both are private; callers go through onItemsAdded/etc. to mutate.
  List<String> _shuffledIds = [];
  int _shuffleIndex = 0;

  /// Read-only views for tests / persistence — do not mutate.
  List<String> get shuffledIds => List.unmodifiable(_shuffledIds);
  int get shuffleIndex => _shuffleIndex;

  // ── Navigation ───────────────────────────────────────────────────────

  /// Returns the index of the next song in [items], or null if the queue
  /// is exhausted (no next and queueLoop is off). Callers should treat
  /// null as "no next track available" — the previous handler convention
  /// of returning the current index for "exhausted" is now explicit.
  ///
  /// Side effect: when shuffle is on, advances `_shuffleIndex` (and
  /// reshuffles + wraps if at the end of the permutation).
  int? nextIndex(List<MediaItem> items, int currentIndex) {
    if (shuffleEnabled) {
      if (_shuffledIds.isEmpty) return null;
      if (_shuffleIndex + 1 >= _shuffledIds.length) {
        _shuffledIds.shuffle();
        _shuffleIndex = 0;
      } else {
        _shuffleIndex += 1;
      }
      final id = _shuffledIds[_shuffleIndex];
      final idx = items.indexWhere((i) => i.id == id);
      return idx == -1 ? null : idx;
    }
    if (items.length > currentIndex + 1) return currentIndex + 1;
    if (queueLoopEnabled && items.isNotEmpty) return 0;
    return null;
  }

  /// Read-only peek at the index `nextIndex()` WOULD return next, WITHOUT the
  /// side effect of advancing the shuffle cursor. Used for prefetching the
  /// upcoming track's URL. Returns null at the end of the shuffle permutation
  /// (the real advance would reshuffle, so there's nothing stable to prefetch).
  int? peekNextIndex(List<MediaItem> items, int currentIndex) {
    if (shuffleEnabled) {
      if (_shuffledIds.isEmpty || _shuffleIndex + 1 >= _shuffledIds.length) {
        return null;
      }
      final id = _shuffledIds[_shuffleIndex + 1];
      final idx = items.indexWhere((i) => i.id == id);
      return idx == -1 ? null : idx;
    }
    if (items.length > currentIndex + 1) return currentIndex + 1;
    if (queueLoopEnabled && items.isNotEmpty) return 0;
    return null;
  }

  /// Returns the index of the previous song, or null if at the start.
  ///
  /// Side effect (shuffle mode): decrements `_shuffleIndex`, wraps to
  /// end of permutation with a reshuffle if needed.
  int? prevIndex(List<MediaItem> items, int currentIndex) {
    if (shuffleEnabled) {
      if (_shuffledIds.isEmpty) return null;
      if (_shuffleIndex - 1 < 0) {
        _shuffledIds.shuffle();
        _shuffleIndex = _shuffledIds.length - 1;
      } else {
        _shuffleIndex -= 1;
      }
      final id = _shuffledIds[_shuffleIndex];
      final idx = items.indexWhere((i) => i.id == id);
      return idx == -1 ? null : idx;
    }
    if (currentIndex - 1 >= 0) return currentIndex - 1;
    return null;
  }

  // ── Shuffle mode toggle ──────────────────────────────────────────────

  /// Enable shuffle starting from the given index. Builds a permutation
  /// where the current track stays at position 0 and the rest are
  /// randomized — so the current song keeps playing, then the rest play
  /// in random order.
  void enableShuffle(List<MediaItem> items, int fromIndex) {
    if (items.isEmpty || fromIndex < 0 || fromIndex >= items.length) {
      shuffleEnabled = true;
      _shuffledIds = items.map((i) => i.id).toList();
      _shuffleIndex = 0;
      return;
    }
    final ids = items.map((i) => i.id).toList();
    final current = ids.removeAt(fromIndex);
    ids.shuffle();
    ids.insert(0, current);
    _shuffledIds = ids;
    _shuffleIndex = 0;
    shuffleEnabled = true;
  }

  void disableShuffle() {
    shuffleEnabled = false;
    _shuffledIds.clear();
    _shuffleIndex = 0;
  }

  // ── Reactions to canonical-queue mutations ───────────────────────────
  // The canonical queue (the BehaviorSubject inside MyAudioHandler) is the
  // source of truth for what's playable. These hooks let QueueManager keep
  // its shuffled permutation in sync when items are added, removed, or
  // inserted in the canonical queue.

  /// Items appended to the canonical queue (e.g. autoplay refill). Mix each
  /// new track into a RANDOM position within the not-yet-played remainder of
  /// the permutation, rather than appending in arrival order. Otherwise — in
  /// the common "play one song → autoplay grows the queue" flow — the whole
  /// play order would just be the arrival order and shuffle would have no
  /// audible effect.
  void onItemsAdded(List<MediaItem> newItems) {
    if (!shuffleEnabled) return;
    for (final item in newItems) {
      // Candidate slots are [_shuffleIndex + 1 .. length] (inclusive of the
      // end, so a track can also land last). Already-played slots (<= cursor)
      // are never disturbed.
      final lower = _shuffleIndex + 1;
      final pos = lower >= _shuffledIds.length
          ? _shuffledIds.length
          : lower + _rng.nextInt(_shuffledIds.length - lower + 1);
      _shuffledIds.insert(pos, item.id);
    }
  }

  /// An item was removed from the queue. Adjust the shuffled list and
  /// the shuffle cursor.
  void onItemRemoved(String id) {
    if (!shuffleEnabled) return;
    final idx = _shuffledIds.indexOf(id);
    if (idx == -1) return;
    if (_shuffleIndex > idx) _shuffleIndex -= 1;
    _shuffledIds.removeAt(idx);
  }

  /// An item was inserted right after the currently playing song
  /// ("Play next"). Mirror it in the shuffled permutation.
  void onItemInsertedAfterCurrent(String id) {
    if (!shuffleEnabled) return;
    _shuffledIds.insert(_shuffleIndex + 1, id);
  }

  /// All non-current items were removed (the "clear queue" action). Reset
  /// the shuffled list to just the current track.
  void onClearedExceptCurrent(String currentId) {
    if (!shuffleEnabled) return;
    _shuffledIds = [currentId];
    _shuffleIndex = 0;
  }

  /// Full reset — called when the queue is being replaced wholesale
  /// (playAllFrom, playShuffled). Disables shuffle as a side effect, since
  /// those code paths always start with ordered playback.
  void reset() {
    shuffleEnabled = false;
    _shuffledIds.clear();
    _shuffleIndex = 0;
  }
}
