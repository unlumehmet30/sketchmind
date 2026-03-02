import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/services/learning_progress_service.dart';

class VocabularyTrainerScreen extends StatefulWidget {
  const VocabularyTrainerScreen({
    super.key,
    required this.storyTitle,
    required this.storyText,
  });

  final String storyTitle;
  final String storyText;

  @override
  State<VocabularyTrainerScreen> createState() =>
      _VocabularyTrainerScreenState();
}

class _VocabularyTrainerScreenState extends State<VocabularyTrainerScreen> {
  final LearningProgressService _progressService = LearningProgressService();
  final Random _random = Random();

  late List<String> _words;
  late List<_WordQuestion> _questions;
  int _index = 0;
  int _score = 0;
  bool _finished = false;
  bool _saved = false;
  final Set<String> _masteredWords = <String>{};

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    _words = _extractWords(widget.storyText);
    _questions = _words.map(_buildQuestion).toList();
    _index = 0;
    _score = 0;
    _finished = _questions.isEmpty;
    _saved = false;
    _masteredWords.clear();
  }

  List<String> _extractWords(String text) {
    final tokenRegex = RegExp(r"[a-zA-ZcCgGiIoOsSuUçğıöşüÇĞİÖŞÜ]{4,}");
    final stopWords = <String>{
      've',
      'ama',
      'cunku',
      'gibi',
      'icin',
      'daha',
      'kadar',
      'sonra',
      'once',
      'bunu',
      'sunu',
      'olan',
      'olarak',
      'birlikte',
      'cocuk',
      'hikaye',
      'diye',
      'ancak',
      'bazen',
      'hemen',
      'orada',
      'burada',
    };

    final all = <String>{};
    for (final match in tokenRegex.allMatches(text)) {
      final raw = match.group(0);
      if (raw == null) continue;
      final normalized = raw.toLowerCase();
      if (stopWords.contains(normalized)) continue;
      all.add(normalized);
    }

    final sorted = all.toList()..sort((a, b) => b.length.compareTo(a.length));
    return sorted.take(8).toList();
  }

  _WordQuestion _buildQuestion(String word) {
    final options = <String>{word};
    while (options.length < 4) {
      options.add(_mutateWord(word));
    }
    final mixed = options.toList()..shuffle(_random);

    return _WordQuestion(
      prompt: 'Hangi seçenekte kelime doğru yazılıyor?',
      targetWord: word,
      options: mixed,
    );
  }

  String _mutateWord(String word) {
    if (word.length < 4) {
      return '$word${_random.nextInt(9)}';
    }

    final chars = word.split('');
    final index = _random.nextInt(chars.length);
    const replacementPool = 'abcdeghilmnoprstuvyz';
    final replacement =
        replacementPool[_random.nextInt(replacementPool.length)];

    chars[index] = replacement;
    if (_random.nextBool() && chars.length > 4) {
      final swapIndex = _random.nextInt(chars.length - 1);
      final temp = chars[swapIndex];
      chars[swapIndex] = chars[swapIndex + 1];
      chars[swapIndex + 1] = temp;
    }
    return chars.join();
  }

  Future<void> _finishIfNeeded() async {
    if (!_finished || _saved) return;
    _saved = true;
    await _progressService.recordVocabularyPractice(
      answered: _questions.length,
      correct: _score,
      masteredWords: _masteredWords.toList(),
      minutes: max(2, (_questions.length / 2).round()),
    );
  }

  void _answer(String option) {
    final question = _questions[_index];
    final isCorrect = option == question.targetWord;
    if (isCorrect) {
      _score += 1;
      _masteredWords.add(question.targetWord);
    }

    if (_index >= _questions.length - 1) {
      setState(() {
        _finished = true;
      });
      _finishIfNeeded();
      return;
    }

    setState(() {
      _index += 1;
    });
  }

  void _restart() {
    setState(_prepare);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelime Modu')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu hikayeden yeterli kelime çıkarılamadı. Daha uzun bir hikaye dene.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kelime Modu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _finished ? _buildResult() : _buildQuiz(),
      ),
    );
  }

  Widget _buildQuiz() {
    final q = _questions[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.storyTitle,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          'Soru ${_index + 1}/${_questions.length}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.blue.withValues(alpha: 0.08),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.prompt,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelime: ${q.targetWord}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...q.options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElevatedButton(
              onPressed: () => _answer(option),
              child: Text(option, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final ratio = _questions.isEmpty ? 0 : _score / _questions.length;
    final levelText =
        ratio >= 0.8 ? 'Süper' : (ratio >= 0.5 ? 'İyi' : 'Biraz daha pratik');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          ratio >= 0.8 ? Icons.emoji_events : Icons.menu_book,
          size: 92,
          color: ratio >= 0.8 ? Colors.amber : Colors.blueAccent,
        ),
        const SizedBox(height: 8),
        Text(
          'Skor: $_score / ${_questions.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Text(
          'Seviye: $levelText',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        if (_masteredWords.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _masteredWords.map((word) => Chip(label: Text(word))).toList(),
          ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar Dene'),
        ),
      ],
    );
  }
}

class _WordQuestion {
  const _WordQuestion({
    required this.prompt,
    required this.targetWord,
    required this.options,
  });

  final String prompt;
  final String targetWord;
  final List<String> options;
}
