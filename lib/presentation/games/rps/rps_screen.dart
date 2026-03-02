import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';
import 'logic/rps_predictor.dart';

class RockPaperScissorsScreen extends StatefulWidget {
  const RockPaperScissorsScreen({super.key});

  @override
  State<RockPaperScissorsScreen> createState() =>
      _RockPaperScissorsScreenState();
}

class _RockPaperScissorsScreenState extends State<RockPaperScissorsScreen> {
  String? _userChoice;
  String? _computerChoice;
  String _result = '';
  int _userScore = 0;
  int _computerScore = 0;

  // AI state
  final RPSPredictor _predictor = RPSPredictor();
  final LearningProgressService _progressService = LearningProgressService();
  String? _secondLastUserChoice;
  String? _lastUserChoice;
  int _gameCount = 0;
  bool _isAiReady = false;
  double _aiConfidence = 0;

  final List<String> _choices = ['Taş', 'Kağıt', 'Makas'];
  final Map<String, IconData> _icons = {
    'Taş': Icons.landscape,
    'Kağıt': Icons.note,
    'Makas': Icons.cut,
  };
  final Map<String, Color> _choiceColors = {
    'Taş': const Color(0xFF86B9FF),
    'Kağıt': const Color(0xFF9E9BFF),
    'Makas': const Color(0xFFFF9FD2),
  };

  final Random _random = Random();
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _initializeAi();
  }

  Future<void> _initializeAi() async {
    await _predictor.initialize();
    if (!mounted) return;
    setState(() {
      _isAiReady = true;
      _aiConfidence = _predictor.estimateConfidence();
    });
  }

  void _play(String choice) async {
    setState(() {
      _isThinking = true;
      _userChoice = null;
      _computerChoice = null;
      _result = '';
    });

    // Simulate computer thinking
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    String computerSelection;

    if (_isAiReady) {
      computerSelection = _predictor.chooseComputerMove(
        roundCount: _gameCount,
        lastUserMove: _lastUserChoice,
        secondLastUserMove: _secondLastUserChoice,
      );
    } else {
      computerSelection = _choices[_random.nextInt(_choices.length)];
    }

    // Record every round so the model keeps adapting forever.
    if (_isAiReady) {
      _predictor.recordMove(
        previousMove: _lastUserChoice,
        secondPreviousMove: _secondLastUserChoice,
        currentMove: choice,
      );
    }

    _secondLastUserChoice = _lastUserChoice;
    _lastUserChoice = choice;
    _gameCount++;
    _aiConfidence = _predictor.estimateConfidence(
      lastUserMove: _lastUserChoice,
      secondLastUserMove: _secondLastUserChoice,
    );

    setState(() {
      _isThinking = false;
      _userChoice = choice;
      _computerChoice = computerSelection;
      _result = _determineWinner(choice, computerSelection);

      if (_result == 'Kazandın!') {
        _userScore++;
      } else if (_result == 'Kaybettin!') {
        _computerScore++;
      }
    });

    unawaited(
      _progressService.recordGameSession(
        gameId: 'rps',
        won: _result == 'Kazandın!',
        score: _userScore,
        minutes: 1,
      ),
    );
  }

  String _determineWinner(String user, String computer) {
    if (user == computer) return 'Berabere!';
    if ((user == 'Taş' && computer == 'Makas') ||
        (user == 'Kağıt' && computer == 'Taş') ||
        (user == 'Makas' && computer == 'Kağıt')) {
      return 'Kazandın!';
    }
    return 'Kaybettin!';
  }

  void _resetGame() {
    setState(() {
      _userChoice = null;
      _computerChoice = null;
      _result = '';
      _userScore = 0;
      _computerScore = 0;
      _gameCount = 0;
      _secondLastUserChoice = null;
      _lastUserChoice = null;
      _aiConfidence = _predictor.estimateConfidence();
      // Predictor memory is intentionally preserved across rounds and sessions.
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Taş Kağıt Makas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Taş Kağıt Makas',
              rules: [
                'Taş, makas\'ı yener (kırar).',
                'Makas, kağıdı yener (keser).',
                'Kağıt, taşı yener (sarar).',
                'Aynı seçimi yaparsanız berabere!',
                'AI senin hamlelerini öğrenmeye çalışır.',
              ],
              tip: 'Her zaman aynı şeyi seçme, AI seni tahmin eder!',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
          ),
        ],
      ),
      body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const PlayfulGameHero(
                        icon: Icons.psychology_alt_rounded,
                        title: 'Taş Kağıt Makas',
                        subtitle: 'AI rakibe karşı hızlı turlar oyna.',
                        accent: Color(0xFF8A95FF),
                      ),
                      const SizedBox(height: 12),
                      _buildAiBanner(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildScoreCard('Sen', _userScore)),
                          const SizedBox(width: 10),
                          Expanded(
                            child:
                                _buildScoreCard('Bilgisayar', _computerScore),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (_isThinking)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF95A2FF)
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Bilgisayar düşünüyor...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_userChoice != null &&
                          _computerChoice != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildChoiceDisplay(_userChoice!, 'Sen'),
                            const SizedBox(width: 16),
                            const Text(
                              'VS',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildChoiceDisplay(_computerChoice!, 'Bilgisayar'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _result,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _resultColor(),
                          ),
                        ),
                      ] else
                        const Text(
                          'Bir seçim yap!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: _choices
                            .map((choice) => _buildChoiceButton(choice))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Oyun Sayısı: $_gameCount',
                        style: TextStyle(
                          color: Colors.indigo.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Model Hafızası: ${_predictor.roundsLearned} hamle (kalıcı)',
                        style: TextStyle(
                          color: Colors.indigo.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildScoreCard(String label, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFA9B0FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceDisplay(String choice, String label) {
    final accent = _choiceColors[choice] ?? const Color(0xFF8EA1FF);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
          ),
          child: Icon(_icons[choice], size: 46, color: accent),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildChoiceButton(String choice) {
    final accent = _choiceColors[choice] ?? const Color(0xFF90A0FF);
    return ElevatedButton(
      onPressed: (_isThinking || !_isAiReady) ? null : () => _play(choice),
      style: ElevatedButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.2),
        foregroundColor: accent,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.grey.shade500,
        elevation: 0,
        padding: const EdgeInsets.all(20),
        shape: const CircleBorder(),
        side: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Icon(_icons[choice], size: 32),
    );
  }

  Widget _buildAiBanner() {
    final confidencePercent = (_aiConfidence * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF9BA6FF).withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          if (_isAiReady)
            const Icon(Icons.psychology, color: Color(0xFF7379E8), size: 22)
          else
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isAiReady
                  ? 'Sürekli Öğrenen AI aktif | Güven: %$confidencePercent | Veri: ${_predictor.roundsLearned}'
                  : 'AI hafızası yükleniyor...',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF525FA2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _resultColor() {
    if (_result == 'Kazandın!') return const Color(0xFF34B176);
    if (_result == 'Kaybettin!') return const Color(0xFFFF6A93);
    return const Color(0xFF7A6FE3);
  }
}
