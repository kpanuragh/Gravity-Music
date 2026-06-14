// ui/library/import_playlist.dart
//
// Playlist Import flow (Spotify / Apple Music → Gravity Music):
//   1. URL bottom sheet            → showImportPlaylistSheet()
//   2. Preview screen              → ImportPreviewScreen (count, ETA, songs)
//   3. "Playlist name" dialog      → _promptPlaylistName()
//   4. Simulated-progress screen   → ImportProgressScreen
//   5. Saves a normal LocalPlaylist and opens PlaylistDetailScreen.
//
// Everything funnels into the existing playlist architecture (LibraryService +
// SearchResult.toLibraryTrack), so an imported playlist is identical to a
// hand-made one. UI uses the existing design tokens / shared widgets.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/import_service.dart';
import '../../services/library_service.dart';
import '../../services/search_service.dart';
import '../app_theme.dart';
import '../theme/glass.dart';
import '../theme/motion.dart';
import '../ui_helpers.dart';
import '../widgets/common_widgets.dart';
import '../widgets/mini_player.dart';
import 'library_screen.dart';

// ── Step 1: paste-URL bottom sheet ───────────────────────────────────────────

void showImportPlaylistSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ImportUrlSheet(rootContext: context),
  );
}

class _ImportUrlSheet extends StatefulWidget {
  /// The screen context (not the sheet's) used to push the preview screen.
  final BuildContext rootContext;
  const _ImportUrlSheet({required this.rootContext});

  @override
  State<_ImportUrlSheet> createState() => _ImportUrlSheetState();
}

class _ImportUrlSheetState extends State<_ImportUrlSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste a playlist link to continue.');
      return;
    }
    if (!url.contains('spotify.com') && !url.contains('music.apple.com')) {
      setState(() =>
          _error = 'Only Spotify and Apple Music playlist links are supported.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await ImportService.fetchDetails(url);
      if (!mounted) return;
      if (details.songCount == 0 || details.songs.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'This playlist looks empty — nothing to import.';
        });
        return;
      }
      Navigator.of(context).pop(); // close sheet
      if (!widget.rootContext.mounted) return;
      Navigator.of(widget.rootContext).push(MaterialPageRoute(
        builder: (_) => ImportPreviewScreen(url: url, details: details),
      ));
    } on ImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassContainer(
        radius: AppRadius.xl,
        blur: 30,
        fill: AppColors.card.withOpacity(0.72),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 16),
            Text('Import Playlist', style: AppText.heading(size: 22)),
            const SizedBox(height: 4),
            Text('Paste a Spotify or Apple Music playlist link.',
                style: AppText.subtitle(size: 14)),
            const SizedBox(height: AppSpacing.gutter),
            GlassContainer(
              radius: AppRadius.lg,
              fill: AppColors.glassFill,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      color: AppColors.textTertiary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      enabled: !_loading,
                      style: AppText.title(size: 14),
                      cursorColor: Colors.white,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _continue(),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: InputBorder.none,
                        hintText: 'https://open.spotify.com/playlist/…',
                        hintStyle: AppText.subtitle(size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: AppText.subtitle(size: 13, color: AppColors.accent)),
            ],
            const SizedBox(height: AppSpacing.gutter),
            _loading
                ? const _LoadingButton(label: 'Fetching playlist…')
                : PrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onTap: _continue,
                  ),
          ],
        ),
      ),
    );
  }
}

/// Disabled primary-button look with a spinner, for in-flight actions.
class _LoadingButton extends StatelessWidget {
  final String label;
  const _LoadingButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 10),
          Text(label, style: AppText.button()),
        ],
      ),
    );
  }
}

// ── Step 2/3: preview screen ────────────────────────────────────────────────

class ImportPreviewScreen extends StatelessWidget {
  final String url;
  final PlaylistImportDetails details;
  const ImportPreviewScreen(
      {super.key, required this.url, required this.details});

  String _eta() {
    final s = details.estimatedSeconds;
    if (s <= 0) return 'a few moments';
    if (s < 60) return 'about $s seconds';
    final m = (s / 60).round();
    return 'about $m ${m == 1 ? 'minute' : 'minutes'}';
  }

  Future<void> _startImport(BuildContext context) async {
    final name = await _promptPlaylistName(
      context,
      initial: details.name ?? 'Imported Playlist',
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          ImportProgressScreen(url: url, name: name, details: details),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ScreenWithMiniPlayer(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.canvas,
              pinned: true,
              leading: const AppBackButton(),
              title: Text('Import Playlist', style: AppText.title(size: 18)),
            ),
            // ── Summary ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, 8,
                    AppSpacing.screenMargin, AppSpacing.stackSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(details.name ?? 'Playlist preview',
                        style: AppText.heading(size: 26)),
                    const SizedBox(height: 6),
                    Text('${details.songCount} songs',
                        style: AppText.subtitle(
                            size: 15, color: AppColors.textSecondaryHi)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 15, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Text('Estimated import time: ${_eta()}',
                            style: AppText.subtitle(size: 13)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    PrimaryButton(
                      label: 'Import',
                      icon: Icons.download_rounded,
                      onTap: () => _startImport(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.stackMd),
                child: SectionHeader(title: 'Songs'),
              ),
            ),
            // ── Song-name list ────────────────────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final song = details.songs[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenMargin, vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 12),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: AppColors.textTertiary,
                                shape: BoxShape.circle),
                          ),
                        ),
                        Expanded(
                          child: Text(prettyTitle(song),
                              style: AppText.title(size: 14)),
                        ),
                      ],
                    ),
                  );
                },
                childCount: details.songs.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: name dialog ─────────────────────────────────────────────────────

Future<String?> _promptPlaylistName(BuildContext context,
    {required String initial}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Playlist name', style: AppText.title(size: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: AppText.title(size: 15),
        decoration: const InputDecoration(hintText: 'Playlist name'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Import')),
      ],
    ),
  );
}

// ── Step 5/6: import + simulated progress ───────────────────────────────────

class ImportProgressScreen extends StatefulWidget {
  final String url;
  final String name;
  final PlaylistImportDetails details;
  const ImportProgressScreen({
    super.key,
    required this.url,
    required this.name,
    required this.details,
  });

  @override
  State<ImportProgressScreen> createState() => _ImportProgressScreenState();
}

class _ImportProgressScreenState extends State<ImportProgressScreen> {
  static const _holdCap = 0.95; // hold here until the import actually finishes

  double _progress = 0;
  bool _done = false;
  bool _error = false;
  String _errMsg = '';
  Timer? _ticker;
  DateTime _start = DateTime.now();

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _begin() {
    _error = false;
    _done = false;
    _progress = 0;
    _start = DateTime.now();
    final estSec = widget.details.estimatedSeconds.clamp(1, 600);

    // Simulated progress: smooth 0 → 95% across the estimated time. Capped at
    // 95% so it visibly "waits" if the import runs long; jumps to 100% the
    // moment the real import completes.
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_done || _error) return;
      final elapsed =
          DateTime.now().difference(_start).inMilliseconds / 1000.0;
      final p = (elapsed / estSec).clamp(0.0, _holdCap);
      setState(() => _progress = p);
    });

    _runImport();
  }

  Future<void> _runImport() async {
    try {
      final songs = await ImportService.importPlaylist(
        widget.url,
        estimatedSeconds: widget.details.estimatedSeconds,
      );
      if (songs.isEmpty) {
        throw const ImportException(
            'No songs could be imported from this playlist.');
      }

      // Funnel into the EXISTING playlist architecture — identical to a
      // manually-created playlist from here on.
      final tracks =
          songs.map((SearchResult s) => s.toLibraryTrack()).toList();
      final playlist =
          LibraryService.createPlaylistWithTracks(widget.name, tracks);

      _ticker?.cancel();
      _done = true;
      await _finishBar();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
      ));
    } on ImportException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Import failed. Please try again.');
    }
  }

  void _fail(String msg) {
    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _error = true;
      _errMsg = msg;
    });
  }

  /// Quickly run the bar from its current value up to 100%.
  Future<void> _finishBar() async {
    final from = _progress;
    const steps = 16;
    for (var i = 1; i <= steps; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 20));
      setState(() => _progress = from + (1.0 - from) * (i / steps));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.stackLg),
          child: Center(
            child: _error ? _errorView() : _progressView(),
          ),
        ),
      ),
    );
  }

  Widget _progressView() {
    final pct = (_progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Icon(
            _done ? Icons.check_rounded : Icons.library_music_rounded,
            size: 44,
            color: _done ? Colors.greenAccent : Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        Text(widget.name,
            textAlign: TextAlign.center, style: AppText.heading(size: 22)),
        const SizedBox(height: 6),
        Text(
          _done ? 'Finishing up…' : 'Importing ${widget.details.songCount} songs…',
          style: AppText.subtitle(size: 14),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        // Progress bar.
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(
            children: [
              Container(height: 6, color: AppColors.glassFillActive),
              AnimatedFractionallySizedBox(
                duration: AppMotion.fast,
                curve: AppMotion.standardCurve,
                widthFactor: _progress.clamp(0.0, 1.0),
                child: Container(height: 6, color: AppColors.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('$pct%', style: AppText.caption(color: AppColors.textSecondaryHi)),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 56, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.gutter),
        Text('Import failed', style: AppText.heading(size: 20)),
        const SizedBox(height: AppSpacing.stackSm),
        Text(_errMsg,
            textAlign: TextAlign.center, style: AppText.subtitle(size: 14)),
        const SizedBox(height: AppSpacing.stackMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 130,
              child: SecondaryButton(
                label: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: AppSpacing.gutter),
            SizedBox(
              width: 130,
              child: PrimaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onTap: () => setState(_begin),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
