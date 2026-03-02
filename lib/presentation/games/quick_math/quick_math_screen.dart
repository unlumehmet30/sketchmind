import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/services/learning_progress_service.dart';
import '../widgets/playful_game_chrome.dart';

class QuickMathScreen extends StatefulWidget {
  const QuickMathScreen({super.key});

  @override
  State<QuickMathScreen> createState() => _QuickMathScreenState();
}

class _QuickMathScreenState extends State<QuickMathScreen> {
  final _random = Random();
  final LearningProgressService _progressService = LearningProgressService();

  int _round = 1;
  int _score = 0;
  int _timeLeft = 15;
  int _correctCount = 0;
  int _difficultyLevel = 1;
  int _correctStreak = 0;
  int _wrongStreak = 0;
  bool _isReady = false;
  bool _sessionSaved = false;
  DateTime _sessionStartedAt = DateTime.now();

  late String _question;
  late int _correctAnswer;
  late List<int> _choices;
  _MathOperation _currentOperation = _MathOperation.add;
  int _firstOperand = 0;
  int _secondOperand = 0;
  int _hintStep = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    final level = await _progressService.getQuickMathLevel();
    if (!mounted) return;

    setState(() {
      _difficultyLevel = level.clamp(1, 5);
      _sessionStartedAt = DateTime.now();
      _isReady = true;
    });
    _createQuestion();
    _startTimer();
  }

  int get _roundSeconds {
    final computed = 16 - ((_difficultyLevel - 1) * 2);
    return computed.clamp(8, 16);
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _roundSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft <= 1) {
        timer.cancel();
        _nextRound();
        return;
      }
      setState(() => _timeLeft -= 1);
    });
  }

  void _createQuestion() {
    final maxBase = 20 + ((_difficultyLevel - 1) * 12);
    final a = _random.nextInt(maxBase) + 1;
    final b = _random.nextInt(maxBase) + 1;
    final operator =
        _difficultyLevel >= 4 ? _random.nextInt(4) : _random.nextInt(3);

    late int answer;
    late String prompt;

    if (operator == 0) {
      answer = a + b;
      prompt = '$a + $b = ?';
      _currentOperation = _MathOperation.add;
      _firstOperand = a;
      _secondOperand = b;
    } else if (operator == 1) {
      final maxValue = max(a, b);
      final minValue = min(a, b);
      answer = maxValue - minValue;
      prompt = '$maxValue - $minValue = ?';
      _currentOperation = _MathOperation.subtract;
      _firstOperand = maxValue;
      _secondOperand = minValue;
    } else if (operator == 2) {
      final m1 = _random.nextInt(10) + 1;
      final m2 = _random.nextInt(10) + 1;
      final multiplier = max(1, _difficultyLevel - 2);
      answer = (m1 + multiplier) * (m2 + multiplier);
      prompt = '${m1 + multiplier} x ${m2 + multiplier} = ?';
      _currentOperation = _MathOperation.multiply;
      _firstOperand = m1 + multiplier;
      _secondOperand = m2 + multiplier;
    } else {
      final divisor = _random.nextInt(8) + 2;
      final quotient = _random.nextInt(10 + (_difficultyLevel * 2)) + 1;
      final dividend = divisor * quotient;
      answer = quotient;
      prompt = '$dividend / $divisor = ?';
      _currentOperation = _MathOperation.divide;
      _firstOperand = dividend;
      _secondOperand = divisor;
    }

    final options = <int>{answer};
    while (options.length < 4) {
      final drift = _random.nextInt(8 + (_difficultyLevel * 4)) -
          (4 + (_difficultyLevel * 2));
      options.add(max(0, answer + drift));
    }

    final mixed = options.toList()..shuffle(_random);

    setState(() {
      _correctAnswer = answer;
      _question = prompt;
      _choices = mixed;
      _hintStep = 0;
    });
  }

  void _onAnswerTap(int selected) {
    if (selected == _correctAnswer) {
      _score += 10;
      _correctCount += 1;
      _correctStreak += 1;
      _wrongStreak = 0;
      if (_correctStreak >= 3) {
        _difficultyLevel = min(5, _difficultyLevel + 1);
        _correctStreak = 0;
      }
    } else {
      _wrongStreak += 1;
      _correctStreak = 0;
      if (_wrongStreak >= 2) {
        _difficultyLevel = max(1, _difficultyLevel - 1);
        _wrongStreak = 0;
      }
    }
    _nextRound();
  }

  Future<void> _showHint() async {
    _hintStep += 1;
    unawaited(_progressService.recordHintUsage(context: 'quick_math'));

    String hint;
    if (_currentOperation == _MathOperation.add) {
      hint = _hintStep == 1
           ? 'Toplamada onlukları ve birlikleri ayrı düşün.'
           : '$_firstOperand + $_secondOperand işlemini parçala: '
              '${_firstOperand ~/ 10 * 10} + ${_firstOperand % 10} + $_secondOperand';
    } else if (_currentOperation == _MathOperation.subtract) {
      hint = _hintStep == 1
           ? 'Çıkarmada büyük sayıdan küçüğü çıkar.'
           : '$_firstOperand - $_secondOperand için önce birlikleri düşün.';
    } else if (_currentOperation == _MathOperation.multiply) {
      hint = _hintStep == 1
           ? 'Çarpma tekrarlayan toplama gibidir.'
          : '$_firstOperand x $_secondOperand = '
              '${List<int>.filled(_secondOperand, _firstOperand).join(' + ')}';
    } else {
      final quotient = _correctAnswer;
      hint = _hintStep == 1
           ? 'Bölmede cevap, bölünen sayıyı bölene kaç kez sığdırabildiğindir.'
          : 'Kontrol et: $_secondOperand x $quotient = $_firstOperand';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hint)),
    );
  }

  void _nextRound() {
    if (_round >= 10) {
      _timer?.cancel();
      unawaited(_saveSessionIfNeeded());
      _showResultDialog();
      return;
    }

    setState(() => _round += 1);
    _createQuestion();
    _startTimer();
  }

  Future<void> _saveSessionIfNeeded() async {
    if (_sessionSaved) return;
    _sessionSaved = true;

    final elapsed =
        DateTime.now().difference(_sessionStartedAt).inMinutes.clamp(1, 60);
    await _progressService.recordQuickMathResult(
      correct: _correctCount,
      total: 10,
      score: _score,
      minutes: elapsed,
    );
  }

  Future<void> _showResultDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Oyun Bitti'),
          content: Text('Toplam Puan: $_score / 100'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Kapat'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartGame();
              },
              child: const Text('Tekrar Oyna'),
            ),
          ],
        );
      },
    );
  }

  void _restartGame() {
    setState(() {
      _round = 1;
      _score = 0;
      _correctCount = 0;
      _correctStreak = 0;
      _wrongStreak = 0;
      _sessionSaved = false;
      _sessionStartedAt = DateTime.now();
      _hintStep = 0;
    });
    _createQuestion();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progress = _timeLeft / _roundSeconds;

    return PlayfulGameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Hızlı Matematik'),
        actions: [
          IconButton(
            onPressed: () => showGameInfoDialog(
              context,
              title: 'Hızlı Matematik',
              rules: [
                'Ekranda bir matematik sorusu çıkar.',
                'Süre dolmadan doğru cevabı seç!',
                'Her doğru cevap sana puan kazandırır.',
                'Yanlış cevap verirsen skor sıfırlanmaz ama puan alamazsın.',
                'Ne kadar hızlı cevaplarsan o kadar iyi!',
              ],
              tip: 'Önce kolay soruları hızlı çöz, zor olanlarda sakin ol!',
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Nasıl oynanır?',
          ),
          IconButton(onPressed: _restartGame, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PlayfulGameHero(
                  icon: Icons.calculate_rounded,
                  title: 'Hızlı Matematik',
                  subtitle: 'Süre dolmadan doğru seçeneği bul.',
                  accent: Color(0xFF90AAFF),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PlayfulStatChip(
                      label: 'Tur',
                      value: '$_round/10',
                      accent: const Color(0xFF7689FF),
                      icon: Icons.flag_rounded,
                    ),
                    const SizedBox(width: 10),
                    PlayfulStatChip(
                      label: 'Puan',
                      value: '$_score',
                      accent: const Color(0xFFFF85BE),
                      icon: Icons.stars_rounded,
                    ),
                    const SizedBox(width: 10),
                    PlayfulStatChip(
                      label: 'Seviye',
                      value: '$_difficultyLevel',
                      accent: const Color(0xFF9D84FF),
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.55),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF8D9BFF)),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF98B4FF),
                        Color(0xFFA99BFF),
                        Color(0xFFFFA5D6)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Soruyu Çöz',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _showHint,
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: const Text('İpuçlu Çözüm'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B71D6),
                    side: BorderSide(
                      color: const Color(0xFF95A2FF).withValues(alpha: 0.6),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                ..._choices.map(
                  (choice) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: () => _onAnswerTap(choice),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: const Color(0xFF9FA8FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        '$choice',
                        style: const TextStyle(
                          fontSize: 22,
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
}

enum _MathOperation { add, subtract, multiply, divide }
