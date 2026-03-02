import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  static const _baseIcons = [
    Icons.pets,
    Icons.rocket_launch,
    Icons.park,
    Icons.sailing,
    Icons.music_note,
    Icons.star,
    Icons.cloud,
    Icons.favorite,
  ];

  final _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  late List<IconData> _cards;
  late List<bool> _revealed;
  late List<bool> _matched;

  int _moves = 0;
  bool _isBusy = false;
  int? _firstSelected;
  int? _secondSelected;
  DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    final generated = [..._baseIcons, ..._baseIcons]..shuffle(_random);
    setState(() {
      _cards = generated;
      _revealed = List<bool>.filled(generated.length, false);
      _matched = List<bool>.filled(generated.length, false);
      _moves = 0;
      _isBusy = false;
      _firstSelected = null;
      _secondSelected = null;
      _startedAt = DateTime.now();
    });
  }

  Future<void> _onCardTap(int index) async {
    if (_isBusy || _matched[index] || _revealed[index]) return;

    setState(() {
      _revealed[index] = true;
      if (_firstSelected == null) {
        _firstSelected = index;
      } else {
        _secondSelected = index;
      }
    });

    if (_firstSelected == null || _secondSelected == null) return;

    final first = _firstSelected!;
    final second = _secondSelected!;

    setState(() {
      _isBusy = true;
      _moves += 1;
    });

    if (_cards[first] == _cards[second]) {
      setState(() {
        _matched[first] = true;
        _matched[second] = true;
      });
    } else {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _revealed[first] = false;
        _revealed[second] = false;
      });
    }

    if (!mounted) return;

    final completed = _matched.every((isDone) => isDone);
    setState(() {
      _firstSelected = null;
      _secondSelected = null;
      _isBusy = false;
    });

    if (completed) {
      _showResultDialog();
    }
  }

  Future<void> _showResultDialog() async {
    final elapsed = DateTime.now().difference(_startedAt);
    final score = max(10, 220 - (_moves * 8) - elapsed.inSeconds);
    unawaited(
      _progressService.recordGameSession(
        gameId: 'memory',
        won: true,
        score: score,
        minutes: max(1, elapsed.inMinutes),
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tebrikler!'),
          content: Text(
            'Tüm kartları buldun.\nHamle: $_moves\nSüre: ${elapsed.inSeconds} sn',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame();
              },
              child: const Text('Tekrar Oyna'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Hafıza Eşleştirme'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Hafıza Eşleştirme',
              rules: [
                'Kartlar ters çevrilmiş olarak başlar.',
                'Her turda 2 kart aç.',
                'Eğer ikisi aynıysa, eşleşme bulursun!',
                'Eğer farklıysa, kartlar tekrar kapanır.',
                'Tüm eşleri en az hamlede bulmaya çalış.',
              ],
              tip: 'Açtığın kartların yerini aklında tut!',
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
          ),
          IconButton(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PlayfulGameHero(
                  icon: Icons.psychology_alt_rounded,
                  title: 'Hafıza Eşleştirme',
                  subtitle: 'Kartları aç, eşleri bul ve dikkatini güçlendir.',
                  accent: Color(0xFFFF8FC8),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PlayfulStatChip(
                      label: 'Hamle',
                      value: '$_moves',
                      accent: const Color(0xFF7F8DFF),
                      icon: Icons.swipe_rounded,
                    ),
                    const SizedBox(width: 10),
                    PlayfulStatChip(
                      label: 'Eşleşen',
                      value:
                          '${_matched.where((item) => item).length ~/ 2}/${_baseIcons.length}',
                      accent: const Color(0xFFFF86C3),
                      icon: Icons.favorite_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.74),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFA2ABFF).withValues(alpha: 0.24),
                      ),
                    ),
                    child: GridView.builder(
                      itemCount: _cards.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final isVisible = _revealed[index] || _matched[index];
                        return InkWell(
                          onTap: () => _onCardTap(index),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: isVisible
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFF2F5FF),
                                        Color(0xFFEFDFFF),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF9FB4FF),
                                        Color(0xFFA88DFF),
                                        Color(0xFFFF9ED1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isVisible
                                    ? _cards[index]
                                    : Icons.question_mark_rounded,
                                size: 30,
                                color: isVisible
                                    ? const Color(0xFF6B67C8)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
