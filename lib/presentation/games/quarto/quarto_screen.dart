import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

// ─── Quarto Game Screen ─────────────────────────────────────────────────────

class QuartoScreen extends StatefulWidget {
  const QuartoScreen({super.key});

  @override
  State<QuartoScreen> createState() => _QuartoScreenState();
}

class _QuartoScreenState extends State<QuartoScreen> {
  final Random _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  // Board: 4×4, null = empty, otherwise piece index (0‑15).
  final List<int?> _board = List.filled(16, null);

  // Available pieces (0‑15, each a 4‑bit descriptor).
  final Set<int> _availablePieces = List.generate(16, (i) => i).toSet();

  int? _chosenPiece; // piece chosen for opponent to place
  bool _isUserPlacing = false; // true → user must place _chosenPiece
  bool _isUserChoosing = true; // true → user must choose a piece for AI
  bool _isAiThinking = false;
  bool _isGameOver = false;
  String _statusText = 'AI\'nin yerleştireceği taşı seç.';

  int _userWins = 0;
  int _aiWins = 0;
  int _draws = 0;

  @override
  void initState() {
    super.initState();
  }

  // ─── Game flow ──────────────────────────────────────────────────────────

  void _userChoosesPiece(int piece) {
    if (!_isUserChoosing || _isGameOver || _isAiThinking) return;
    setState(() {
      _chosenPiece = piece;
      _availablePieces.remove(piece);
      _isUserChoosing = false;
      _isAiThinking = true;
      _statusText = 'AI taşı yerleştiriyor…';
    });
    _aiPlaceThenChoose();
  }

  Future<void> _aiPlaceThenChoose() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isGameOver) return;

    // AI places the chosen piece
    final bestCell = _aiBestPlacement(_chosenPiece!);
    setState(() {
      _board[bestCell] = _chosenPiece;
      _chosenPiece = null;
    });

    if (_checkWin(bestCell)) {
      _finishGame(winner: 'AI');
      return;
    }
    if (_availablePieces.isEmpty) {
      _finishGame(winner: null); // draw
      return;
    }

    // AI chooses a piece for the user to place
    final aiChoice = _aiBestChoice();
    setState(() {
      _chosenPiece = aiChoice;
      _availablePieces.remove(aiChoice);
      _isAiThinking = false;
      _isUserPlacing = true;
      _statusText = 'AI bir taş seçti. Tahtaya yerleştir.';
    });
  }

  void _userPlacesPiece(int cell) {
    if (!_isUserPlacing || _isGameOver || _board[cell] != null) return;

    setState(() {
      _board[cell] = _chosenPiece;
      _chosenPiece = null;
      _isUserPlacing = false;
    });

    if (_checkWin(cell)) {
      _finishGame(winner: 'Sen');
      return;
    }
    if (_availablePieces.isEmpty) {
      _finishGame(winner: null);
      return;
    }

    setState(() {
      _isUserChoosing = true;
      _statusText = 'AI\'nin yerleştireceği taşı seç.';
    });
  }

  void _finishGame({String? winner}) {
    unawaited(
      _progressService.recordGameSession(
        gameId: 'quarto',
        won: winner == 'Sen',
        score: winner == 'Sen' ? 100 : (winner == null ? 50 : 30),
        minutes: 3,
      ),
    );

    setState(() {
      _isGameOver = true;
      _isAiThinking = false;
      if (winner == 'Sen') {
        _userWins += 1;
        _statusText = 'Tebrikler, kazandın!';
      } else if (winner == 'AI') {
        _aiWins += 1;
        _statusText = 'AI kazandı. Tekrar dene!';
      } else {
        _draws += 1;
        _statusText = 'Berabere! Harika mücadele.';
      }
    });
  }

  void _restart() {
    setState(() {
      _board.fillRange(0, 16, null);
      _availablePieces
        ..clear()
        ..addAll(List.generate(16, (i) => i));
      _chosenPiece = null;
      _isUserPlacing = false;
      _isUserChoosing = true;
      _isAiThinking = false;
      _isGameOver = false;
      _statusText = 'AI\'nin yerleştireceği taşı seç.';
    });
  }

  // ─── Win check ──────────────────────────────────────────────────────────

  static const _lines = <List<int>>[
    [0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14, 15], // rows
    [0, 4, 8, 12], [1, 5, 9, 13], [2, 6, 10, 14], [3, 7, 11, 15], // cols
    [0, 5, 10, 15], [3, 6, 9, 12], // diags
  ];

  bool _checkWin(int lastCell) {
    for (final line in _lines) {
      if (!line.contains(lastCell)) continue;
      final pieces = <int>[];
      for (final idx in line) {
        if (_board[idx] == null) break;
        pieces.add(_board[idx]!);
      }
      if (pieces.length == 4 && _lineWins(pieces)) return true;
    }
    return false;
  }

  bool _lineWins(List<int> pieces) {
    // For each of the 4 bits, check if ALL pieces share the same value.
    for (var bit = 0; bit < 4; bit++) {
      final mask = 1 << bit;
      final allSet = pieces.every((p) => (p & mask) != 0);
      final allClear = pieces.every((p) => (p & mask) == 0);
      if (allSet || allClear) return true;
    }
    return false;
  }

  bool _boardLineWins(List<int?> board, List<int> line) {
    final pieces = <int>[];
    for (final idx in line) {
      if (board[idx] == null) return false;
      pieces.add(board[idx]!);
    }
    return _lineWins(pieces);
  }

  // ─── AI: placement ─────────────────────────────────────────────────────

  int _aiBestPlacement(int piece) {
    final emptyCells = <int>[];
    for (var i = 0; i < 16; i++) {
      if (_board[i] == null) emptyCells.add(i);
    }

    // Try to win
    for (final cell in emptyCells) {
      _board[cell] = piece;
      final wins = _lines.any((line) =>
          line.contains(cell) && _boardLineWins(_board, line));
      _board[cell] = null;
      if (wins) return cell;
    }

    // Block: avoid cells that let the user win next
    final safeCells = <int>[];
    for (final cell in emptyCells) {
      safeCells.add(cell);
    }

    // Prefer center
    const preference = [5, 6, 9, 10, 0, 3, 12, 15, 1, 2, 4, 7, 8, 11, 13, 14];
    for (final p in preference) {
      if (emptyCells.contains(p)) return p;
    }
    return emptyCells[_random.nextInt(emptyCells.length)];
  }

  // ─── AI: choice ─────────────────────────────────────────────────────────

  int _aiBestChoice() {
    final available = _availablePieces.toList();
    if (available.length <= 1) return available.first;

    // Avoid giving a piece that lets the user win immediately
    final safePieces = <int>[];
    for (final piece in available) {
      var canWin = false;
      for (var cell = 0; cell < 16; cell++) {
        if (_board[cell] != null) continue;
        _board[cell] = piece;
        canWin = _lines.any((line) =>
            line.contains(cell) && _boardLineWins(_board, line));
        _board[cell] = null;
        if (canWin) break;
      }
      if (!canWin) safePieces.add(piece);
    }

    final pool = safePieces.isNotEmpty ? safePieces : available;
    return pool[_random.nextInt(pool.length)];
  }

  // ─── Piece visual helpers ───────────────────────────────────────────────

  // Bit 0 = color (0=light, 1=dark)
  // Bit 1 = height (0=short, 1=tall)
  // Bit 2 = shape (0=round, 1=square)
  // Bit 3 = hole (0=solid, 1=hollow)

  bool _pDark(int p) => (p & 1) != 0;
  bool _pTall(int p) => (p & 2) != 0;
  bool _pSquare(int p) => (p & 4) != 0;
  bool _pHollow(int p) => (p & 8) != 0;

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Quarto'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Quarto Nasıl Oynanır?',
              rules: [
                'Her taşın 4 özelliği var: renk, boy, şekil ve içi dolu/boş.',
                'Sen bir taş seçersin, ama onu AI yerleştirir!',
                'Sonra AI bir taş seçer, sen yerleştirirsin.',
                'Aynı özelliği paylaşan 4 taşı sıraya koyarsan kazanırsın.',
                'Sıra = yatay, dikey veya çapraz olabilir.',
              ],
              tip: 'Rakibine kolay sıra yapacak taş verme!',
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
          ),
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yeniden başla',
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
                  icon: Icons.extension_rounded,
                  title: 'Quarto',
                  subtitle:
                      'Taşı sen seç, rakip yerleştirsin. 4\'lü özellik eşleşmesi kazanır.',
                  accent: Color(0xFFD4A5FF),
                ),
                const SizedBox(height: 10),
                // Stat chips
                Row(
                  children: [
                    PlayfulStatChip(
                      label: 'Sen',
                      value: '$_userWins',
                      accent: const Color(0xFF759BFF),
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(width: 8),
                    PlayfulStatChip(
                      label: 'AI',
                      value: '$_aiWins',
                      accent: const Color(0xFFFF82BE),
                      icon: Icons.smart_toy_rounded,
                    ),
                    const SizedBox(width: 8),
                    PlayfulStatChip(
                      label: 'Berabere',
                      value: '$_draws',
                      accent: const Color(0xFFB0B0B0),
                      icon: Icons.handshake_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Status + chosen piece
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (_chosenPiece != null && _isUserPlacing) ...[
                        _buildPieceWidget(_chosenPiece!, size: 32),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isAiThinking
                                ? const Color(0xFFFF5D8D)
                                : const Color(0xFF394E76),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 4×4 Board
                Expanded(
                  flex: 3,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFD4A5FF).withValues(alpha: 0.3),
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
                            final piece = _board[index];
                            return GestureDetector(
                              onTap: () => _userPlacesPiece(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: piece != null
                                      ? const Color(0xFFF0ECFF)
                                      : (_isUserPlacing
                                          ? const Color(0xFFE8FFE8)
                                          : const Color(0xFFF8F6FF)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isUserPlacing && piece == null
                                        ? const Color(0xFF6ACD95)
                                            .withValues(alpha: 0.6)
                                        : Colors.black
                                            .withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Center(
                                  child: piece != null
                                      ? _buildPieceWidget(piece, size: 36)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Piece pool label
                Text(
                  _isUserChoosing ? 'Bir taş seç →' : 'Kalan taşlar',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7A99),
                  ),
                ),
                const SizedBox(height: 6),
                // Piece pool
                SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _availablePieces.map((piece) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _userChoosesPiece(piece),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 50,
                            decoration: BoxDecoration(
                              color: _isUserChoosing
                                  ? const Color(0xFFFFF4E8)
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isUserChoosing
                                    ? const Color(0xFFFFB95C)
                                        .withValues(alpha: 0.5)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Center(
                              child: _buildPieceWidget(piece, size: 30),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Game-over restart button
                if (_isGameOver) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay),
                    label: const Text('Yeni Oyun'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: const Color(0xFFD4A5FF),
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

  // ─── Piece widget ───────────────────────────────────────────────────────

  Widget _buildPieceWidget(int piece, {double size = 32}) {
    final isDark = _pDark(piece);
    final isTall = _pTall(piece);
    final isSquare = _pSquare(piece);
    final isHollow = _pHollow(piece);

    final color = isDark ? const Color(0xFF6A5ACD) : const Color(0xFFFFA07A);
    final height = isTall ? size : size * 0.65;
    final borderRadius = isSquare ? 4.0 : size;

    return Container(
      width: size * 0.7,
      height: height,
      decoration: BoxDecoration(
        color: isHollow ? Colors.transparent : color,
        border: Border.all(color: color, width: isHollow ? 3 : 1.5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
