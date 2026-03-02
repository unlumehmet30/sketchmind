import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

// ─── Blokus Game Screen ─────────────────────────────────────────────────────

class BlokusScreen extends StatefulWidget {
  const BlokusScreen({super.key});

  @override
  State<BlokusScreen> createState() => _BlokusScreenState();
}

class _BlokusScreenState extends State<BlokusScreen> {
  static const int gridSize = 14;
  final Random _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  // 0 = empty, 1 = user, 2 = ai
  late List<List<int>> _grid;

  late List<List<List<int>>> _userPieces;
  late List<List<List<int>>> _aiPieces;
  int _selectedPieceIndex = 0;
  int _userScore = 0;
  int _aiScore = 0;
  bool _isGameOver = false;
  bool _isAiThinking = false;
  bool _userPassed = false;
  bool _aiPassed = false;
  String _statusText = 'Parçanı tahtaya yerleştir.';

  // User's first move must touch their corner (0,0); AI's corner (13,13)
  bool _userFirstMove = true;
  bool _aiFirstMove = true;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      _grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
      _userPieces = _allPieces().toList();
      _aiPieces = _allPieces().toList();
      _selectedPieceIndex = 0;
      _userScore = 0;
      _aiScore = 0;
      _isGameOver = false;
      _isAiThinking = false;
      _userPassed = false;
      _aiPassed = false;
      _userFirstMove = true;
      _aiFirstMove = true;
      _statusText = 'Parçanı tahtaya yerleştir.';
    });
  }

  // ─── Piece definitions (21 standard polyominoes, sizes 1‑5) ─────────────

  static List<List<List<int>>> _allPieces() {
    return [
      // Monomino (1)
      [[0, 0]],
      // Domino (2)
      [[0, 0], [0, 1]],
      // Triominoes (3)
      [[0, 0], [0, 1], [0, 2]],
      [[0, 0], [0, 1], [1, 0]],
      // Tetrominoes (4)
      [[0, 0], [0, 1], [0, 2], [0, 3]],
      [[0, 0], [0, 1], [0, 2], [1, 0]],
      [[0, 0], [0, 1], [0, 2], [1, 1]],
      [[0, 0], [0, 1], [1, 1], [1, 2]],
      [[0, 0], [1, 0], [0, 1], [1, 1]],
      // Pentominoes (5) — a selection of 12
      [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]], // I
      [[0, 0], [0, 1], [0, 2], [0, 3], [1, 0]], // L
      [[0, 0], [0, 1], [0, 2], [0, 3], [1, 1]], // Y
      [[0, 0], [0, 1], [0, 2], [1, 2], [1, 3]], // S
      [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1]], // P
      [[0, 0], [0, 1], [0, 2], [1, 0], [2, 0]], // V
      [[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]], // W
      [[0, 0], [0, 1], [0, 2], [1, 1], [2, 1]], // T
      [[0, 0], [0, 1], [1, 1], [2, 0], [2, 1]], // Z
      [[0, 1], [1, 0], [1, 1], [1, 2], [2, 1]], // +
      [[0, 0], [0, 1], [1, 0], [2, 0], [2, 1]], // U
      [[0, 0], [0, 1], [0, 2], [1, 0], [1, 2]], // C shape
    ];
  }

  // ─── Piece transforms ──────────────────────────────────────────────────

  List<List<int>> _rotatePiece(List<List<int>> piece) {
    return piece.map((c) => [-c[1], c[0]]).toList();
  }

  List<List<int>> _flipPiece(List<List<int>> piece) {
    return piece.map((c) => [-c[0], c[1]]).toList();
  }

  List<List<int>> _normalize(List<List<int>> piece) {
    final minR = piece.map((c) => c[0]).reduce(min);
    final minC = piece.map((c) => c[1]).reduce(min);
    return piece.map((c) => [c[0] - minR, c[1] - minC]).toList();
  }

  void _rotateSelected() {
    if (_isGameOver || _userPieces.isEmpty) return;
    setState(() {
      _userPieces[_selectedPieceIndex] =
          _normalize(_rotatePiece(_userPieces[_selectedPieceIndex]));
    });
  }

  void _flipSelected() {
    if (_isGameOver || _userPieces.isEmpty) return;
    setState(() {
      _userPieces[_selectedPieceIndex] =
          _normalize(_flipPiece(_userPieces[_selectedPieceIndex]));
    });
  }

  // ─── Placement validation ──────────────────────────────────────────────

  bool _isLegalMove(List<List<int>> piece, int anchorR, int anchorC,
      int player, bool firstMove) {
    final cells = piece.map((c) => [c[0] + anchorR, c[1] + anchorC]).toList();

    // All cells in bounds & empty
    for (final c in cells) {
      if (c[0] < 0 || c[0] >= gridSize || c[1] < 0 || c[1] >= gridSize) {
        return false;
      }
      if (_grid[c[0]][c[1]] != 0) return false;
    }

    // No edge-adjacent to own pieces
    for (final c in cells) {
      for (final d in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final nr = c[0] + d[0];
        final nc = c[1] + d[1];
        if (nr < 0 || nr >= gridSize || nc < 0 || nc >= gridSize) continue;
        if (_grid[nr][nc] == player &&
            !cells.any((cc) => cc[0] == nr && cc[1] == nc)) {
          return false;
        }
      }
    }

    if (firstMove) {
      // Must touch starting corner
      final corner = player == 1 ? [0, 0] : [gridSize - 1, gridSize - 1];
      return cells.any((c) => c[0] == corner[0] && c[1] == corner[1]);
    }

    // Must share at least one diagonal with own pieces
    var hasDiag = false;
    for (final c in cells) {
      for (final d in [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
        final nr = c[0] + d[0];
        final nc = c[1] + d[1];
        if (nr < 0 || nr >= gridSize || nc < 0 || nc >= gridSize) continue;
        if (_grid[nr][nc] == player) {
          hasDiag = true;
          break;
        }
      }
      if (hasDiag) break;
    }
    return hasDiag;
  }

  bool _canPlayerPlace(int player, List<List<List<int>>> pieces, bool first) {
    for (final piece in pieces) {
      // Try all 8 orientations
      var oriented = piece;
      for (var r = 0; r < 4; r++) {
        for (final flip in [false, true]) {
          final candidate = _normalize(flip ? _flipPiece(oriented) : oriented);
          for (var row = 0; row < gridSize; row++) {
            for (var col = 0; col < gridSize; col++) {
              if (_isLegalMove(candidate, row, col, player, first)) {
                return true;
              }
            }
          }
        }
        oriented = _rotatePiece(oriented);
      }
    }
    return false;
  }

  // ─── User placement ────────────────────────────────────────────────────

  void _onGridTap(int row, int col) {
    if (_isGameOver || _isAiThinking || _userPieces.isEmpty) return;

    final piece = _userPieces[_selectedPieceIndex];
    if (!_isLegalMove(piece, row, col, 1, _userFirstMove)) {
      setState(() => _statusText = 'Geçersiz yerleştirme!');
      return;
    }

    // Place
    for (final c in piece) {
      _grid[row + c[0]][col + c[1]] = 1;
    }
    final placedCount = piece.length;
    setState(() {
      _userScore += placedCount;
      _userPieces.removeAt(_selectedPieceIndex);
      if (_selectedPieceIndex >= _userPieces.length && _userPieces.isNotEmpty) {
        _selectedPieceIndex = _userPieces.length - 1;
      }
      _userFirstMove = false;
      _userPassed = false;
      _isAiThinking = true;
      _statusText = 'AI düşünüyor…';
    });

    _playAiTurn();
  }

  void _userPass() {
    if (_isGameOver || _isAiThinking) return;
    setState(() {
      _userPassed = true;
      _isAiThinking = true;
      _statusText = 'AI düşünüyor…';
    });
    _playAiTurn();
  }

  // ─── AI turn ────────────────────────────────────────────────────────────

  Future<void> _playAiTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || _isGameOver) return;

    // Try to place largest piece first (greedy)
    var placed = false;

    // Sort AI pieces by size descending
    final indexed = List.generate(_aiPieces.length, (i) => i);
    indexed.sort((a, b) => _aiPieces[b].length.compareTo(_aiPieces[a].length));

    for (final pi in indexed) {
      final piece = _aiPieces[pi];
      var oriented = piece;

      var found = false;
      for (var r = 0; r < 4 && !found; r++) {
        for (final flip in [false, true]) {
          if (found) break;
          final candidate = _normalize(flip ? _flipPiece(oriented) : oriented);

          // Shuffle positions for variety
          final positions = <List<int>>[];
          for (var row = 0; row < gridSize; row++) {
            for (var col = 0; col < gridSize; col++) {
              positions.add([row, col]);
            }
          }
          positions.shuffle(_random);

          for (final pos in positions) {
            if (_isLegalMove(candidate, pos[0], pos[1], 2, _aiFirstMove)) {
              for (final c in candidate) {
                _grid[pos[0] + c[0]][pos[1] + c[1]] = 2;
              }
              setState(() {
                _aiScore += candidate.length;
                _aiPieces.removeAt(pi);
                _aiFirstMove = false;
                _aiPassed = false;
              });
              found = true;
              placed = true;
              break;
            }
          }
        }
        oriented = _rotatePiece(oriented);
      }
      if (found) break;
    }

    if (!placed) {
      _aiPassed = true;
    }

    // Check game end
    if ((_userPassed || _userPieces.isEmpty || !_canPlayerPlace(1, _userPieces, _userFirstMove)) &&
        (_aiPassed || _aiPieces.isEmpty || !_canPlayerPlace(2, _aiPieces, _aiFirstMove))) {
      _finishGame();
      return;
    }

    setState(() {
      _isAiThinking = false;
      _statusText = _userPieces.isEmpty
          ? 'Parçan kalmadı!'
          : 'Parçanı tahtaya yerleştir.';
    });
  }

  void _finishGame() {
    final userWon = _userScore > _aiScore;
    unawaited(
      _progressService.recordGameSession(
        gameId: 'blokus',
        won: userWon,
        score: _userScore,
        minutes: 5,
      ),
    );

    setState(() {
      _isGameOver = true;
      _isAiThinking = false;
      _statusText = userWon
          ? 'Kazandın! $_userScore - $_aiScore'
          : _userScore == _aiScore
              ? 'Berabere! $_userScore - $_aiScore'
              : 'AI kazandı! $_aiScore - $_userScore';
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Blokus'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Blokus Nasıl Oynanır?',
              rules: [
                'Sırayla parçalarını tahtaya yerleştir.',
                'İlk parçan köşe karesine değmeli.',
                'Sonraki parçaların kendi rengine sadece KÖŞEDEN değmeli.',
                'Kendi rengine KENARDAN değemezsin! Bu en önemli kural.',
                'En çok kare kaplayan oyuncu kazanır.',
                'Döndür ve çevir butonlarıyla parçanı şekillendir.',
              ],
              tip: 'Büyük parçaları önce kullan, küçükleri sona sakla!',
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
          ),
          IconButton(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yeniden başla',
          ),
        ],
      ),
      body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PlayfulGameHero(
                  icon: Icons.dashboard_rounded,
                  title: 'Blokus',
                  subtitle:
                      'Parçaları köşeden bağla, kenardan değme!',
                  accent: Color(0xFFFF9AA2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PlayfulStatChip(
                      label: 'Sen',
                      value: '$_userScore',
                      accent: const Color(0xFF759BFF),
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(width: 8),
                    PlayfulStatChip(
                      label: 'AI',
                      value: '$_aiScore',
                      accent: const Color(0xFFFF82BE),
                      icon: Icons.smart_toy_rounded,
                    ),
                    const Spacer(),
                    if (!_isGameOver) ...[
                      IconButton(
                        onPressed: _rotateSelected,
                        icon: const Icon(Icons.rotate_right_rounded),
                        tooltip: 'Döndür',
                        iconSize: 22,
                      ),
                      IconButton(
                        onPressed: _flipSelected,
                        icon: const Icon(Icons.flip_rounded),
                        tooltip: 'Çevir',
                        iconSize: 22,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isAiThinking
                        ? const Color(0xFFFF5D8D)
                        : const Color(0xFF394E76),
                  ),
                ),
                const SizedBox(height: 6),
                // 14×14 Board
                Expanded(
                  flex: 4,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFF9AA2)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: gridSize * gridSize,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridSize,
                            mainAxisSpacing: 1,
                            crossAxisSpacing: 1,
                          ),
                          itemBuilder: (context, index) {
                            final row = index ~/ gridSize;
                            final col = index % gridSize;
                            final cell = _grid[row][col];
                            final isCorner =
                                (row == 0 && col == 0) ||
                                    (row == gridSize - 1 &&
                                        col == gridSize - 1);

                            return GestureDetector(
                              onTap: () => _onGridTap(row, col),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cell == 1
                                      ? const Color(0xFF759BFF)
                                      : cell == 2
                                          ? const Color(0xFFFF82BE)
                                          : isCorner
                                              ? const Color(0xFFFFF3E0)
                                              : const Color(0xFFFAF9FF),
                                  borderRadius: BorderRadius.circular(2),
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
                // Piece selector
                if (!_isGameOver && _userPieces.isNotEmpty) ...[
                  SizedBox(
                    height: 62,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _userPieces.length,
                      itemBuilder: (context, index) {
                        final piece = _userPieces[index];
                        final isSelected = index == _selectedPieceIndex;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPieceIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 56,
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE0ECFF)
                                  : Colors.white.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF759BFF)
                                    : Colors.black.withValues(alpha: 0.06),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: _buildPieceMini(piece),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _userPass,
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Pas geç'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7A99),
                    ),
                  ),
                ],
                if (_isGameOver)
                  ElevatedButton.icon(
                    onPressed: _resetGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('Yeni Oyun'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      backgroundColor: const Color(0xFFFF9AA2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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

  Widget _buildPieceMini(List<List<int>> piece) {
    final norm = _normalize(piece);
    final maxR = norm.map((c) => c[0]).reduce(max) + 1;
    final maxC = norm.map((c) => c[1]).reduce(max) + 1;
    final cellSize = min(42.0 / maxR, 42.0 / maxC).clamp(4.0, 10.0);

    return SizedBox(
      width: maxC * cellSize,
      height: maxR * cellSize,
      child: CustomPaint(
        painter: _PiecePainter(
          cells: norm,
          cellSize: cellSize,
          color: const Color(0xFF759BFF),
        ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter({
    required this.cells,
    required this.cellSize,
    required this.color,
  });

  final List<List<int>> cells;
  final double cellSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final c in cells) {
      final rect = Rect.fromLTWH(
        c[1] * cellSize,
        c[0] * cellSize,
        cellSize - 0.5,
        cellSize - 0.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PiecePainter oldDelegate) =>
      cells != oldDelegate.cells ||
      cellSize != oldDelegate.cellSize ||
      color != oldDelegate.color;
}
