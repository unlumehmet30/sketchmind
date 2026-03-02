import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class RPSPredictor {
  static const _storageKey = 'rps_predictor_state_v2';
  static const _recentWindow = 15;
  static const _choices = ['Taş', 'Kağıt', 'Makas'];

  final Map<String, Map<String, int>> _transitions = {};
  final Map<String, Map<String, int>> _pairTransitions = {};
  final Map<String, int> _globalCounts = {};
  final List<String> _recentMoves = [];

  final Random _random = Random();
  bool _isInitialized = false;
  int _roundsLearned = 0;

  bool get isInitialized => _isInitialized;
  int get roundsLearned => _roundsLearned;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final rawState = prefs.getString(_storageKey);
    if (rawState == null || rawState.isEmpty) {
      _isInitialized = true;
      return;
    }

    try {
      final decoded = jsonDecode(rawState);
      if (decoded is! Map<String, dynamic>) {
        _isInitialized = true;
        return;
      }

      _roundsLearned = (decoded['roundsLearned'] as num?)?.toInt() ?? 0;

      _loadNestedMap(decoded['transitions'], _transitions);
      _loadNestedMap(decoded['pairTransitions'], _pairTransitions);
      _loadFlatMap(decoded['globalCounts'], _globalCounts);
      _loadRecentMoves(decoded['recentMoves']);
    } catch (_) {
      _transitions.clear();
      _pairTransitions.clear();
      _globalCounts.clear();
      _recentMoves.clear();
      _roundsLearned = 0;
    }

    _isInitialized = true;
  }

  void recordMove({
    String? previousMove,
    String? secondPreviousMove,
    required String currentMove,
  }) {
    _globalCounts[currentMove] = (_globalCounts[currentMove] ?? 0) + 1;
    _roundsLearned += 1;
    _recentMoves.add(currentMove);
    if (_recentMoves.length > _recentWindow) {
      _recentMoves.removeAt(0);
    }

    if (previousMove != null) {
      final nextMoves = _transitions.putIfAbsent(previousMove, () => {});
      nextMoves[currentMove] = (nextMoves[currentMove] ?? 0) + 1;
    }

    if (secondPreviousMove != null && previousMove != null) {
      final pairKey = _pairKey(secondPreviousMove, previousMove);
      final nextMoves = _pairTransitions.putIfAbsent(pairKey, () => {});
      nextMoves[currentMove] = (nextMoves[currentMove] ?? 0) + 1;
    }

    unawaited(_persistState());
  }

  String chooseComputerMove({
    required int roundCount,
    String? lastUserMove,
    String? secondLastUserMove,
  }) {
    final effectiveRound = max(roundCount, _roundsLearned);
    final explorationRate = _explorationRate(effectiveRound);
    if (_random.nextDouble() < explorationRate) {
      return _getRandomMove();
    }

    final predictedMove = predictNextUserMove(
      lastUserMove: lastUserMove,
      secondLastUserMove: secondLastUserMove,
    );
    return getCounterMove(predictedMove);
  }

  String predictNextUserMove({
    String? lastUserMove,
    String? secondLastUserMove,
  }) {
    final scores = _buildScoreMap(
      lastUserMove: lastUserMove,
      secondLastUserMove: secondLastUserMove,
    );
    return _bestMove(scores);
  }

  double estimateConfidence({
    String? lastUserMove,
    String? secondLastUserMove,
  }) {
    if (_roundsLearned == 0) return 0;
    final scores = _buildScoreMap(
      lastUserMove: lastUserMove,
      secondLastUserMove: secondLastUserMove,
    );
    final values = scores.values.toList()..sort();
    final top = values.last;
    final runnerUp = values.length > 1 ? values[values.length - 2] : 0;
    final margin =
        top <= 0 ? 0 : ((top - runnerUp) / top).clamp(0, 1).toDouble();
    final sampleFactor = (_roundsLearned / 45).clamp(0, 1).toDouble();
    return ((margin * 0.65) + (sampleFactor * 0.35)).clamp(0, 1).toDouble();
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

  Future<void> _persistState() async {
    if (!_isInitialized) return;

    final state = <String, dynamic>{
      'roundsLearned': _roundsLearned,
      'transitions': _transitions,
      'pairTransitions': _pairTransitions,
      'globalCounts': _globalCounts,
      'recentMoves': _recentMoves,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state));
  }

  String _pairKey(String secondPreviousMove, String previousMove) {
    return '$secondPreviousMove>$previousMove';
  }

  void _loadNestedMap(
    Object? rawValue,
    Map<String, Map<String, int>> target,
  ) {
    target.clear();
    if (rawValue is! Map) return;
    for (final entry in rawValue.entries) {
      final parent = entry.key;
      final childMap = entry.value;
      if (parent is! String || childMap is! Map) continue;

      final parsedChild = <String, int>{};
      for (final childEntry in childMap.entries) {
        final key = childEntry.key;
        final value = childEntry.value;
        if (key is String && value is num) {
          parsedChild[key] = value.toInt();
        }
      }
      if (parsedChild.isNotEmpty) {
        target[parent] = parsedChild;
      }
    }
  }

  void _loadFlatMap(Object? rawValue, Map<String, int> target) {
    target.clear();
    if (rawValue is! Map) return;
    for (final entry in rawValue.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is num) {
        target[key] = value.toInt();
      }
    }
  }

  void _loadRecentMoves(Object? rawValue) {
    _recentMoves.clear();
    if (rawValue is! List) return;
    for (final item in rawValue) {
      if (item is String && _choices.contains(item)) {
        _recentMoves.add(item);
      }
    }
    if (_recentMoves.length > _recentWindow) {
      _recentMoves.removeRange(0, _recentMoves.length - _recentWindow);
    }
  }

  Map<String, double> _buildScoreMap({
    String? lastUserMove,
    String? secondLastUserMove,
  }) {
    final scores = <String, double>{
      for (final choice in _choices) choice: 1.0,
    };

    if (secondLastUserMove != null && lastUserMove != null) {
      final pairKey = _pairKey(secondLastUserMove, lastUserMove);
      _applyDistribution(
        scores: scores,
        counts: _pairTransitions[pairKey],
        weight: 0.55,
      );
    }

    if (lastUserMove != null) {
      _applyDistribution(
        scores: scores,
        counts: _transitions[lastUserMove],
        weight: 0.25,
      );
    }

    _applyDistribution(scores: scores, counts: _globalCounts, weight: 0.12);
    _applyRecencyDistribution(scores, 0.08);

    return scores;
  }

  void _applyDistribution({
    required Map<String, double> scores,
    required Map<String, int>? counts,
    required double weight,
  }) {
    if (counts == null || counts.isEmpty) return;
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    for (final choice in _choices) {
      final count = counts[choice] ?? 0;
      scores[choice] = scores[choice]! + (count / total) * weight;
    }
  }

  void _applyRecencyDistribution(Map<String, double> scores, double weight) {
    if (_recentMoves.isEmpty) return;
    final recencyScores = <String, double>{
      for (final choice in _choices) choice: 0,
    };

    double totalWeight = 0;
    for (var index = 0; index < _recentMoves.length; index++) {
      final move = _recentMoves[index];
      final ageWeight = (index + 1).toDouble();
      recencyScores[move] = (recencyScores[move] ?? 0) + ageWeight;
      totalWeight += ageWeight;
    }

    if (totalWeight <= 0) return;
    for (final choice in _choices) {
      final normalized = (recencyScores[choice] ?? 0) / totalWeight;
      scores[choice] = scores[choice]! + (normalized * weight);
    }
  }

  String _bestMove(Map<String, double> scores) {
    var maxScore = -double.infinity;
    final topMoves = <String>[];

    for (final choice in _choices) {
      final score = scores[choice] ?? 0;
      if (score > maxScore + 0.000001) {
        maxScore = score;
        topMoves
          ..clear()
          ..add(choice);
      } else if ((score - maxScore).abs() <= 0.000001) {
        topMoves.add(choice);
      }
    }

    if (topMoves.isEmpty) return _getRandomMove();
    return topMoves[_random.nextInt(topMoves.length)];
  }

  double _explorationRate(int roundCount) {
    final adaptive = 0.38 - (roundCount * 0.012);
    return adaptive.clamp(0.08, 0.38).toDouble();
  }

  String _getRandomMove() {
    return _choices[_random.nextInt(_choices.length)];
  }
}
