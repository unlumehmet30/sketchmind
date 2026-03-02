import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MascotMood {
  idle,
  happy,
  excited,
  thinking,
  warning,
  sleepy,
  celebrate,
}

class MascotReaction {
  const MascotReaction({
    required this.mood,
    required this.message,
  });

  final MascotMood mood;
  final String message;
}

class ReactiveMascot extends StatefulWidget {
  const ReactiveMascot({
    super.key,
    required this.name,
    required this.reaction,
    this.onTap,
  });

  final String name;
  final MascotReaction reaction;
  final VoidCallback? onTap;

  @override
  State<ReactiveMascot> createState() => _ReactiveMascotState();
}

class _ReactiveMascotState extends State<ReactiveMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visualByMood(widget.reaction.mood);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 224),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              );

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: Container(
              key: ValueKey<String>(
                '${widget.reaction.mood.name}_${widget.reaction.message}',
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: visual.primary.withValues(alpha: 0.36),
                  width: 1.1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F2D4E82),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Text(
                widget.reaction.message,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: visual.textColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final floatY = math.sin(t * math.pi * 2) * 3.0;
                final tilt = math.sin(t * math.pi * 2) * visual.tiltAmount;
                final scale = 1.0 + (math.cos(t * math.pi * 2) * 0.018);

                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: Transform.rotate(
                    angle: tilt,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [visual.primary, visual.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: visual.primary.withValues(alpha: 0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 17,
                      left: 20,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 17,
                      right: 20,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 34,
                      child: Icon(
                        visual.icon,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.name,
              style: TextStyle(
                color: visual.textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _MascotVisual _visualByMood(MascotMood mood) {
    switch (mood) {
      case MascotMood.happy:
        return const _MascotVisual(
          primary: Color(0xFF75C9FF),
          secondary: Color(0xFF8EA3FF),
          textColor: Color(0xFF274C7E),
          icon: Icons.tag_faces_rounded,
          tiltAmount: 0.04,
        );
      case MascotMood.excited:
        return const _MascotVisual(
          primary: Color(0xFFFFA6D8),
          secondary: Color(0xFFFFC19E),
          textColor: Color(0xFF7A335A),
          icon: Icons.bolt_rounded,
          tiltAmount: 0.06,
        );
      case MascotMood.thinking:
        return const _MascotVisual(
          primary: Color(0xFFA7B0FF),
          secondary: Color(0xFF8CD7FF),
          textColor: Color(0xFF2F4070),
          icon: Icons.psychology_alt_rounded,
          tiltAmount: 0.03,
        );
      case MascotMood.warning:
        return const _MascotVisual(
          primary: Color(0xFFFFB48A),
          secondary: Color(0xFFFF8A9E),
          textColor: Color(0xFF6D3341),
          icon: Icons.warning_amber_rounded,
          tiltAmount: 0.015,
        );
      case MascotMood.sleepy:
        return const _MascotVisual(
          primary: Color(0xFF9AA8C5),
          secondary: Color(0xFFB8C2DB),
          textColor: Color(0xFF3E4D68),
          icon: Icons.bedtime_rounded,
          tiltAmount: 0.01,
        );
      case MascotMood.celebrate:
        return const _MascotVisual(
          primary: Color(0xFF8FD88F),
          secondary: Color(0xFF72C7C7),
          textColor: Color(0xFF265A51),
          icon: Icons.celebration_rounded,
          tiltAmount: 0.055,
        );
      case MascotMood.idle:
        return const _MascotVisual(
          primary: Color(0xFFA6BAFF),
          secondary: Color(0xFFD39BFF),
          textColor: Color(0xFF3B4B7A),
          icon: Icons.waving_hand_rounded,
          tiltAmount: 0.025,
        );
    }
  }
}

class _MascotVisual {
  const _MascotVisual({
    required this.primary,
    required this.secondary,
    required this.textColor,
    required this.icon,
    required this.tiltAmount,
  });

  final Color primary;
  final Color secondary;
  final Color textColor;
  final IconData icon;
  final double tiltAmount;
}
