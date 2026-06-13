// background_task.dart
// Mirrors HarmonyMusic's background_task.dart.
// This function is called via Isolate.run() so the main UI thread is never blocked.

import 'package:flutter/services.dart';
import 'stream_service.dart';

/// Called from an isolate. Returns a serialisable Map so it can cross isolate
/// boundaries — same pattern as HarmonyMusic.
Future<Map<String, dynamic>> getStreamInfo(
    String videoId, RootIsolateToken token) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final provider = await StreamProvider.fetch(videoId);
  return provider.hmStreamingData;
}
