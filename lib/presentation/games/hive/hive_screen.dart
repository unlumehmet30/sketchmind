import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

// ─── Hive Game Screen ───────────────────────────────────────────────────────

enum _BugType { bee, ant, spider }
enum _HivePlayer { user, ai }

class _HivePiece {
  const _HivePiece({required this.owner, required this.type});
  final _HivePlayer owner;
  final _BugType type;
}

/// Axial coordinate (q, r) for hex grid.
class _Hex {
  const _Hex(this.q, this.r);
  final int q;
  final int r;

  @override
  bool operator ==(Object other) =>
      other is _Hex && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);

  /// The 6 axial neighbors.
  static const _dirs = [
    [1, 0], [-1, 0], [0, 1], [0, -1], [1, -1], [-1, 1],
  ];

  List<_Hex> neighbors() =>
      _dirs.map((d) => _Hex(q + d[0], r + d[1])).toList();
}

class HiveScreen extends StatefulWidget {
  const HiveScreen({super.key});

  @override
  State<HiveScreen> createState() => _HiveScreenState();
}

class _HiveScreenState extends State<HiveScreen> {
  final Random _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  // Board: hex → piece (single layer for simplicity)
  final Map<_Hex, _HivePiece> _board = {};

  // Hands
  late Map<_BugType, int> _userHand;
  late Map<_BugType, int> _aiHand;

  // Turn tracking handled by board state
  bool _isUserTurn = true;
  bool _isAiThinking = false;
  bool _isGameOver = false;
  String _statusText = 'Bir böcek yerleştir.';

  int _userWins = 0;
  int _aiWins = 0;

  _Hex? _selectedHex; // selected piece on board to move
  _BugType? _selectedHandBug; // selected piece from hand
  Set<_Hex> _validTargets = {};

  @override
  void initState() {
    super.initState();
    _resetGame(keepScore: true);
  }

  void _resetGame({required bool keepScore}) {
    setState(() {
      _board.clear();
      _userHand = {_BugType.bee: 1, _BugType.ant: 2, _BugType.spider: 2};
      _aiHand = {_BugType.bee: 1, _BugType.ant: 2, _BugType.spider: 2};
      _isUserTurn = true;
      _isAiThinking = false;
      _isGameOver = false;
      _selectedHex = null;
      _selectedHandBug = null;
      _validTargets = {};
      if (!keepScore) {
        _userWins = 0;
        _aiWins = 0;
      }
      _statusText = 'Bir böcek yerleştir.';
    });
  }

  // ─── One Hive Rule (BFS connectivity) ──────────────────────────────────

  bool _isConnectedWithout(_Hex excluded) {
    final remaining = _board.keys.where((h) => h != excluded).toSet();
    if (remaining.isEmpty) return true;

    final visited = <_Hex>{};
    final queue = Queue<_Hex>()..add(remaining.first);
    visited.add(remaining.first);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final n in current.neighbors()) {
        if (remaining.contains(n) && !visited.contains(n)) {
          visited.add(n);
          queue.add(n);
        }
      }
    }
    return visited.length == remaining.length;
  }

  // ─── Placement targets ─────────────────────────────────────────────────

  Set<_Hex> _placementTargets(_HivePlayer player) {
    if (_board.isEmpty) return {const _Hex(0, 0)};
    if (_board.length == 1) {
      // Second piece: any neighbor of first piece
      return _board.keys.first.neighbors().toSet();
    }

    final candidates = <_Hex>{};
    for (final hex in _board.keys) {
      for (final n in hex.neighbors()) {
        if (!_board.containsKey(n)) candidates.add(n);
      }
    }

    // Must only touch own pieces, not opponent's
    return candidates.where((hex) {
      var touchesOwn = false;
      var touchesEnemy = false;
      for (final n in hex.neighbors()) {
        final piece = _board[n];
        if (piece == null) continue;
        if (piece.owner == player) {
          touchesOwn = true;
        } else {
          touchesEnemy = true;
        }
      }
      return touchesOwn && !touchesEnemy;
    }).toSet();
  }

  // ─── Movement targets ──────────────────────────────────────────────────

  Set<_Hex> _movementTargets(_Hex from) {
    final piece = _board[from];
    if (piece == null) return {};
    if (!_isConnectedWithout(from)) return {};

    switch (piece.type) {
      case _BugType.bee:
        return _beeMovement(from);
      case _BugType.ant:
        return _antMovement(from);
      case _BugType.spider:
        return _spiderMovement(from);
    }
  }

  Set<_Hex> _beeMovement(_Hex from) {
    // 1 step to an adjacent empty hex that is still touching the hive
    final result = <_Hex>{};
    for (final n in from.neighbors()) {
      if (_board.containsKey(n)) continue;
      // Must slide: at least one common neighbor of from & n must be occupied,
      // and the other common neighbor must be empty (sliding gap).
      if (_canSlide(from, n)) {
        // Must still be connected to hive
        final touchesHive = n.neighbors().any(
            (nn) => _board.containsKey(nn) && nn != from);
        if (touchesHive) result.add(n);
      }
    }
    return result;
  }

  bool _canSlide(_Hex from, _Hex to) {
    // Common neighbors of from and to
    final fromN = from.neighbors().toSet();
    final toN = to.neighbors().toSet();
    final common = fromN.intersection(toN);

    var occupiedCommon = 0;
    for (final c in common) {
      if (_board.containsKey(c)) occupiedCommon++;
    }
    // Can slide if not both common neighbors are occupied (gateway)
    return occupiedCommon < 2;
  }

  Set<_Hex> _antMovement(_Hex from) {
    // Unlimited sliding along the hive edge
    final result = <_Hex>{};
    final visited = <_Hex>{from};
    final queue = Queue<_Hex>();

    for (final n in from.neighbors()) {
      if (!_board.containsKey(n) && _canSlide(from, n)) {
        final touchesHive =
            n.neighbors().any((nn) => _board.containsKey(nn) && nn != from);
        if (touchesHive) {
          queue.add(n);
          visited.add(n);
          result.add(n);
        }
      }
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final n in current.neighbors()) {
        if (visited.contains(n) || _board.containsKey(n)) continue;
        if (!_canSlide(current, n)) continue;
        final touchesHive = n.neighbors()
            .any((nn) => _board.containsKey(nn) && nn != from);
        if (touchesHive) {
          visited.add(n);
          result.add(n);
          queue.add(n);
        }
      }
    }
    return result;
  }

  Set<_Hex> _spiderMovement(_Hex from) {
    // Exactly 3 steps sliding
    var frontier = <List<_Hex>>[
      [from]
    ];

    for (var step = 0; step < 3; step++) {
      final nextFrontier = <List<_Hex>>[];
      for (final path in frontier) {
        final current = path.last;
        for (final n in current.neighbors()) {
          if (path.contains(n) || _board.containsKey(n)) continue;
          if (!_canSlide(current, n)) continue;
          final touchesHive = n.neighbors()
              .any((nn) => _board.containsKey(nn) && nn != from);
          if (touchesHive) {
            nextFrontier.add([...path, n]);
          }
        }
      }
      frontier = nextFrontier;
    }

    return frontier.map((path) => path.last).toSet();
  }

  // ─── Must place bee by turn 4 ──────────────────────────────────────────

  bool _mustPlaceBee(_HivePlayer player) {
    final hand = player == _HivePlayer.user ? _userHand : _aiHand;
    if ((hand[_BugType.bee] ?? 0) == 0) return false;
    // Count this player's turns
    final playerTurnsSoFar = _board.values
        .where((p) => p.owner == player)
        .length;
    return playerTurnsSoFar >= 3;
  }

  bool _hasBeeOnBoard(_HivePlayer player) {
    return _board.values.any((p) => p.owner == player && p.type == _BugType.bee);
  }

  // ─── Win check ─────────────────────────────────────────────────────────

  _HivePlayer? _checkWinner() {
    for (final entry in _board.entries) {
      if (entry.value.type != _BugType.bee) continue;
      final surrounded =
          entry.key.neighbors().every((n) => _board.containsKey(n));
      if (surrounded) {
        return entry.value.owner == _HivePlayer.user
            ? _HivePlayer.ai
            : _HivePlayer.user;
      }
    }
    return null;
  }

  // ─── User interaction ───────────────────────────────────────────────────

  void _onHandTap(_BugType type) {
    if (!_isUserTurn || _isGameOver || _isAiThinking) return;
    if ((_userHand[type] ?? 0) <= 0) return;
    if (_mustPlaceBee(_HivePlayer.user) && type != _BugType.bee) {
      setState(() => _statusText = 'Arını yerleştirmelisin!');
      return;
    }

    setState(() {
      _selectedHex = null;
      _selectedHandBug = type;
      _validTargets = _placementTargets(_HivePlayer.user);
      _statusText = _validTargets.isEmpty
          ? 'Yerleştirecek yer yok!'
          : '${_bugLabel(type)} nereye yerleştirilsin?';
    });
  }

  void _onBoardTap(_Hex hex) {
    if (!_isUserTurn || _isGameOver || _isAiThinking) return;

    // Placing from hand
    if (_selectedHandBug != null) {
      if (!_validTargets.contains(hex)) return;

      setState(() {
        _board[hex] = _HivePiece(owner: _HivePlayer.user, type: _selectedHandBug!);
        _userHand[_selectedHandBug!] = (_userHand[_selectedHandBug!] ?? 1) - 1;
        _selectedHandBug = null;
        _validTargets = {};
      });

      _endUserTurn();
      return;
    }

    // Select a piece from board to move
    if (_board.containsKey(hex) && _board[hex]!.owner == _HivePlayer.user) {
      if (!_hasBeeOnBoard(_HivePlayer.user)) {
        setState(() => _statusText = 'Arın yerleştirilmeden hareket edemezsin!');
        return;
      }
      final targets = _movementTargets(hex);
      setState(() {
        _selectedHex = hex;
        _selectedHandBug = null;
        _validTargets = targets;
        _statusText = targets.isEmpty
            ? 'Bu böcek hareket edemiyor!'
            : 'Nereye hareket etsin?';
      });
      return;
    }

    // Moving selected piece
    if (_selectedHex != null && _validTargets.contains(hex)) {
      final piece = _board.remove(_selectedHex!);
      setState(() {
        _board[hex] = piece!;
        _selectedHex = null;
        _validTargets = {};
      });

      _endUserTurn();
    }
  }

  void _endUserTurn() {
    final winner = _checkWinner();
    if (winner != null) {
      _finishGame(winner);
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

    // Placement phase: place from hand
    final placements = _placementTargets(_HivePlayer.ai);
    final mustBee = _mustPlaceBee(_HivePlayer.ai);

    // Try to place
    if (placements.isNotEmpty) {
      final placeable = <_BugType>[];
      for (final entry in _aiHand.entries) {
        if (entry.value > 0) {
          if (mustBee && entry.key != _BugType.bee) continue;
          placeable.add(entry.key);
        }
      }

      if (placeable.isNotEmpty) {
        final bugType = placeable[_random.nextInt(placeable.length)];
        final target = placements.elementAt(_random.nextInt(placements.length));

        setState(() {
          _board[target] = _HivePiece(owner: _HivePlayer.ai, type: bugType);
          _aiHand[bugType] = (_aiHand[bugType] ?? 1) - 1;
        });

        final winner = _checkWinner();
        if (winner != null) {
          _finishGame(winner);
          return;
        }

        setState(() {
          _isUserTurn = true;
          _isAiThinking = false;
          _statusText = 'Sıra sende.';
        });
        return;
      }
    }

    // Movement phase: try to move a piece
    if (_hasBeeOnBoard(_HivePlayer.ai)) {
      final aiPieces = _board.entries
          .where((e) => e.value.owner == _HivePlayer.ai)
          .toList()
        ..shuffle(_random);

      for (final entry in aiPieces) {
        final targets = _movementTargets(entry.key);
        if (targets.isNotEmpty) {
          final target = targets.elementAt(_random.nextInt(targets.length));
          final piece = _board.remove(entry.key);
          setState(() {
            _board[target] = piece!;
          });

          final winner = _checkWinner();
          if (winner != null) {
            _finishGame(winner);
            return;
          }

          break;
        }
      }
    }

    setState(() {
      _isUserTurn = true;
      _isAiThinking = false;
      _statusText = 'Sıra sende.';
    });
  }

  void _finishGame(_HivePlayer winner) {
    unawaited(
      _progressService.recordGameSession(
        gameId: 'hive',
        won: winner == _HivePlayer.user,
        score: winner == _HivePlayer.user ? 100 : 30,
        minutes: 5,
      ),
    );

    setState(() {
      _isGameOver = true;
      _isAiThinking = false;
      if (winner == _HivePlayer.user) {
        _userWins += 1;
        _statusText = 'Arıyı sardın, kazandın!';
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
        title: const Text('Hive'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Hive Nasıl Oynanır?',
              rules: [
                'Elindeki böcekleri tahtaya koy veya tahtadaki böceğini hareket ettir.',
                'Yeni böcek sadece kendi böceklerine değecek şekilde konabilir.',
                'Arı: 1 adım gider. Karınca: sınırsız kayar. Örümcek: tam 3 adım.',
                'Kovanı asla ikiye bölemezsin (One Hive kuralı)!',
                'Rakibin arısını 6 taraftan sararsan kazanırsın!',
              ],
              tip: 'Arını erken koy ama güvende tut!',
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PlayfulGameHero(
                  icon: Icons.hexagon_rounded,
                  title: 'Hive',
                  subtitle:
                      'Rakip arıyı sar. Kovanı bölme!',
                  accent: Color(0xFFFBC87A),
                ),
                const SizedBox(height: 8),
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
                  ],
                ),
                const SizedBox(height: 6),
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
                // Hand
                if (!_isGameOver)
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const Text(
                          'Elde:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7A99),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ..._BugType.values.map((type) {
                          final count = _userHand[type] ?? 0;
                          if (count <= 0) return const SizedBox.shrink();
                          final isSelected = _selectedHandBug == type;
                          return GestureDetector(
                            onTap: () => _onHandTap(type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF3D0)
                                    : Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFBC87A)
                                      : Colors.black.withValues(alpha: 0.06),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_bugIcon(type), size: 18,
                                      color: const Color(0xFF759BFF)),
                                  Text(
                                    '×$count',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                // Hex board rendered as offset grid
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFBC87A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _buildHexBoard(constraints);
                        },
                      ),
                    ),
                  ),
                ),
                if (_isGameOver) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _resetGame(keepScore: true),
                    icon: const Icon(Icons.replay),
                    label: const Text('Yeni Oyun'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      backgroundColor: const Color(0xFFFBC87A),
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

  Widget _buildHexBoard(BoxConstraints constraints) {
    // Determine visible range based on board contents + padding
    final allHexes = <_Hex>{..._board.keys, ..._validTargets};
    if (allHexes.isEmpty) allHexes.add(const _Hex(0, 0));

    // Add some padding around visible hexes
    final padded = <_Hex>{};
    for (final h in allHexes) {
      padded.add(h);
      padded.addAll(h.neighbors());
    }
    // Also add neighbors of board pieces for placement targets
    for (final h in _board.keys) {
      for (final n in h.neighbors()) {
        padded.add(n);
        padded.addAll(n.neighbors());
      }
    }

    final minQ = padded.map((h) => h.q).reduce(min) - 1;
    final maxQ = padded.map((h) => h.q).reduce(max) + 1;
    final minR = padded.map((h) => h.r).reduce(min) - 1;
    final maxR = padded.map((h) => h.r).reduce(max) + 1;

    final cols = maxQ - minQ + 1;
    final rows = maxR - minR + 1;

    // Hex cell size to fit
    final hexW = (constraints.maxWidth - 8) / (cols + 0.5);
    final hexH = (constraints.maxHeight - 8) / (rows * 0.86 + 0.5);
    final cellSize = min(hexW, hexH).clamp(20.0, 48.0);

    return SingleChildScrollView(
      child: SizedBox(
        width: (cols + 0.5) * cellSize,
        height: (rows * 0.86 + 0.5) * cellSize,
        child: Stack(
          children: [
            for (var r = minR; r <= maxR; r++)
              for (var q = minQ; q <= maxQ; q++)
                _buildHexCell(
                  _Hex(q, r),
                  cellSize,
                  q - minQ,
                  r - minR,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildHexCell(_Hex hex, double size, int col, int row) {
    // Offset coordinates: odd rows shift right
    final x = col * size + (row.isOdd ? size * 0.5 : 0);
    final y = row * size * 0.86;

    final piece = _board[hex];
    final isTarget = _validTargets.contains(hex);
    final isSelected = _selectedHex == hex;
    final isEmpty = piece == null && !isTarget;

    // Don't render truly empty cells with no context
    if (isEmpty &&
        !hex.neighbors().any((n) =>
            _board.containsKey(n) || _validTargets.contains(n))) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    if (isSelected) {
      bgColor = const Color(0xFFD0E8FF);
    } else if (isTarget) {
      bgColor = const Color(0xFFDCF7EB);
    } else if (piece != null) {
      bgColor = piece.owner == _HivePlayer.user
          ? const Color(0xFFE0ECFF)
          : const Color(0xFFFFE0EC);
    } else {
      bgColor = const Color(0xFFF8F6FF);
    }

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () => _onBoardTap(hex),
        child: Container(
          width: size - 2,
          height: size - 2,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF759BFF)
                  : isTarget
                      ? const Color(0xFF6ACD95)
                      : Colors.black.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: piece != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _bugIcon(piece.type),
                        size: size * 0.38,
                        color: piece.owner == _HivePlayer.user
                            ? const Color(0xFF759BFF)
                            : const Color(0xFFFF82BE),
                      ),
                      Text(
                        _bugLetter(piece.type),
                        style: TextStyle(
                          fontSize: size * 0.2,
                          fontWeight: FontWeight.w800,
                          color: piece.owner == _HivePlayer.user
                              ? const Color(0xFF759BFF)
                              : const Color(0xFFFF82BE),
                        ),
                      ),
                    ],
                  )
                : isTarget
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6ACD95),
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  IconData _bugIcon(_BugType type) {
    switch (type) {
      case _BugType.bee:
        return Icons.emoji_nature_rounded;
      case _BugType.ant:
        return Icons.bug_report_rounded;
      case _BugType.spider:
        return Icons.pest_control_rounded;
    }
  }

  String _bugLabel(_BugType type) {
    switch (type) {
      case _BugType.bee:
        return 'Arı';
      case _BugType.ant:
        return 'Karınca';
      case _BugType.spider:
        return 'Örümcek';
    }
  }

  String _bugLetter(_BugType type) {
    switch (type) {
      case _BugType.bee:
        return 'A';
      case _BugType.ant:
        return 'K';
      case _BugType.spider:
        return 'Ö';
    }
  }
}
