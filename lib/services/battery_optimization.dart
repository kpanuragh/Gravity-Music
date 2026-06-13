// services/battery_optimization.dart
//
// Thin Dart side of the `com.saragama/battery` MethodChannel (handled in
// MainActivity.kt). Streamed playback stalls when the screen is off because
// Android Doze freezes the app process and restricts its network access; an
// exemption from battery optimization is what keeps background audio alive
// on non-Pixel devices.
//
// We never fire the bare system dialog cold — users reflexively decline a
// permission they didn't ask for. Instead we show a short in-app rationale
// first, and only open the system prompt if they opt in. We ask once.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../ui/app_theme.dart';

class BatteryOptimization {
  static const _channel = MethodChannel('com.saragama/battery');
  static const _prefKey = 'batteryOptPrompted';

  /// Show the in-app rationale once per install (Android only), then the
  /// system exemption dialog if the user accepts. No-op if already exempt,
  /// already asked, or off-Android.
  static Future<void> maybePrompt() async {
    if (!Platform.isAndroid) return;
    final prefs = Hive.box('AppPrefs');
    if (prefs.get(_prefKey) == true) return;
    try {
      final ignoring = await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
      if (ignoring) {
        await prefs.put(_prefKey, true);
        return;
      }
      // Mark asked up-front so a force-quit mid-flow doesn't re-nag.
      await prefs.put(_prefKey, true);
      final accepted = await _showRationale();
      if (accepted == true) {
        await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (_) {
      // Channel unavailable or platform exception — ignore silently.
    }
  }

  static Future<bool?> _showRationale() {
    return Get.dialog<bool>(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.battery_charging_full_rounded,
                  color: AppColors.accent, size: 30),
            ),
            const SizedBox(height: 18),
            Text('Keep music playing',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              'Android can pause background apps to save power, which '
              'interrupts streaming when your screen is off. Allow SaraGama '
              'to ignore battery optimization so playback never stops.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.grey.shade400)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: SecondaryButton(
                  label: 'NOT NOW',
                  outlined: true,
                  onTap: () => Get.back(result: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'ALLOW',
                  onTap: () => Get.back(result: true),
                ),
              ),
            ]),
          ]),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
