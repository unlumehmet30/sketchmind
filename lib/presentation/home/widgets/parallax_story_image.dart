import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ParallaxStoryImage extends StatefulWidget {
  const ParallaxStoryImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.borderRadius = 14,
    this.enableGesture = true,
    this.reducedMotion = false,
  });

  final String imageUrl;
  final double height;
  final double borderRadius;
  final bool enableGesture;
  final bool reducedMotion;

  @override
  State<ParallaxStoryImage> createState() => _ParallaxStoryImageState();
}

class _ParallaxStoryImageState extends State<ParallaxStoryImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragX = 0;
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateDrag(Offset localPosition, Size size) {
    final nx = ((localPosition.dx / size.width) - 0.5) * 2;
    final ny = ((localPosition.dy / size.height) - 0.5) * 2;
    setState(() {
      _dragX = nx.clamp(-1.0, 1.0);
      _dragY = ny.clamp(-1.0, 1.0);
    });
  }

  void _resetDrag() {
    setState(() {
      _dragX = 0;
      _dragY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.reducedMotion) {
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F3C4D80),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.red[100],
                  child: const Center(
                    child: Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            ),
          );
        }

        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final touchSize = Size(width, widget.height);

        final preview = AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final waveX = math.sin(t * math.pi * 2) * 0.018;
            final waveY = math.cos(t * math.pi * 2) * 0.02;
            final scale = 1.02 + (math.sin(t * math.pi * 2) * 0.008);
            final tiltX = (waveY * -1) + (_dragY * -0.08);
            final tiltY = waveX + (_dragX * 0.11);

            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x443C4D80).withValues(alpha: 0.26),
                    blurRadius: 18,
                    offset: Offset(_dragX * 2, 10 + (_dragY.abs() * 3)),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0011)
                        ..rotateX(tiltX)
                        ..rotateY(tiltY)
                        ..scaleByDouble(scale, scale, 1.0, 1.0),
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.red[100],
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.1 + (t * 1.8), -1.0),
                            end: Alignment(0.2 + (t * 1.8), 1.2),
                            colors: const [
                              Color(0x00FFFFFF),
                              Color(0x29FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: const [0.08, 0.48, 0.92],
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(widget.borderRadius),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.56),
                            width: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (!widget.enableGesture) return preview;

        return GestureDetector(
          onPanDown: (details) => _updateDrag(details.localPosition, touchSize),
          onPanUpdate: (details) =>
              _updateDrag(details.localPosition, touchSize),
          onPanEnd: (_) => _resetDrag(),
          onPanCancel: _resetDrag,
          child: preview,
        );
      },
    );
  }
}
