import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class LiveToyPreview extends StatefulWidget {
  const LiveToyPreview({
    super.key,
    required this.imageFile,
    this.height = 170,
    this.borderRadius = 14,
  });

  final File imageFile;
  final double height;
  final double borderRadius;

  @override
  State<LiveToyPreview> createState() => _LiveToyPreviewState();
}

class _LiveToyPreviewState extends State<LiveToyPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragX = 0;
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
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
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final size = Size(width, widget.height);

        return GestureDetector(
          onPanDown: (details) => _updateDrag(details.localPosition, size),
          onPanUpdate: (details) => _updateDrag(details.localPosition, size),
          onPanEnd: (_) => _resetDrag(),
          onPanCancel: _resetDrag,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final waveX = math.sin(t * math.pi * 2) * 0.02;
              final waveY = math.cos(t * math.pi * 2) * 0.02;
              final breathing = 1.0 + (math.sin(t * math.pi * 2) * 0.007);
              final tiltX = (waveY * -1) + (_dragY * -0.09);
              final tiltY = waveX + (_dragX * 0.11);

              return Container(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x44394D7A).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: Offset(_dragX * 2, 10 + (_dragY.abs() * 2)),
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
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(tiltX)
                          ..rotateY(tiltY)
                          ..scaleByDouble(breathing, breathing, 1.0, 1.0),
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1.1 + (t * 1.6), -1.2),
                              end: Alignment(0.3 + (t * 1.6), 1.1),
                              colors: const [
                                Color(0x00FFFFFF),
                                Color(0x33FFFFFF),
                                Color(0x00FFFFFF),
                              ],
                              stops: const [0.05, 0.5, 0.95],
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.58),
                              width: 1.1,
                            ),
                            borderRadius:
                                BorderRadius.circular(widget.borderRadius),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
