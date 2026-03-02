import 'package:flutter/material.dart';

import '../../data/services/learning_progress_service.dart';

class SpacedReviewScreen extends StatefulWidget {
  const SpacedReviewScreen({super.key});

  @override
  State<SpacedReviewScreen> createState() => _SpacedReviewScreenState();
}

class _SpacedReviewScreenState extends State<SpacedReviewScreen> {
  final LearningProgressService _progressService = LearningProgressService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<ReviewCard> _cards = const [];
  int _completed = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });
    final cards = await _progressService.getDueReviewCards(limit: 16);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
  }

  Future<void> _submit(bool correct) async {
    if (_cards.isEmpty || _isSubmitting) return;
    final card = _cards.first;

    setState(() {
      _isSubmitting = true;
    });
    await _progressService.submitReviewResult(
        cardId: card.id, correct: correct);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _completed += 1;
      if (correct) {
        _correct += 1;
      }
      _cards = _cards.sublist(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final doneAll = !_isLoading && _cards.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Aralikli Tekrar')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: doneAll ? _buildCompletedState() : _buildReviewState(),
            ),
    );
  }

  Widget _buildReviewState() {
    final card = _cards.first;
    final progress = _completed / (_completed + _cards.length).clamp(1, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kart ${_completed + 1}/${_completed + _cards.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Dogru: $_correct',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF00796B)],
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Kelimeyi hatirla',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                card.word,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Anlamini dusun, cumlede kullan ve sonra degerlendir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : () => _submit(false),
          icon: const Icon(Icons.refresh),
          label: const Text('Hatirlayamadim'),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : () => _submit(true),
          icon: const Icon(Icons.check_circle),
          label: const Text('Hatirladim'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedState() {
    final successRatio = _completed <= 0 ? 0.0 : (_correct / _completed);
    final title =
        _completed == 0 ? 'Bugun kart yok' : 'Tekrar oturumu tamamlandi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          successRatio >= 0.75 ? Icons.emoji_events : Icons.task_alt,
          size: 90,
          color: successRatio >= 0.75 ? Colors.amber : Colors.green,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _completed == 0
              ? 'Yeni kelime calistikca kartlar otomatik olusur.'
              : 'Dogru: $_correct / $_completed',
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _loadCards,
          icon: const Icon(Icons.refresh),
          label: const Text('Kartlari Yenile'),
        ),
      ],
    );
  }
}
