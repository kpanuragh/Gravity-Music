// controllers/playlist_download_controller.dart
//
// Reactive layer over PlaylistDownloadService. Drives the background download
// of a whole playlist and exposes:
//   • progress      — playlistId → 0..1 while actively downloading (per-song
//                      granularity: completed tracks / total).
//   • downloadedIds — playlists that are fully available offline.
//
// Downloads run in the background; the user can keep listening/navigating. The
// Library tile badge and the playlist-detail action both observe this.

import 'package:get/get.dart';

import '../services/library_service.dart';
import '../services/playlist_download_service.dart';
import '../ui/app_theme.dart';

class PlaylistDownloadController extends GetxController {
  /// playlistId → 0..1 while a playlist download is in flight.
  final progress = <String, double>{}.obs;

  /// Playlists that are fully downloaded for offline play.
  final downloadedIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _refreshDownloadedSet();
  }

  void _refreshDownloadedSet() {
    downloadedIds.assignAll(
      PlaylistDownloadService.registeredIds()
          .where(PlaylistDownloadService.isFullyDownloaded),
    );
  }

  bool isDownloading(String playlistId) => progress.containsKey(playlistId);
  bool isDownloaded(String playlistId) => downloadedIds.contains(playlistId);
  double progressFor(String playlistId) => progress[playlistId] ?? 0.0;

  /// Start (or resume) a background download of [pl]. Returns immediately if a
  /// download for this playlist is already running.
  Future<void> download(LocalPlaylist pl) async {
    final id = pl.id;
    if (isDownloading(id)) return;
    final total = pl.tracks.length;
    if (total == 0) return;

    PlaylistDownloadService.registerPlaylist(
        id, pl.name, pl.tracks.map((t) => t.videoId).toList());
    downloadedIds.remove(id);

    int doneCount() =>
        pl.tracks.where((t) => PlaylistDownloadService.isResolvable(t.videoId)).length;

    progress[id] = doneCount() / total;
    try {
      for (final t in pl.tracks) {
        if (!PlaylistDownloadService.isResolvable(t.videoId)) {
          try {
            await PlaylistDownloadService.downloadTrack(t);
          } catch (_) {
            // Skip a failed track; the playlist just won't be "fully" done.
          }
        }
        progress[id] = doneCount() / total;
      }
    } finally {
      progress.remove(id);
      if (PlaylistDownloadService.isFullyDownloaded(id)) {
        downloadedIds.add(id);
        Get.snackbar('Playlist downloaded',
            '“${pl.name}” is available offline',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.card,
            colorText: AppColors.white,
            duration: const Duration(seconds: 2));
      } else {
        Get.snackbar('Download incomplete',
            'Some songs in “${pl.name}” couldn’t be downloaded — tap download to retry',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.card,
            colorText: AppColors.white,
            duration: const Duration(seconds: 3));
      }
    }
  }

  /// Remove a playlist's offline copy (files + registry).
  Future<void> removeDownload(LocalPlaylist pl) async {
    await PlaylistDownloadService.removePlaylist(pl.id);
    downloadedIds.remove(pl.id);
  }
}
