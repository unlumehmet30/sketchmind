import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

// ─── Santorini Game Screen ──────────────────────────────────────────────────

enum _Phase { selectWorker, moveWorker, build }
enum _Player { user, ai }

class SantoriniScreen extends StatefulWidget {
  const SantoriniScreen({super.key});

  @override
  State<SantoriniScreen> createState() => _SantoriniScreenState();
}

class _SantoriniScreenState extends State<SantoriniScreen> {
  final Random _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  // Grid 5×5: levels 0–3, dome = 4
  late List<int> _levels; // 25 cells
  late List<_Player?> _workers; // which player occupies each cell

  int _userWins = 0;
  int _aiWins = 0;
  bool _isGameOver = false;
  bool _isAiThinking = false;
  String _statusText = 'İşçini seç.';

  _Phase _phase = _Phase.selectWorker;
  int? _selectedWorker;

  @override
  void initState() {
    super.initState();
    _resetGame(keepScore: true);
  }

  void _resetGame({required bool keepScore}) {
    setState(() {
      _levels = List.filled(25, 0);
      _workers = List.filled(25, null);

      // Place workers: user at bottom, AI at top
      _workers[21] = _Player.user;
      _workers[23] = _Player.user;
      _workers[1] = _Player.ai;
      _workers[3] = _Player.ai;

      if (!keepScore) {
        _userWins = 0;
        _aiWins = 0;
      }
      _isGameOver = false;
      _isAiThinking = false;
      _phase = _Phase.selectWorker;
      _selectedWorker = null;
      _statusText = 'İşçini seç.';
    });
  }

  // ─── Adjacency ──────────────────────────────────────────────────────────

  List<int> _adjacent(int cell) {
    final row = cell ~/ 5;
    final col = cell % 5;
    final result = <int>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr;
        final nc = col + dc;
        if (nr >= 0 && nr < 5 && nc >= 0 && nc < 5) {
          result.add(nr * 5 + nc);
        }
      }
    }
    return result;
  }

  List<int> _validMoves(int workerCell) {
    final currentLevel = _levels[workerCell];
    return _adjacent(workerCell).where((cell) {
      return _workers[cell] == null &&
          _levels[cell] < 4 && // not a dome
          _levels[cell] <= currentLevel + 1; // can go up max +1
    }).toList();
  }

  List<int> _validBuilds(int workerCell) {
    return _adjacent(workerCell).where((cell) {
      return _workers[cell] == null && _levels[cell] < 4;
    }).toList();
  }

  // ─── User interaction ───────────────────────────────────────────────────

  void _onCellTap(int cell) {
    if (_isGameOver || _isAiThinking) return;

    switch (_phase) {
      case _Phase.selectWorker:
        if (_workers[cell] == _Player.user) {
          final moves = _validMoves(cell);
          if (moves.isEmpty) {
            setState(() => _statusText = 'Bu işçi hareket edemiyor!');
            return;
          }
          setState(() {
            _selectedWorker = cell;
            _phase = _Phase.moveWorker;
            _statusText = 'Nereye hareket etsin?';
          });
        }
        break;

      case _Phase.moveWorker:
        if (_workers[cell] == _Player.user) {
          // Re-select different worker
          final moves = _validMoves(cell);
          if (moves.isNotEmpty) {
            setState(() {
              _selectedWorker = cell;
              _statusText = 'Nereye hareket etsin?';
            });
          }
          return;
        }
        if (_selectedWorker == null) return;
        final moves = _validMoves(_selectedWorker!);
        if (!moves.contains(cell)) return;

        setState(() {
          _workers[cell] = _Player.user;
          _workers[_selectedWorker!] = null;
          _selectedWorker = cell;
        });

        // Win check: moved to level 3
        if (_levels[cell] == 3) {
          _finishGame(winner: _Player.user);
          return;
        }

        setState(() {
          _phase = _Phase.build;
          _statusText = 'Nereye inşa etsin?';
        });
        break;

      case _Phase.build:
        if (_selectedWorker == null) return;
        final builds = _validBuilds(_selectedWorker!);
        if (!builds.contains(cell)) return;

        setState(() {
          _levels[cell] += 1;
          _selectedWorker = null;
          _phase = _Phase.selectWorker;
          _isAiThinking = true;
          _statusText = 'AI düşünüyor…';
        });

        _playAiTurn();
        break;
    }
  }

  // ─── AI turn ────────────────────────────────────────────────────────────

  Future<void> _playAiTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || _isGameOver) return;

    final aiWorkers = <int>[];
    for (var i = 0; i < 25; i++) {
      if (_workers[i] == _Player.ai) aiWorkers.add(i);
    }

    // Check if AI can move at all
    var canMove = false;
    for (final w in aiWorkers) {
      if (_validMoves(w).isNotEmpty) {
        canMove = true;
        break;
      }
    }
    if (!canMove) {
      _finishGame(winner: _Player.user);
      return;
    }

    // Evaluate all move+build combos
    var bestScore = -999999;
    int? bestWorker;
    int? bestMove;
    int? bestBuild;

    for (final w in aiWorkers) {
      final moves = _validMoves(w);
      for (final m in moves) {
        // Simulate move
        _workers[m] = _Player.ai;
        _workers[w] = null;

        // Win immediately?
        if (_levels[m] == 3) {
          _workers[w] = _Player.ai;
          _workers[m] = null;
          // Execute this winning move
          setState(() {
            _workers[m] = _Player.ai;
            _workers[w] = null;
          });
          _finishGame(winner: _Player.ai);
          return;
        }

        final builds = _validBuilds(m);
        for (final b in builds) {
          _levels[b] += 1;
          final score = _evaluateBoard(_Player.ai);
          _levels[b] -= 1;

          if (score > bestScore) {
            bestScore = score;
            bestWorker = w;
            bestMove = m;
            bestBuild = b;
          }
        }

        // Undo move
        _workers[w] = _Player.ai;
        _workers[m] = null;
      }
    }

    if (bestWorker == null || bestMove == null || bestBuild == null) {
      _finishGame(winner: _Player.user);
      return;
    }

    setState(() {
      _workers[bestMove!] = _Player.ai;
      _workers[bestWorker!] = null;
      _levels[bestBuild!] += 1;
      _isAiThinking = false;
      _statusText = 'İşçini seç.';
      _phase = _Phase.selectWorker;
    });

    // Check if user can move
    final userWorkers = <int>[];
    for (var i = 0; i < 25; i++) {
      if (_workers[i] == _Player.user) userWorkers.add(i);
    }
    var userCanMove = false;
    for (final w in userWorkers) {
      if (_validMoves(w).isNotEmpty) {
        userCanMove = true;
        break;
      }
    }
    if (!userCanMove) {
      _finishGame(winner: _Player.ai);
    }
  }

  int _evaluateBoard(_Player perspective) {
    var score = 0;
    for (var i = 0; i < 25; i++) {
      if (_workers[i] == null) continue;
      final level = _levels[i];
      final mobility = _validMoves(i).length;
      final value = level * 30 + mobility * 5;

      if (_workers[i] == perspective) {
        score += value;
      } else {
        score -= value;
      }
    }
    // Add randomness to avoid repetitive play
    score += _random.nextInt(8);
    return score;
  }

  void _finishGame({required _Player winner}) {
    unawaited(
      _progressService.recordGameSession(
        gameId: 'santorini',
        won: winner == _Player.user,
        score: winner == _Player.user ? 100 : 30,
        minutes: 4,
      ),
    );

    setState(() {
      _isGameOver = true;
      _isAiThinking = false;
      if (winner == _Player.user) {
        _userWins += 1;
        _statusText = 'Zirveye ulaştın, kazandın!';
      } else {
        _aiWins += 1;
        _statusText = 'AI kazandı. Stratejini değiştir!';
      }
    });
  }

  // ─── Build UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final highlights = <int>{};
    if (_selectedWorker != null) {
      if (_phase == _Phase.moveWorker) {
        highlights.addAll(_validMoves(_selectedWorker!));
      } else if (_phase == _Phase.build) {
        highlights.addAll(_validBuilds(_selectedWorker!));
      }
    }

    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Santorini'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Santorini Nasıl Oynanır?',
              rules: [
                'Her oyuncunun 2 işçisi var.',
                'Her turda: önce işçini komşu kareye hareket ettir, sonra komşu kareye bir kat inşa et.',
                'Bir kat yukarı çıkabilirsin, ama iki kat birden çıkamazsın.',
                'Aşağıya istediğin kadar inebilirsin.',
                '3. kata çıkan ilk oyuncu kazanır!',
                'Kubbe (4. kat) inşa edersen kimse o kareye çıkamaz.',
              ],
              tip: 'Yüksek yerlere yakın dur, ama rakibini de engelle!',
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
          ),
          IconButton(
            onPressed: () => _resetGame(keepScore: false),
            icon: const Icon(Icons.refresh),
            tooltip: 'Skoru sıfırla',
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
                  icon: Icons.terrain_rounded,
                  title: 'Santorini',
                  subtitle:
                      'İşçilerini hareket ettir, inşa et, zirveye ulaş!',
                  accent: Color(0xFF85D0E7),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    PlayfulStatChip(
                      label: 'Sen',
                      value: '$_userWins',
                      accent: const Color(0xFF759BFF),
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(width: 10),
                    PlayfulStatChip(
                      label: 'AI',
                      value: '$_aiWins',
                      accent: const Color(0xFFFF82BE),
                      icon: Icons.smart_toy_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isAiThinking
                        ? const Color(0xFFFF5D8D)
                        : const Color(0xFF394E76),
                  ),
                ),
                const SizedBox(height: 10),
                // 5×5 Board
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF85D0E7)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 25,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemBuilder: (context, index) {
                            final level = _levels[index];
                            final worker = _workers[index];
                            final isDome = level >= 4;
                            final isHighlight = highlights.contains(index);
                            final isSelected = _selectedWorker == index;

                            return GestureDetector(
                              onTap: () => _onCellTap(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: isDome
                                      ? const Color(0xFF546E90)
                                      : _levelColor(level, isHighlight),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF759BFF)
                                        : isHighlight
                                            ? const Color(0xFF6ACD95)
                                            : Colors.black
                                                .withValues(alpha: 0.06),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: level > 0 && !isDome
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                            blurRadius: level * 2.0,
                                            offset: Offset(0, level * 1.0),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Level indicator
                                    if (level > 0 && !isDome)
                                      Positioned(
                                        bottom: 2,
                                        right: 4,
                                        child: Text(
                                          '$level',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                      ),
                                    // Dome cap
                                    if (isDome)
                                      const Icon(
                                        Icons.domain_rounded,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    // Worker
                                    if (worker != null)
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: worker == _Player.user
                                              ? const Color(0xFF759BFF)
                                              : const Color(0xFFFF82BE),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (worker == _Player.user
                                                      ? const Color(
                                                          0xFF759BFF)
                                                      : const Color(
                                                          0xFFFF82BE))
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 6,
                                            ),
                                          ],
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
                  ),
                ),
                const SizedBox(height: 6),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _legendDot(const Color(0xFF759BFF), 'Sen'),
                    _legendDot(const Color(0xFFFF82BE), 'AI'),
                    _legendDot(const Color(0xFF546E90), 'Kubbe'),
                  ],
                ),
                if (_isGameOver) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _resetGame(keepScore: true),
                    icon: const Icon(Icons.replay),
                    label: const Text('Yeni Oyun'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: const Color(0xFF85D0E7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _levelColor(int level, bool highlight) {
    if (highlight) return const Color(0xFFDCF7EB);
    switch (level) {
      case 0:
        return const Color(0xFFF0F8FF);
      case 1:
        return const Color(0xFFE0EDFF);
      case 2:
        return const Color(0xFFCFDFFC);
      case 3:
        return const Color(0xFFBBD2FA);
      default:
        return const Color(0xFF546E90);
    }
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7A99),
          ),
        ),
      ],
    );
  }
}
