import 'package:flutter/material.dart';
import 'logic/game_logic.dart';
import 'widgets/game_board.dart';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  late GameLogic _gameLogic;

  @override
  void initState() {
    super.initState();
    _gameLogic = GameLogic();
  }

  void _handleMove(String direction) {
    setState(() {
      bool moved = false;
      switch (direction) {
        case 'up':
          moved = _gameLogic.moveUp();
          break;
        case 'down':
          moved = _gameLogic.moveDown();
          break;
        case 'left':
          moved = _gameLogic.moveLeft();
          break;
        case 'right':
          moved = _gameLogic.moveRight();
          break;
      }

      if (moved && _gameLogic.isGameOver) {
        _showGameOverDialog();
      }
    });
  }

  void _resetGame() {
    setState(() {
      _gameLogic.resetGame();
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Oyun Bitti!'),
        content: Text('Skorunuz: ${_gameLogic.score}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('Tekrar Oyna'),
          ),
        ],
      ),
    );
  }

  void _showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nasıl Oynanır?'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('2048 oyununa hoş geldiniz!'),
              SizedBox(height: 10),
              Text('• Fayansları hareket ettirmek için parmağınızı yukarı, aşağı, sola veya sağa kaydırın.'),
              Text('• Aynı sayıya sahip iki fayans çarpıştığında birleşirler (2+2=4, 4+4=8).'),
              Text('• Hedefiniz 2048 sayısına ulaşmak!'),
              SizedBox(height: 10),
              Text('Eğitici Bilgi:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Bu oyun 2\'nin kuvvetlerini öğretir:'),
              Text('2¹ = 2'),
              Text('2² = 4'),
              Text('2³ = 8'),
              Text('...'),
              Text('2¹¹ = 2048'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2048 Eğitici Oyun'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHowToPlayDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SKOR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('${_gameLogic.score}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _resetGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeni Oyun'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GameBoard(
              gameLogic: _gameLogic,
              onMove: _handleMove,
            ),
          ),
        ],
      ),
    );
  }
}
