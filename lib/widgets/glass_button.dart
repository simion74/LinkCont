import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium glass-effect button — a soft glow slowly travels around the
/// side border. Used for the HomeScreen "Registration / Share Screen /
/// Screen View" buttons.
///
/// ==== Control size/padding/blur from here ====
/// height        -> button height (default 64)
/// horizontalPad -> side padding around the icon/text inside (default 18)
/// blurSigma     -> how blurry the glass looks (default 8 — was 16 before,
///                  which made it too blurry)
/// fillOpacity   -> how strong the glass panel's tint color is (0.0 = fully
///                  transparent, 1.0 = fully solid)
class GlassGlowButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color glowColor;
  final VoidCallback onTap;
  final double height;
  final double horizontalPad;
  final double blurSigma;
  final double fillOpacity;
  final double borderRadius;
  final double baseBorderWidth; // thickness of the static base border
  final double glowBorderWidth; // thickness of the rotating glow border

  const GlassGlowButton({
    super.key,
    required this.icon,
    required this.label,
    required this.glowColor,
    required this.onTap,
    this.height = 64,
    this.horizontalPad = 18,
    this.blurSigma = 3,
    this.fillOpacity = 0.12,
    this.borderRadius = 12,
    this.baseBorderWidth = 2.2,
    this.glowBorderWidth = 5,
  });

  @override
  State<GlassGlowButton> createState() => _GlassGlowButtonState();
}

class _GlassGlowButtonState extends State<GlassGlowButton>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();
    // Premium touch feel: slight scale-down on press, springs back on release
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
    HapticFeedback.lightImpact(); // light vibration — premium touch feel
  }

  void _onTapUp(TapUpDetails _) => _pressController.reverse();
  void _onTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: scale,
        child: SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return CustomPaint(
                // Using foregroundPainter so the glow border is drawn **on
                // top of** the glass panel — previously it used painter
                // (background), so the glass panel covered the glow and the
                // border glow wasn't visible.
                foregroundPainter: _GlowBorderPainter(
                  progress: _glowController.value,
                  color: widget.glowColor,
                  radius: widget.borderRadius,
                  baseWidth: widget.baseBorderWidth,
                  glowWidth: widget.glowBorderWidth,
                ),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: widget.horizontalPad),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    // Glass fill tinted with glowColor (mixed with white for
                    // the glass look) instead of plain white, so the panel
                    // itself reflects the button's accent color.
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(Colors.white, widget.glowColor, 0.35)!
                            .withOpacity(widget.fillOpacity + 0.10),
                        Color.lerp(Colors.white, widget.glowColor, 0.35)!
                            .withOpacity(widget.fillOpacity * 0.4),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.glowColor.withOpacity(0.16),
                          border: Border.all(
                            color: widget.glowColor.withOpacity(0.75),
                            width: 1.4,
                          ),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 21),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.white.withOpacity(0.85)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bright light slowly sweeps around the button's rounded border (sweep gradient).
class _GlowBorderPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, one full rotation
  final Color color;
  final double radius;
  final double baseWidth; // thickness of the static base border
  final double glowWidth; // thickness of the rotating bright glow

  _GlowBorderPainter({
    required this.progress,
    required this.color,
    required this.radius,
    this.baseWidth = 1.2,
    this.glowWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(0.8);

    // Light static border (always visible even without the glow) — change
    // baseWidth to make it thicker/thinner
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseWidth
      ..color = color.withOpacity(0.45);
    canvas.drawRRect(rrect, basePaint);

    // Rotating glow — change glowWidth to make it thicker/thinner
    final sweep = SweepGradient(
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(1.0),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.12, 0.28],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..shader = sweep.createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.baseWidth != baseWidth ||
      oldDelegate.glowWidth != glowWidth;
}

/// ID card — used in place of "Registration". Tapping it doesn't navigate
/// anywhere, it just shows the ID text; tapping the copy icon on the right
/// copies it. Looks like GlassGlowButton (same glass + rotating glow border).
class IdDisplayCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color glowColor;
  final VoidCallback onCopy;
  final double height;
  final double blurSigma;
  final double borderRadius;
  final double baseBorderWidth;
  final double glowBorderWidth;

  const IdDisplayCard({
    super.key,
    required this.icon,
    required this.label,
    required this.glowColor,
    required this.onCopy,
    this.height = 64,
    this.blurSigma = 8,
    this.borderRadius = 26,
    this.baseBorderWidth = 1.2,
    this.glowBorderWidth = 2.6,
  });

  @override
  State<IdDisplayCard> createState() => _IdDisplayCardState();
}

class _IdDisplayCardState extends State<IdDisplayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _GlowBorderPainter(
              progress: _glowController.value,
              color: widget.glowColor,
              radius: widget.borderRadius,
              baseWidth: widget.baseBorderWidth,
              glowWidth: widget.glowBorderWidth,
            ),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                // Glass fill tinted with glowColor instead of plain white,
                // so the card reflects its own accent color.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(Colors.white, widget.glowColor, 0.35)!
                        .withOpacity(0.22),
                    Color.lerp(Colors.white, widget.glowColor, 0.35)!
                        .withOpacity(0.06),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.glowColor.withOpacity(0.16),
                      border: Border.all(
                        color: widget.glowColor.withOpacity(0.75),
                        width: 1.4,
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  _CopyTapIcon(
                      onTap: widget.onCopy, glowColor: widget.glowColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Copy icon has its own press animation (premium touch feel)
class _CopyTapIcon extends StatefulWidget {
  final VoidCallback onTap;
  final Color glowColor;
  const _CopyTapIcon({required this.onTap, required this.glowColor});

  @override
  State<_CopyTapIcon> createState() => _CopyTapIconState();
}

class _CopyTapIconState extends State<_CopyTapIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: 0.85).animate(_controller);
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.glowColor.withOpacity(0.16),
          ),
          child: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// Round glass icon button — used for the share icon next to the ID card.
class GlassCircleIconButton extends StatefulWidget {
  final IconData icon;
  final Color glowColor;
  final VoidCallback onTap;
  final double size;

  const GlassCircleIconButton({
    super.key,
    required this.icon,
    required this.glowColor,
    required this.onTap,
    this.size = 64,
  });

  @override
  State<GlassCircleIconButton> createState() => _GlassCircleIconButtonState();
}

class _GlassCircleIconButtonState extends State<GlassCircleIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: scale,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.size / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Glass fill tinted with glowColor instead of plain white
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(Colors.white, widget.glowColor, 0.35)!
                          .withOpacity(0.22),
                      Color.lerp(Colors.white, widget.glowColor, 0.35)!
                          .withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(
                    color: widget.glowColor.withOpacity(0.6),
                    width: 1.2,
                  ),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sits directly on top of the background image (no glass box, like a
/// plain icon on the photo). Also has a light press-feel animation.
class TopIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const TopIconButton({super.key, required this.icon, required this.onTap});

  @override
  State<TopIconButton> createState() => _TopIconButtonState();
}

class _TopIconButtonState extends State<TopIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: 0.88).animate(_controller);
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: scale,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 26,
            shadows: [
              Shadow(
                  color: Colors.black.withOpacity(0.35), blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }
}
