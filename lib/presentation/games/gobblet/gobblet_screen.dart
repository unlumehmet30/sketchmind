import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

// ─── Gobblet Game Screen ────────────────────────────────────────────────────

enum _Owner { user, ai }

class _GobPiece {
  const _GobPiece({required this.owner, required this.size});
  final _Owner owner;
  final int size; // 1, 2, 3
}

class GobbletScreen extends StatefulWidget {
  const GobbletScreen({super.key});

  @override
  State<GobbletScreen> createState() => _GobbletScreenState();
}

class _GobbletScreenState extends State<GobbletScreen> {
  final Random _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  // Board: 4×4, each cell is a stack (bottom → top).
  late List<List<_GobPiece>> _board;

  // Off-board stock: each player starts with 2 pieces of each size (1,2,3).
  late List<_GobPiece> _userStock;
  late List<_GobPiece> _aiStock;

  int _userWins = 0;
  int _aiWins = 0;
  bool _isUserTurn = true;
  bool _isAiThinking = false;
  bool _isGameOver = false;
  String _statusText = 'Bir taş veya stok seç.';

  // Selection state
  _GobPiece? _selectedPiece;
  int? _selectedFromCell; // null → from stock
  bool _selectedFromStock = false;

  @override
  void initState() {
    super.initState();
    _resetGame(keepScore: true);
  }

  void _resetGame({required bool keepScore}) {
    setState(() {
      _board = List.generate(16, (_) => <_GobPiece>[]);
      _userStock = [
        const _GobPiece(owner: _Owner.user, size: 1),
        const _GobPiece(owner: _Owner.user, size: 1),
        const _GobPiece(owner: _Owner.user, size: 2),
        const _GobPiece(owner: _Owner.user, size: 2),
        const _GobPiece(owner: _Owner.user, size: 3),
        const _GobPiece(owner: _Owner.user, size: 3),
      ];
      _aiStock = [
        const _GobPiece(owner: _Owner.ai, size: 1),
        const _GobPiece(owner: _Owner.ai, size: 1),
        const _GobPiece(owner: _Owner.ai, size: 2),
        const _GobPiece(owner: _Owner.ai, size: 2),
        const _GobPiece(owner: _Owner.ai, size: 3),
        const _GobPiece(owner: _Owner.ai, size: 3),
      ];
      if (!keepScore) {
        _userWins = 0;
        _aiWins = 0;
      }
      _isUserTurn = true;
      _isAiThinking = false;
      _isGameOver = false;
      _statusText = 'Bir taş veya stok seç.';
      _clearSelection();
    });
  }

  void _clearSelection() {
    _selectedPiece = null;
    _selectedFromCell = null;
    _selectedFromStock = false;
  }

  // ─── User interaction ───────────────────────────────────────────────────

  void _onStockTap(int stockIndex) {
    if (!_isUserTurn || _isGameOver || _isAiThinking) return;
    if (stockIndex >= _userStock.length) return;

    final piece = _userStock[stockIndex];
    setState(() {
      _selectedPiece = piece;
      _selectedFromCell = null;
      _selectedFromStock = true;
      _statusText = 'Boyut ${piece.size} taşı yerleştir.';
    });
  }

  void _onCellTap(int cell) {
    if (!_isUserTurn || _isGameOver || _isAiThinking) return;

    // If no piece selected, try to pick from board
    if (_selectedPiece == null) {
      final stack = _board[cell];
      if (stack.isNotEmpty && stack.last.owner == _Owner.user) {
        setState(() {
          _selectedPiece = stack.last;
          _selectedFromCell = cell;
          _selectedFromStock = false;
          _statusText = 'Hedef kareyi seç.';
        });
      }
      return;
    }

    // Place selected piece
    final targetStack = _board[cell];
    final topSize = targetStack.isNotEmpty ? targetStack.last.size : 0;

    if (_selectedPiece!.size <= topSize) {
      // Can't place smaller/equal on top
      setState(() => _statusText = 'Daha büyük taş gerekli!');
      return;
    }
    if (_selectedFromCell == cell) {
      // Deselect
      setState(() {
        _clearSelection();
        _statusText = 'Bir taş veya stok seç.';
      });
      return;
    }

    // Execute move
    setState(() {
      if (_selectedFromStock) {
        _userStock.remove(_selectedPiece);
      } else if (_selectedFromCell != null) {
        _board[_selectedFromCell!].removeLast();
      }
      _board[cell].add(_selectedPiece!);
      _clearSelection();
    });

    if (_checkWin(_Owner.user)) {
      _finishGame(winner: _Owner.user);
      return;
    }

    setState(() {
      _isUserTurn = false;
      _isAiThinking = true;
      _statusText = 'AI düşünüyor…';
    });
    _playAiTurn();
  }

  // ─── AI turn ────────────────────────────────────────────────────────────

  Future<void> _playAiTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isGameOver) return;

    final move = _findAiMove();
    if (move == null) {
      // AI can't move — user wins
      _finishGame(winner: _Owner.user);
      return;
    }

    setState(() {
      if (move.fromStock) {
        _aiStock.remove(move.piece);
      } else {
        _board[move.fromCell!].removeLast();
      }
      _board[move.toCell].add(move.piece);
    });

    if (_checkWin(_Owner.ai)) {
      _finishGame(winner: _Owner.ai);
      return;
    }

    setState(() {
      _isUserTurn = true;
      _isAiThinking = false;
      _statusText = 'Sıra sende.';
    });
  }

  _AiMove? _findAiMove() {
    final allMoves = _generateMoves(_Owner.ai);
    if (allMoves.isEmpty) return null;

    // 1. Try to win
    for (final move in allMoves) {
      _applyMove(move);
      final wins = _checkWin(_Owner.ai);
      _undoMove(move);
      if (wins) return move;
    }

    // 2. Block user wins
    final userMoves = _generateMoves(_Owner.user);
    final dangerousCells = <int>{};
    for (final uMove in userMoves) {
      _applyMoveGeneric(uMove.piece, uMove.fromCell, uMove.fromStock, uMove.toCell, _Owner.user);
      if (_checkWin(_Owner.user)) dangerousCells.add(uMove.toCell);
      _undoMoveGeneric(uMove.piece, uMove.fromCell, uMove.fromStock, uMove.toCell, _Owner.user);
    }

    if (dangerousCells.isNotEmpty) {
      for (final move in allMoves) {
        if (dangerousCells.contains(move.toCell)) return move;
      }
    }

    // 3. Center preference + large pieces
    allMoves.shuffle(_random);
    allMoves.sort((a, b) {
      const centerWeight = {5: 3, 6: 3, 9: 3, 10: 3, 0: 1, 3: 1, 12: 1, 15: 1};
      final sa = (centerWeight[a.toCell] ?? 2) + a.piece.size;
      final sb = (centerWeight[b.toCell] ?? 2) + b.piece.size;
      return sb.compareTo(sa);
    });

    return allMoves.first;
  }

  List<_AiMove> _generateMoves(_Owner owner) {
    final moves = <_AiMove>[];
    final stock = owner == _Owner.ai ? _aiStock : _userStock;

    // Stock moves
    final seenSizes = <int>{};
    for (final piece in stock) {
      if (seenSizes.contains(piece.size)) continue;
      seenSizes.add(piece.size);
      for (var cell = 0; cell < 16; cell++) {
        final topSize = _board[cell].isNotEmpty ? _board[cell].last.size : 0;
        if (piece.size > topSize) {
          moves.add(_AiMove(piece: piece, toCell: cell, fromStock: true));
        }
      }
    }

    // Board moves
    for (var fromCell = 0; fromCell < 16; fromCell++) {
      final stack = _board[fromCell];
      if (stack.isEmpty || stack.last.owner != owner) continue;
      final piece = stack.last;
      for (var toCell = 0; toCell < 16; toCell++) {
        if (toCell == fromCell) continue;
        final topSize = _board[toCell].isNotEmpty ? _board[toCell].last.size : 0;
        if (piece.size > topSize) {
          moves.add(_AiMove(piece: piece, fromCell: fromCell, toCell: toCell));
        }
      }
    }

    return moves;
  }

  void _applyMove(_AiMove move) {
    _applyMoveGeneric(move.piece, move.fromCell, move.fromStock, move.toCell, _Owner.ai);
  }

  void _undoMove(_AiMove move) {
    _undoMoveGeneric(move.piece, move.fromCell, move.fromStock, move.toCell, _Owner.ai);
  }

  void _applyMoveGeneric(_GobPiece piece, int? fromCell, bool fromStock, int toCell, _Owner owner) {
    if (fromStock) {
      (owner == _Owner.ai ? _aiStock : _userStock).remove(piece);
    } else if (fromCell != null) {
      _board[fromCell].removeLast();
    }
    _board[toCell].add(piece);
  }

  void _undoMoveGeneric(_GobPiece piece, int? fromCell, bool fromStock, int toCell, _Owner owner) {
    _board[toCell].removeLast();
    if (fromStock) {
      (owner == _Owner.ai ? _aiStock : _userStock).add(piece);
    } else if (fromCell != null) {
      _board[fromCell].add(piece);
    }
  }

  // ─── Win check ──────────────────────────────────────────────────────────

  static const _lines = <List<int>>[
    [0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14, 15],
    [0, 4, 8, 12], [1, 5, 9, 13], [2, 6, 10, 14], [3, 7, 11, 15],
    [0, 5, 10, 15], [3, 6, 9, 12],
  ];

  bool _checkWin(_Owner owner) {
    for (final line in _lines) {
      var allOwner = true;
      for (final cell in line) {
        final stack = _board[cell];
        if (stack.isEmpty || stack.last.owner != owner) {
          allOwner = false;
          break;
        }
      }
      if (allOwner) return true;
    }
    return false;
  }

  void _finishGame({required _Owner winner}) {
    unawaited(
      _progressService.recordGameSession(
        gameId: 'gobblet',
        won: winner == _Owner.user,
        score: winner == _Owner.user ? 100 : 30,
        minutes: 3,
      ),
    );

    setState(() {
      _isGameOver = true;
      _isAiThinking = false;
      if (winner == _Owner.user) {
        _userWins += 1;
        _statusText = 'Tebrikler, kazandın!';
      } else {
        _aiWins += 1;
        _statusText = 'AI kazandı. Tekrar dene!';
      }
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Gobblet'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Gobblet Nasıl Oynanır?',
              rules: [
                'Her oyuncunun 3 farklı boyutta taşları var (1, 2, 3).',
                'Taşları tahtaya koy veya tahtadaki taşını başka yere taşı.',
                'Büyük taş, küçük taşın üstüne konabilir ve onu kapatır!',
                'Yatay, dikey veya çapraz 4 taşını sıraya koyarsan kazanırsın.',
                'Dikkat: Taşını kaldırınca altından rakip çıkabilir!',
              ],
              tip: 'Büyük taşlarını hemen harcama, sonlara sakla!',
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
                  icon: Icons.layers_rounded,
                  title: 'Gobblet',
                  subtitle: 'Tahtada 4 taş sırala, büyük küçüğü yutar!',
                  accent: Color(0xFFE8A87C),
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
                // Status
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
                const SizedBox(height: 8),
                // User stock
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      const Text(
                        'Stok:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7A99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _userStock.length,
                          itemBuilder: (context, index) {
                            final piece = _userStock[index];
                            final isSelected = _selectedFromStock &&
                                _selectedPiece == piece;
                            return GestureDetector(
                              onTap: () => _onStockTap(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 44,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD0E8FF)
                                      : Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF759BFF)
                                        : Colors.black.withValues(alpha: 0.06),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: _buildPieceCircle(piece, 34),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 4×4 board
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                const Color(0xFFE8A87C).withValues(alpha: 0.3),
                          ),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 16,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                          itemBuilder: (context, index) {
                            final stack = _board[index];
                            final top =
                                stack.isNotEmpty ? stack.last : null;
                            final isSelectedCell =
                                _selectedFromCell == index &&
                                    _selectedPiece != null;
                            final canPlace = _selectedPiece != null &&
                                _selectedFromCell != index &&
                                (top == null ||
                                    _selectedPiece!.size > top.size);

                            return GestureDetector(
                              onTap: () => _onCellTap(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                decoration: BoxDecoration(
                                  color: isSelectedCell
                                      ? const Color(0xFFD0E8FF)
                                      : canPlace
                                          ? const Color(0xFFE8FFE8)
                                          : const Color(0xFFF8F4EE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelectedCell
                                        ? const Color(0xFF759BFF)
                                        : canPlace
                                            ? const Color(0xFF6ACD95)
                                                .withValues(alpha: 0.5)
                                            : Colors.black
                                                .withValues(alpha: 0.06),
                                    width: isSelectedCell ? 2.2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: top != null
                                      ? _buildPieceCircle(top, 36)
                                      : (stack.length > 1
                                          ? Text(
                                              '${stack.length}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade400,
                                              ),
                                            )
                                          : null),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isGameOver) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _resetGame(keepScore: true),
                    icon: const Icon(Icons.replay),
                    label: const Text('Yeni Oyun'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: const Color(0xFFE8A87C),
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

  Widget _buildPieceCircle(_GobPiece piece, double maxSize) {
    final ratio = piece.size / 3.0;
    final diameter = maxSize * (0.45 + 0.55 * ratio);
    final color = piece.owner == _Owner.user
        ? const Color(0xFF759BFF)
        : const Color(0xFFFF82BE);

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${piece.size}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _AiMove {
  const _AiMove({
    required this.piece,
    required this.toCell,
    this.fromCell,
    this.fromStock = false,
  });

  final _GobPiece piece;
  final int toCell;
  final int? fromCell;
  final bool fromStock;
}
