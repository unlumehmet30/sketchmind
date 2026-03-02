import 'package:flutter/material.dart';

import '../logic/game_logic.dart';
import 'tile_widget.dart';

class GameBoard extends StatelessWidget {
  final GameLogic gameLogic;
  final Function(String) onMove;

  const GameBoard({super.key, required this.gameLogic, required this.onMove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null) return;
        if (velocity < 0) {
          onMove('up');
        } else if (velocity > 0) {
          onMove('down');
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null) return;
        if (velocity < 0) {
          onMove('left');
        } else if (velocity > 0) {
          onMove('right');
        }
      },
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE6DCFF), Color(0xFFF9E6F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(
              color: const Color(0xFF9585F9).withValues(alpha: 0.32),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridSize = gameLogic.gridSize;
              final tileSize =
                  (constraints.maxWidth - (gridSize - 1) * 10) / gridSize;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: gridSize * gridSize,
                itemBuilder: (context, index) {
                  int r = index ~/ gridSize;
                  int c = index % gridSize;
                  return TileWidget(
                      value: gameLogic.grid[r][c], size: tileSize);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
