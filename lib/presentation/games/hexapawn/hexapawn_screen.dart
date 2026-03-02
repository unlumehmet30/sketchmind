import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

class HexapawnScreen extends StatefulWidget {
  const HexapawnScreen({super.key});

  @override
  State<HexapawnScreen> createState() => _HexapawnScreenState();
}

class _HexapawnScreenState extends State<HexapawnScreen> {
  final Random _random = Random();
  final LearningProgressService _progressService = LearningProgressService();
  late List<List<_Piece?>> _board;

  static const List<Color> _pieceColorOptions = [
    Color(0xFF7D9DFF), // Mavi (varsayılan)
    Color(0xFF6ACD95), // Yeşil
    Color(0xFFFFB95C), // Turuncu
    Color(0xFF9A95FF), // Mor
    Color(0xFF5CC8E4), // Turkuaz
    Color(0xFFFF6F91), // Pembe
  ];

  int _userWins = 0;
  int _aiWins = 0;
  bool _isUserTurn = true;
  bool _isAiThinking = false;
  bool _isGameOver = false;
  String _statusText = 'Sıra sende. Bir piyon seç.';
  Color _userPieceColor = _pieceColorOptions.first;
  bool _userStartsFirst = true;

  int? _selectedRow;
  int? _selectedCol;
  List<_HexMove> _candidateMoves = const [];

  @override
  void initState() {
    super.initState();
    _resetBoard(keepScore: true);
  }

  void _resetBoard({required bool keepScore}) {
    setState(() {
      _board = [
        [_Piece.ai, _Piece.ai, _Piece.ai],
        [null, null, null],
        [_Piece.user, _Piece.user, _Piece.user],
      ];
      if (!keepScore) {
        _userWins = 0;
        _aiWins = 0;
      }
      _isUserTurn = _userStartsFirst;
      _isAiThinking = false;
      _isGameOver = false;
      _statusText = _userStartsFirst
          ? 'Sıra sende. Bir piyon seç.'
          : 'AI düşünüyor...';
      _selectedRow = null;
      _selectedCol = null;
      _candidateMoves = const [];
    });

    if (!_userStartsFirst) {
      _isAiThinking = true;
      _playAiTurn();
    }
  }

  void _onCellTap(int row, int col) {
    if (_isGameOver || _isAiThinking || !_isUserTurn) return;

    final cell = _board[row][col];
    if (cell == _Piece.user) {
      final moves = _movesForPiece(_board, row, col, _Piece.user);
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
        _candidateMoves = moves;
      });
      return;
    }

    if (_selectedRow == null || _selectedCol == null) return;

    _HexMove? selectedMove;
    for (final move in _candidateMoves) {
      if (move.toRow == row && move.toCol == col) {
        selectedMove = move;
        break;
      }
    }

    if (selectedMove == null) return;
    _playUserMove(selectedMove);
  }

  void _playUserMove(_HexMove move) {
    setState(() {
      _applyMove(_board, move);
      _selectedRow = null;
      _selectedCol = null;
      _candidateMoves = const [];
    });

    final winner = _winnerForNextTurn(_board, _Piece.ai);
    if (winner != null) {
      _finishRound(winner);
      return;
    }

    setState(() {
      _isUserTurn = false;
      _isAiThinking = true;
      _statusText = 'AI düşünüyor...';
    });
    _playAiTurn();
  }

  Future<void> _playAiTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || _isGameOver) return;

    final aiMoves = _allMoves(_board, _Piece.ai);
    if (aiMoves.isEmpty) {
      _finishRound(_Piece.user);
      return;
    }

    final aiMove = _chooseAiMove(aiMoves);
    setState(() {
      _applyMove(_board, aiMove);
    });

    final winner = _winnerForNextTurn(_board, _Piece.user);
    if (winner != null) {
      _finishRound(winner);
      return;
    }

    setState(() {
      _isUserTurn = true;
      _isAiThinking = false;
      _statusText = 'Sıra sende.';
    });
  }

  _HexMove _chooseAiMove(List<_HexMove> moves) {
    if (moves.length == 1) return moves.first;

    if (_random.nextDouble() < 0.12) {
      return moves[_random.nextInt(moves.length)];
    }

    var bestScore = -1 << 30;
    final bestMoves = <_HexMove>[];

    for (final move in moves) {
      final cloned = _cloneBoard(_board);
      _applyMove(cloned, move);
      final score = _minimax(
        board: cloned,
        turn: _Piece.user,
        depth: 7,
      );

      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(move);
      } else if (score == bestScore) {
        bestMoves.add(move);
      }
    }

    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  int _minimax({
    required List<List<_Piece?>> board,
    required _Piece turn,
    required int depth,
  }) {
    final winner = _winnerForNextTurn(board, turn);
    if (winner != null || depth == 0) {
      return _evaluateBoard(board, winner, depth);
    }

    final moves = _allMoves(board, turn);
    if (moves.isEmpty) {
      return turn == _Piece.ai ? -1000 : 1000;
    }

    if (turn == _Piece.ai) {
      var best = -1 << 30;
      for (final move in moves) {
        final cloned = _cloneBoard(board);
        _applyMove(cloned, move);
        best = max(
          best,
          _minimax(board: cloned, turn: _Piece.user, depth: depth - 1),
        );
      }
      return best;
    }

    var best = 1 << 30;
    for (final move in moves) {
      final cloned = _cloneBoard(board);
      _applyMove(cloned, move);
      best = min(
        best,
        _minimax(board: cloned, turn: _Piece.ai, depth: depth - 1),
      );
    }
    return best;
  }

  int _evaluateBoard(List<List<_Piece?>> board, _Piece? winner, int depth) {
    if (winner == _Piece.ai) return 200 + depth;
    if (winner == _Piece.user) return -200 - depth;

    final aiCount = _countPieces(board, _Piece.ai);
    final userCount = _countPieces(board, _Piece.user);
    final aiProgress = _progressScore(board, _Piece.ai);
    final userProgress = _progressScore(board, _Piece.user);
    return (aiCount - userCount) * 25 + (aiProgress - userProgress) * 6;
  }

  _Piece? _winnerForNextTurn(List<List<_Piece?>> board, _Piece nextTurn) {
    if (_hasReachedBackRank(board, _Piece.user)) return _Piece.user;
    if (_hasReachedBackRank(board, _Piece.ai)) return _Piece.ai;

    final userCount = _countPieces(board, _Piece.user);
    final aiCount = _countPieces(board, _Piece.ai);
    if (userCount == 0) return _Piece.ai;
    if (aiCount == 0) return _Piece.user;

    final nextMoves = _allMoves(board, nextTurn);
    if (nextMoves.isEmpty) {
      return nextTurn == _Piece.user ? _Piece.ai : _Piece.user;
    }
    return null;
  }

  int _countPieces(List<List<_Piece?>> board, _Piece piece) {
    var count = 0;
    for (final row in board) {
      for (final cell in row) {
        if (cell == piece) count += 1;
      }
    }
    return count;
  }

  int _progressScore(List<List<_Piece?>> board, _Piece piece) {
    var score = 0;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        if (board[row][col] != piece) continue;
        if (piece == _Piece.ai) {
          score += row;
        } else {
          score += (2 - row);
        }
      }
    }
    return score;
  }

  bool _hasReachedBackRank(List<List<_Piece?>> board, _Piece piece) {
    if (piece == _Piece.user) {
      for (var col = 0; col < 3; col++) {
        if (board[0][col] == _Piece.user) return true;
      }
      return false;
    }

    for (var col = 0; col < 3; col++) {
      if (board[2][col] == _Piece.ai) return true;
    }
    return false;
  }

  List<_HexMove> _allMoves(List<List<_Piece?>> board, _Piece piece) {
    final moves = <_HexMove>[];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        if (board[row][col] == piece) {
          moves.addAll(_movesForPiece(board, row, col, piece));
        }
      }
    }
    return moves;
  }

  List<_HexMove> _movesForPiece(
    List<List<_Piece?>> board,
    int row,
    int col,
    _Piece piece,
  ) {
    final direction = piece == _Piece.user ? -1 : 1;
    final targetRow = row + direction;
    if (targetRow < 0 || targetRow > 2) return const [];

    final moves = <_HexMove>[];
    if (board[targetRow][col] == null) {
      moves.add(
          _HexMove(fromRow: row, fromCol: col, toRow: targetRow, toCol: col));
    }

    for (final deltaCol in const [-1, 1]) {
      final targetCol = col + deltaCol;
      if (targetCol < 0 || targetCol > 2) continue;
      final target = board[targetRow][targetCol];
      if (target != null && target != piece) {
        moves.add(
          _HexMove(
            fromRow: row,
            fromCol: col,
            toRow: targetRow,
            toCol: targetCol,
          ),
        );
      }
    }

    return moves;
  }

  List<List<_Piece?>> _cloneBoard(List<List<_Piece?>> board) {
    return board.map((row) => List<_Piece?>.from(row)).toList();
  }

  void _applyMove(List<List<_Piece?>> board, _HexMove move) {
    final piece = board[move.fromRow][move.fromCol];
    board[move.fromRow][move.fromCol] = null;
    board[move.toRow][move.toCol] = piece;
  }

  Future<void> _finishRound(_Piece winner) async {
    unawaited(
      _progressService.recordGameSession(
        gameId: 'hexapawn',
        won: winner == _Piece.user,
        score: winner == _Piece.user ? 100 : 40,
        minutes: 2,
      ),
    );

    setState(() {
      _isGameOver = true;
      _isAiThinking = false;
      if (winner == _Piece.user) {
        _userWins += 1;
        _statusText = 'Bu raundu kazandın!';
      } else {
        _aiWins += 1;
        _statusText = 'Bu raundu AI kazandı.';
      }
    });

    final title = winner == _Piece.user ? 'Tebrikler' : 'Yeni Tur';
    final body = winner == _Piece.user
        ? 'Rakibin piyonlarını dengeleyip oyunu aldın.'
        : 'Bu turu AI kazandı. Hemen bir tur daha dene.';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Devam Et'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    _resetBoard(keepScore: true);
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Hexapawn'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Hexapawn Nasıl Oynanır?',
              rules: [
                'Senin 3 piyonun altta, AI\'ın 3 piyonu üstte başlar.',
                'Piyonlar sadece ileri gider (yukarıya doğru).',
                'Düşman piyonunu çapraz hareketle yiyebilirsin.',
                'Piyonunu karşı tarafa ulaştırırsan kazanırsın!',
                'Rakibin hiç hareket edemezse de kazanırsın.',
              ],
              tip: 'Ortadaki piyonu korumaya çalış!',
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
          ),
          IconButton(
            onPressed: () => _resetBoard(keepScore: false),
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
                  icon: Icons.sports_esports_rounded,
                  title: 'Hexapawn',
                  subtitle: '3x3 mini satrançta piyonlarını akıllı kullan.',
                  accent: Color(0xFF9A95FF),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF9EA8FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'Hexapawn: Martin Gardner tarafından popülerleştirilen, sadece piyonlarla oynanan 3x3 mini satranç.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 10),
                // --- Ayarlar (açılabilir) ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _userPieceColor.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      leading: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: _userPieceColor,
                      ),
                      title: const Text(
                        'Oyun Ayarları',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF394E76),
                        ),
                      ),
                      children: [
                        // -- Taş rengi --
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Taş rengi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7A99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: _pieceColorOptions.map((color) {
                            final isSelected = color == _userPieceColor;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _userPieceColor = color),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: isSelected ? 30 : 24,
                                height: isSelected ? 30 : 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color:
                                                color.withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        // -- Kim başlasın --
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Kim başlasın?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7A99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_userStartsFirst) {
                                    setState(() => _userStartsFirst = true);
                                    _resetBoard(keepScore: true);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _userStartsFirst
                                        ? _userPieceColor
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 16,
                                        color: _userStartsFirst
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ben',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _userStartsFirst
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_userStartsFirst) {
                                    setState(() => _userStartsFirst = false);
                                    _resetBoard(keepScore: true);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_userStartsFirst
                                        ? const Color(0xFFFF8CBC)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.smart_toy_rounded,
                                        size: 16,
                                        color: !_userStartsFirst
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'AI',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: !_userStartsFirst
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isAiThinking
                        ? const Color(0xFFFF5D8D)
                        : const Color(0xFF394E76),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFA9B0FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 9,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final row = index ~/ 3;
                            final col = index % 3;
                            final piece = _board[row][col];
                            final isSelected =
                                _selectedRow == row && _selectedCol == col;
                            final isTarget = _candidateMoves.any(
                              (move) => move.toRow == row && move.toCol == col,
                            );

                            return InkWell(
                              onTap: () => _onCellTap(row, col),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: _cellColor(
                                      row, col, isSelected, isTarget),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF7B88FF)
                                        : Colors.black.withValues(alpha: 0.08),
                                    width: isSelected ? 2.2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: piece != null
                                      ? _PieceToken(
                                          piece: piece,
                                          userColor: _userPieceColor,
                                        )
                                      : (isTarget
                                          ? Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF6ACD95),
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                          : const SizedBox.shrink()),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kurallar: Piyonlar bir adım ileri gider, çapraz alır. Son satıra ulaşan veya rakibi hamlesiz bırakan kazanır.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.indigo.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _cellColor(int row, int col, bool isSelected, bool isTarget) {
    if (isSelected) return const Color(0xFFD5DEFF);
    if (isTarget) return const Color(0xFFDCF7EB);
    final isDark = (row + col).isOdd;
    return isDark ? const Color(0xFFE2E4FF) : const Color(0xFFF8F6FF);
  }
}

class _PieceToken extends StatelessWidget {
  const _PieceToken({required this.piece, this.userColor});

  final _Piece piece;
  final Color? userColor;

  @override
  Widget build(BuildContext context) {
    final isUser = piece == _Piece.user;
    final color = isUser
        ? (userColor ?? const Color(0xFF7D9DFF))
        : const Color(0xFFFF8CBC);
    final icon = isUser ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

enum _Piece { user, ai }

class _HexMove {
  const _HexMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
  });

  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
}
