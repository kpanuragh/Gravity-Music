// ui/shell/floating_nav_bar.dart
//
// Apple-Music-style floating glass tab bar (DESIGN.md → Navigation). A pill
// container suspended above the content with a 30px blur and 12% border.
// The active tab gets an elevated circular indicator that springs into place.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_theme.dart';
import '../theme/dynamic_color_controller.dart';
import '../theme/glass.dart';

class NavDestination {
  final IconData icon;
  final String label;
  const NavDestination(this.icon, this.label);
}

const List<NavDestination> kNavDestinations = [
  NavDestination(Icons.home_rounded, 'Home'),
  NavDestination(Icons.search_rounded, 'Search'),
  NavDestination(Icons.library_music_rounded, 'Library'),
  NavDestination(Icons.queue_music_rounded, 'Queue'),
];

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Get.find<DynamicColorController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.stackLg),
      child: GlassContainer(
        radius: AppRadius.pill,
        blur: 30,
        shadow: kGlassShadow,
        fill: AppColors.glassFill,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(kNavDestinations.length, (i) {
            final dest = kNavDestinations[i];
            final selected = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.selection();
                  onTap(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.accent.value.withOpacity(0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: selected
                        ? Border.all(color: AppColors.glassBorder)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(dest.icon,
                          size: 22,
                          color: selected
                              ? Colors.white
                              : AppColors.textTertiary),
                      if (selected) ...[
                        const SizedBox(height: 2),
                        Text(dest.label,
                            style: AppText.caption(color: Colors.white)
                                .copyWith(fontSize: 9, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
