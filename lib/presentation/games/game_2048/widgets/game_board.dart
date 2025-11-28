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
        if (details.primaryVelocity! < 0) {
          onMove('up');
        } else if (details.primaryVelocity! > 0) {
          onMove('down');
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          onMove('left');
        } else if (details.primaryVelocity! > 0) {
          onMove('right');
        }
      },
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFFBBADA0),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridSize = gameLogic.gridSize;
              final tileSize = (constraints.maxWidth - (gridSize - 1) * 10) / gridSize;
              
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
                  return TileWidget(value: gameLogic.grid[r][c], size: tileSize);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
