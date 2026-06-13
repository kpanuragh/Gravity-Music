// models/hm_streaming_data.dart
// Mirrors HarmonyMusic's HMStreamingData model.

import '../services/stream_service.dart';

class HMStreamingData {
  final bool playable;
  final String statusMSG;
  Audio? _audio; // selected based on quality preference

  Audio? lowQualityAudio;
  Audio? highQualityAudio;

  HMStreamingData({
    required this.playable,
    required this.statusMSG,
    this.lowQualityAudio,
    this.highQualityAudio,
  });

  factory HMStreamingData.fromJson(Map<String, dynamic> json) {
    final low = json['lowQualityAudio'] != null
        ? Audio.fromJson(Map<String, dynamic>.from(json['lowQualityAudio']))
        : null;
    final high = json['highQualityAudio'] != null
        ? Audio.fromJson(Map<String, dynamic>.from(json['highQualityAudio']))
        : null;
    return HMStreamingData(
      playable: json['playable'] ?? false,
      statusMSG: json['statusMSG'] ?? '',
      lowQualityAudio: low,
      highQualityAudio: high,
    );
  }

  /// 0 = low quality, 1 = high quality
  void setQualityIndex(int index) {
    _audio = index == 0 ? lowQualityAudio : highQualityAudio;
    _audio ??= highQualityAudio ?? lowQualityAudio;
  }

  Audio? get audio => _audio ?? highQualityAudio ?? lowQualityAudio;
}
