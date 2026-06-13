// ui/queue/queue_screen.dart
//
// "Queue" tab — a full-screen view of the live playback queue from the
// existing MyAudioHandler (queue + mediaItem BehaviorSubjects). Reordering
// and jumping route through the handler's existing APIs (reorderQueue custom
// action via the handler, skipToQueueItem). No queue state is duplicated.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../services/thumb_util.dart';
import '../app_theme.dart';
import '../theme/dynamic_color_controller.dart';
import '../ui_helpers.dart';
import '../widgets/common_widgets.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final handler = pc.audioHandler;
    final colors = Get.find<DynamicColorController>();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, 16,
                AppSpacing.screenMargin, AppSpacing.gutter),
            child: Row(
              children: [
                Expanded(child: Text('Queue', style: AppText.heading(size: 32))),
                GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    pc.clearQueue();
                  },
                  child: Text('Clear',
                      style: AppText.caption(color: AppColors.textSecondaryHi)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MediaItem>>(
              stream: handler.queue,
              initialData: handler.queue.value,
              builder: (_, snap) {
                final queue = snap.data ?? const [];
                if (queue.isEmpty) {
                  return const EmptyState(
                    icon: Icons.queue_music_rounded,
                    title: 'Nothing queued',
                    message: 'Play a song to build your queue.',
                  );
                }
                return StreamBuilder<MediaItem?>(
                  stream: handler.mediaItem,
                  initialData: handler.mediaItem.value,
                  builder: (_, curSnap) {
                    final currentId = curSnap.data?.id;
                    return ListView.builder(
                      padding: const EdgeInsets.only(
                          bottom: AppSpacing.bottomDock),
                      itemCount: queue.length,
                      itemBuilder: (_, i) {
                        final item = queue[i];
                        final active = item.id == currentId;
                        return TrackTile(
                          imageUrl: sizedThumb(
                              item.artUri?.toString(), ThumbnailSize.tile),
                          title: item.title,
                          subtitle: item.artist ?? '',
                          active: active,
                          trailing: active
                              ? Icon(Icons.equalizer_rounded,
                                  color: colors.accent.value, size: 20)
                              : null,
                          onTap: () => handler.skipToQueueItem(i),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
