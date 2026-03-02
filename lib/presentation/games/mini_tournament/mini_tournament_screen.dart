import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

class MiniTournamentScreen extends StatefulWidget {
  const MiniTournamentScreen({super.key});

  @override
  State<MiniTournamentScreen> createState() => _MiniTournamentScreenState();
}

class _MiniTournamentScreenState extends State<MiniTournamentScreen> {
  static const _totalRounds = 6;

  final Random _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  int _round = 1;
  int _score = 0;
  int _wins = 0;
  bool _isFinished = false;
  bool _isMemoryReveal = false;
  bool _sessionSaved = false;
  String _statusText = 'Turnuva başladı!';
  _TournamentChallenge? _challenge;
  Timer? _memoryTimer;

  @override
  void initState() {
    super.initState();
    _nextChallenge();
  }

  @override
  void dispose() {
    _memoryTimer?.cancel();
    super.dispose();
  }

  void _nextChallenge() {
    _memoryTimer?.cancel();

    final type =
        _ChallengeType.values[_random.nextInt(_ChallengeType.values.length)];
    if (type == _ChallengeType.rps) {
      _challenge = _buildRpsChallenge();
      _isMemoryReveal = false;
    } else if (type == _ChallengeType.math) {
      _challenge = _buildMathChallenge();
      _isMemoryReveal = false;
    } else {
      _challenge = _buildMemoryChallenge();
      _isMemoryReveal = true;
      _memoryTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted || _isFinished) return;
        setState(() {
          _isMemoryReveal = false;
        });
      });
    }
    setState(() {});
  }

  _TournamentChallenge _buildRpsChallenge() {
    const moves = ['Taş', 'Kağıt', 'Makas'];
    final aiMove = moves[_random.nextInt(moves.length)];
    return _TournamentChallenge(
      type: _ChallengeType.rps,
      title: 'RPS Duel',
      prompt: 'Hamleni seç. AI hamlesini aynı anda yapacak.',
      options: moves,
      correctAnswer: aiMove,
    );
  }

  _TournamentChallenge _buildMathChallenge() {
    final a = _random.nextInt(35) + 5;
    final b = _random.nextInt(35) + 5;
    final operator = _random.nextInt(3);

    late int answer;
    late String prompt;
    if (operator == 0) {
      answer = a + b;
      prompt = '$a + $b = ?';
    } else if (operator == 1) {
      final high = max(a, b);
      final low = min(a, b);
      answer = high - low;
      prompt = '$high - $low = ?';
    } else {
      final x = _random.nextInt(10) + 2;
      final y = _random.nextInt(10) + 2;
      answer = x * y;
      prompt = '$x x $y = ?';
    }

    final options = <int>{answer};
    while (options.length < 4) {
      options.add(max(0, answer + (_random.nextInt(16) - 8)));
    }

    final mixed = options.map((e) => '$e').toList()..shuffle(_random);
    return _TournamentChallenge(
      type: _ChallengeType.math,
      title: 'Matematik Sprint',
      prompt: prompt,
      options: mixed,
      correctAnswer: '$answer',
    );
  }

  _TournamentChallenge _buildMemoryChallenge() {
    const symbols = ['🌟', '🚀', '🐯', '🎈', '⚽', '🍓', '🎵', '🧩'];
    final sequence = List<String>.generate(
      4,
      (_) => symbols[_random.nextInt(symbols.length)],
    );
    final askIndex = _random.nextInt(sequence.length);
    final correct = sequence[askIndex];

    final options = <String>{correct};
    while (options.length < 4) {
      options.add(symbols[_random.nextInt(symbols.length)]);
    }
    final mixed = options.toList()..shuffle(_random);

    return _TournamentChallenge(
      type: _ChallengeType.memory,
      title: 'Hafıza Blitz',
      prompt: '${askIndex + 1}. sembol hangisiydi?',
      options: mixed,
      correctAnswer: correct,
      memorySequence: sequence,
    );
  }

  void _onAnswer(String answer) {
    if (_challenge == null) return;

    final challenge = _challenge!;
    var isCorrect = false;

    if (challenge.type == _ChallengeType.rps) {
      isCorrect = _evaluateRpsResult(
              userMove: answer, aiMove: challenge.correctAnswer) >=
          0;
      final result =
          _evaluateRpsResult(userMove: answer, aiMove: challenge.correctAnswer);
      if (result > 0) {
        _score += 12;
        _wins += 1;
        _statusText = 'Kazandın! AI: ${challenge.correctAnswer}';
      } else if (result == 0) {
        _score += 5;
        _statusText = 'Berabere! AI: ${challenge.correctAnswer}';
      } else {
        _statusText = 'Bu turu kaybettin. AI: ${challenge.correctAnswer}';
      }
    } else if (challenge.type == _ChallengeType.math) {
      isCorrect = answer == challenge.correctAnswer;
      if (isCorrect) {
        _score += 15;
        _wins += 1;
        _statusText = 'Doğru cevap!';
      } else {
        _statusText = 'Yanlış. Doğru: ${challenge.correctAnswer}';
      }
    } else {
      isCorrect = answer == challenge.correctAnswer;
      if (isCorrect) {
        _score += 14;
        _wins += 1;
        _statusText = 'Hafıza puanı!';
      } else {
        _statusText = 'Kaçırdı. Doğru: ${challenge.correctAnswer}';
      }
    }

    if (!isCorrect && challenge.type == _ChallengeType.rps) {
      _score += 1;
    }

    if (_round >= _totalRounds) {
      _finishTournament();
      return;
    }

    setState(() {
      _round += 1;
    });

    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (!mounted || _isFinished) return;
      _nextChallenge();
    });
  }

  int _evaluateRpsResult({required String userMove, required String aiMove}) {
    if (userMove == aiMove) return 0;
    final win = (userMove == 'Taş' && aiMove == 'Makas') ||
        (userMove == 'Kağıt' && aiMove == 'Taş') ||
        (userMove == 'Makas' && aiMove == 'Kağıt');
    return win ? 1 : -1;
  }

  void _finishTournament() {
    _memoryTimer?.cancel();
    setState(() {
      _isFinished = true;
      _isMemoryReveal = false;
    });
    _saveTournamentIfNeeded();
  }

  Future<void> _saveTournamentIfNeeded() async {
    if (_sessionSaved) return;
    _sessionSaved = true;
    final won = _score >= 56;
    await _progressService.recordTournamentResult(
      totalScore: _score,
      won: won,
      minutes: 7,
    );
  }

  void _restart() {
    setState(() {
      _round = 1;
      _score = 0;
      _wins = 0;
      _isFinished = false;
      _isMemoryReveal = false;
      _sessionSaved = false;
      _statusText = 'Yeni turnuva başladı!';
    });
    _nextChallenge();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _round / _totalRounds;
    final challenge = _challenge;

    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Mini Turnuva'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Mini Turnuva',
              rules: [
                'Farklı mini oyunlardan oluşan bir challenge serisi.',
                'Her turda farklı bir görev karşına çıkar.',
                'Doğru cevaplar puan kazandırır.',
                'Tüm turları tamamlayınca sonucunu görürsün.',
                'En yüksek skoru hedefle!',
              ],
              tip: 'Acele etme, her soruyu dikkatle oku!',
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
          ),
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: _isFinished
                ? _buildResult()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PlayfulGameHero(
                        icon: Icons.emoji_events_rounded,
                        title: 'Mini Turnuva',
                        subtitle:
                            'RPS, matematik ve hafıza mini challenge serisi.',
                        accent: Color(0xFFA18EFF),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          PlayfulStatChip(
                            label: 'Tur',
                            value: '$_round/$_totalRounds',
                            accent: const Color(0xFF738BFF),
                            icon: Icons.flag_rounded,
                          ),
                          const SizedBox(width: 10),
                          PlayfulStatChip(
                            label: 'Skor',
                            value: '$_score',
                            accent: const Color(0xFFFF86C4),
                            icon: Icons.stars_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 11,
                          backgroundColor: Colors.white.withValues(alpha: 0.55),
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF8997FF)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (challenge != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF9FB2FF),
                                Color(0xFFA896FF),
                                Color(0xFFFF9FCC),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                challenge.title,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                challenge.prompt,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _statusText,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (challenge?.type == _ChallengeType.memory &&
                          _isMemoryReveal &&
                          challenge?.memorySequence != null)
                        _buildMemoryReveal(challenge!.memorySequence!)
                      else if (challenge != null)
                        ...challenge.options.map(
                          (option) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ElevatedButton(
                              onPressed: () => _onAnswer(option),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 54),
                                backgroundColor: const Color(0xFFA2ABFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                option,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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

  Widget _buildMemoryReveal(List<String> sequence) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.8),
        border:
            Border.all(color: const Color(0xFFFFB0D8).withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          const Text(
            'Diziyi hatırla',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A61CC),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: sequence
                .map((item) => Text(item, style: const TextStyle(fontSize: 32)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final won = _score >= 56;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          won ? Icons.emoji_events : Icons.sports_score,
          size: 96,
          color: won ? const Color(0xFFFFB95C) : const Color(0xFF7891D6),
        ),
        const SizedBox(height: 10),
        Text(
          won ? 'Kupa Senin!' : 'Turnuva Tamamlandı',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Toplam Skor: $_score',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        Text(
          'Kazanılan Tur: $_wins/$_totalRounds',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.indigo.shade400,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.replay),
          label: const Text('Yeni Turnuva'),
        ),
      ],
    );
  }
}

enum _ChallengeType { rps, math, memory }

class _TournamentChallenge {
  const _TournamentChallenge({
    required this.type,
    required this.title,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    this.memorySequence,
  });

  final _ChallengeType type;
  final String title;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final List<String>? memorySequence;
}
