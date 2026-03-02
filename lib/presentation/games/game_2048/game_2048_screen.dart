import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';
import 'logic/game_logic.dart';
import 'widgets/game_board.dart';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  late GameLogic _gameLogic;
  final LearningProgressService _progressService = LearningProgressService();
  DateTime _startedAt = DateTime.now();

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
      _startedAt = DateTime.now();
    });
  }

  void _showGameOverDialog() {
    final elapsedMinutes =
        DateTime.now().difference(_startedAt).inMinutes.clamp(1, 90);
    unawaited(
      _progressService.recordGameSession(
        gameId: 'game_2048',
        won: _gameLogic.score >= 512,
        score: _gameLogic.score,
        minutes: elapsedMinutes,
      ),
    );

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

  @override
  Widget build(BuildContext context) {
    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('2048 Eğitici Oyun'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
            onPressed: () => showGameInfoDialog(
              context,
              title: '2048 Nasıl Oynanır?',
              rules: [
                'Parmağını yukarı, aşağı, sola veya sağa kaydır.',
                'Aynı sayıdaki iki karo birleşir (2+2=4, 4+4=8).',
                'Hedefe ulaş: 2048 karosunu oluştur!',
                'Hareket alanın biterse oyun biter.',
              ],
              tip: 'Bu oyun 2\'nin kuvvetlerini öğretir: 2, 4, 8, 16 ... 2048!',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
          ),
        ],
      ),
      body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PlayfulGameHero(
                        icon: Icons.grid_4x4_rounded,
                        title: '2048 Sayı Macerası',
                        subtitle: 'Aynı kutuları birleştir ve hedefe ulaş.',
                        accent: Color(0xFF8E97FF),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PlayfulStatChip(
                            label: 'Skor',
                            value: '${_gameLogic.score}',
                            accent: const Color(0xFF6F74FF),
                            icon: Icons.star_rounded,
                          ),
                          const SizedBox(width: 10),
                          const PlayfulStatChip(
                            label: 'Hedef',
                            value: '2048',
                            accent: Color(0xFFFF7FB8),
                            icon: Icons.flag_rounded,
                          ),
                          ElevatedButton.icon(
                            onPressed: _resetGame,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yeni'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFAAB3FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color:
                                const Color(0xFF9DA8FF).withValues(alpha: 0.3),
                          ),
                        ),
                        child: GameBoard(
                          gameLogic: _gameLogic,
                          onMove: _handleMove,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'İpucu: Parmağını kaydırarak kutuları hareket ettir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.indigo.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
