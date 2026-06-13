// ui/theme/glass.dart
//
// Glassmorphism primitives — the Z2 "glass layer" from DESIGN.md.
// A backdrop blur clipped to a rounded rect, a thin 12% white inner border,
// and an 8%→16% white fill that brightens on press for tactile feedback.
// Everything floating (mini-player, nav dock, search field, sheets) is built
// on top of these so the blur/border/elevation stay consistent app-wide.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A frosted-glass surface: rounded, blurred backdrop with a hairline border.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color fill;
  final bool border;
  final List<BoxShadow>? shadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 30, // DESIGN.md: 30px backdrop blur on glass elements
    this.radius = AppRadius.xl,
    this.padding,
    this.fill = AppColors.glassFill,
    this.border = true,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      // Shadows are applied on the outer container (can't live behind a blur).
      decoration: BoxDecoration(borderRadius: br, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: br,
              border: border
                  ? Border.all(color: AppColors.glassBorder, width: 1)
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The diffused, ultra-low-opacity shadow DESIGN.md prescribes for Z2
/// elements: `0px 8px 40px rgba(0,0,0,0.25)`.
const List<BoxShadow> kGlassShadow = [
  BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 8)),
];

/// A circular glass icon button with a press-state brighten.
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color iconColor;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.iconColor = Colors.white,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        AppHaptics.light();
        widget.onTap();
      },
      child: GlassContainer(
        radius: AppRadius.pill,
        fill: _down ? AppColors.glassFillActive : AppColors.glassFill,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Icon(widget.icon, size: widget.iconSize, color: widget.iconColor),
        ),
      ),
    );
  }
}
