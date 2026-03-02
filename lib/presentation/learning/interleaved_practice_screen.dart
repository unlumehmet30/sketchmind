import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/services/learning_progress_service.dart';

class InterleavedPracticeScreen extends StatefulWidget {
  const InterleavedPracticeScreen({super.key});

  @override
  State<InterleavedPracticeScreen> createState() =>
      _InterleavedPracticeScreenState();
}

class _InterleavedPracticeScreenState extends State<InterleavedPracticeScreen> {
  static const int _totalRounds = 9;

  final LearningProgressService _progressService = LearningProgressService();
  final Random _random = Random();

  int _round = 1;
  int _correctCount = 0;
  int _score = 0;
  bool _isFinished = false;
  bool _showMemorySequence = false;
  bool _saved = false;
  DateTime _startedAt = DateTime.now();
  Timer? _memoryTimer;
  _InterleaveQuestion? _question;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _nextQuestion();
  }

  @override
  void dispose() {
    _memoryTimer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    _memoryTimer?.cancel();
    final type =
        _InterleaveType.values[(_round - 1) % _InterleaveType.values.length];

    if (type == _InterleaveType.math) {
      _question = _buildMathQuestion();
      _showMemorySequence = false;
    } else if (type == _InterleaveType.vocabulary) {
      _question = _buildVocabularyQuestion();
      _showMemorySequence = false;
    } else {
      _question = _buildMemoryQuestion();
      _showMemorySequence = true;
      _memoryTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted || _isFinished) return;
        setState(() {
          _showMemorySequence = false;
        });
      });
    }
    setState(() {});
  }

  _InterleaveQuestion _buildMathQuestion() {
    final a = _random.nextInt(25) + 8;
    final b = _random.nextInt(20) + 5;
    final op = _random.nextInt(3);

    late int answer;
    late String prompt;
    if (op == 0) {
      answer = a + b;
      prompt = '$a + $b = ?';
    } else if (op == 1) {
      final high = max(a, b);
      final low = min(a, b);
      answer = high - low;
      prompt = '$high - $low = ?';
    } else {
      final x = (_random.nextInt(7) + 3);
      final y = (_random.nextInt(7) + 3);
      answer = x * y;
      prompt = '$x x $y = ?';
    }

    final options = <int>{answer};
    while (options.length < 4) {
      options.add(max(0, answer + _random.nextInt(18) - 9));
    }

    return _InterleaveQuestion(
      type: _InterleaveType.math,
      title: 'Matematik Turu',
      prompt: prompt,
      options: options.map((e) => '$e').toList()..shuffle(_random),
      correctAnswer: '$answer',
    );
  }

  _InterleaveQuestion _buildVocabularyQuestion() {
    const pairs = <String, String>{
      'kesif': 'yeni bir şeyi bulma',
      'denge': 'eşitlik ve uyum',
      'strateji': 'planlı hareket',
      'ipuclu': 'yardımcı yönlendirme',
      'sabir': 'bekleyebilme gücü',
      'odak': 'dikkati toplama',
    };

    final entry = pairs.entries.elementAt(_random.nextInt(pairs.length));
    final options = <String>{entry.key};
    while (options.length < 4) {
      final randomWord = pairs.keys.elementAt(_random.nextInt(pairs.length));
      options.add(randomWord);
    }

    return _InterleaveQuestion(
      type: _InterleaveType.vocabulary,
      title: 'Kelime Turu',
      prompt: '"${entry.value}" anlamına en yakın kelime hangisi?',
      options: options.toList()..shuffle(_random),
      correctAnswer: entry.key,
    );
  }

  _InterleaveQuestion _buildMemoryQuestion() {
    const symbols = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final sequence = List<String>.generate(
      5,
      (_) => symbols[_random.nextInt(symbols.length)],
    );
    final askIndex = _random.nextInt(sequence.length);
    final answer = sequence[askIndex];

    final options = <String>{answer};
    while (options.length < 4) {
      options.add(symbols[_random.nextInt(symbols.length)]);
    }

    return _InterleaveQuestion(
      type: _InterleaveType.memory,
      title: 'Hafıza Turu',
      prompt: '${askIndex + 1}. harf neydi?',
      options: options.toList()..shuffle(_random),
      correctAnswer: answer,
      memorySequence: sequence,
    );
  }

  Future<void> _onAnswer(String answer) async {
    if (_question == null || _isFinished) return;
    final isCorrect = answer == _question!.correctAnswer;

    setState(() {
      if (isCorrect) {
        _correctCount += 1;
        _score += 12;
      } else {
        _score += 2;
      }
    });

    if (_round >= _totalRounds) {
      await _finishSession();
      return;
    }

    setState(() {
      _round += 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || _isFinished) return;
    _nextQuestion();
  }

  Future<void> _finishSession() async {
    setState(() {
      _isFinished = true;
      _showMemorySequence = false;
    });
    if (_saved) return;
    _saved = true;

    final elapsed =
        DateTime.now().difference(_startedAt).inMinutes.clamp(1, 40);
    await _progressService.recordInterleavingSession(
      total: _totalRounds,
      correct: _correctCount,
      minutes: elapsed,
    );
  }

  void _restart() {
    setState(() {
      _round = 1;
      _correctCount = 0;
      _score = 0;
      _isFinished = false;
      _showMemorySequence = false;
      _saved = false;
      _startedAt = DateTime.now();
    });
    _nextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karma Pratik'),
        actions: [
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isFinished
            ? _buildResult()
            : question == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tur: $_round/$_totalRounds',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Skor: $_score',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_round / _totalRounds).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A237E), Color(0xFF283593)],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question.title,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              question.prompt,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_showMemorySequence &&
                          question.memorySequence != null)
                        _buildMemorySequence(question.memorySequence!)
                      else
                        ...question.options.map(
                          (option) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ElevatedButton(
                              onPressed: () => _onAnswer(option),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 52),
                              ),
                              child: Text(
                                option,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildMemorySequence(List<String> sequence) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.amber.withValues(alpha: 0.16),
      ),
      child: Column(
        children: [
          const Text(
            'Sırayı aklında tut',
            style: TextStyle(fontWeight: FontWeight.bold),
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
    final accuracy = _correctCount / _totalRounds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          accuracy >= 0.7
              ? Icons.workspace_premium
              : Icons.assignment_turned_in,
          size: 92,
          color: accuracy >= 0.7 ? Colors.amber : Colors.blueAccent,
        ),
        const SizedBox(height: 8),
        const Text(
          'Karma Pratik Tamamlandı',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Skor: $_score | Doğru: $_correctCount/$_totalRounds',
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.replay),
          label: const Text('Yeni Oturum'),
        ),
      ],
    );
  }
}

enum _InterleaveType { math, vocabulary, memory }

class _InterleaveQuestion {
  const _InterleaveQuestion({
    required this.type,
    required this.title,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    this.memorySequence,
  });

  final _InterleaveType type;
  final String title;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final List<String>? memorySequence;
}
