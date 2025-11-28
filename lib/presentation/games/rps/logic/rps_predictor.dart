import 'dart:math';

class RPSPredictor {
  // Stores transitions: Key is "PreviousMove", Value is Map of "NextMove" -> Count
  // Example: {'Taş': {'Kağıt': 5, 'Makas': 2, 'Taş': 1}}
  final Map<String, Map<String, int>> _transitions = {};
  final Random _random = Random();

  void recordMove(String? previousMove, String currentMove) {
    if (previousMove == null) return;

    if (!_transitions.containsKey(previousMove)) {
      _transitions[previousMove] = {};
    }

    final nextMoves = _transitions[previousMove]!;
    nextMoves[currentMove] = (nextMoves[currentMove] ?? 0) + 1;
  }

  String predictNextUserMove(String lastUserMove) {
    if (!_transitions.containsKey(lastUserMove)) {
      return _getRandomMove();
    }

    final nextMoves = _transitions[lastUserMove]!;
    if (nextMoves.isEmpty) {
      return _getRandomMove();
    }

    // Find the move with the highest frequency
    String? likelyMove;
    int maxCount = -1;

    nextMoves.forEach((move, count) {
      if (count > maxCount) {
        maxCount = count;
        likelyMove = move;
      }
    });

    return likelyMove ?? _getRandomMove();
  }

  String getCounterMove(String userMove) {
    switch (userMove) {
      case 'Taş':
        return 'Kağıt';
      case 'Kağıt':
        return 'Makas';
      case 'Makas':
        return 'Taş';
      default:
        return _getRandomMove();
    }
  }

  String _getRandomMove() {
    const choices = ['Taş', 'Kağıt', 'Makas'];
    return choices[_random.nextInt(choices.length)];
  }
}
