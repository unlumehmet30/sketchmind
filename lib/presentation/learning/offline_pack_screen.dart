import 'package:flutter/material.dart';

import '../../data/services/learning_progress_service.dart';

class OfflinePackScreen extends StatefulWidget {
  const OfflinePackScreen({super.key});

  @override
  State<OfflinePackScreen> createState() => _OfflinePackScreenState();
}

class _OfflinePackScreenState extends State<OfflinePackScreen> {
  final LearningProgressService _progressService = LearningProgressService();
  final Set<int> _completed = <int>{};

  static const List<_OfflineActivity> _activities = [
    _OfflineActivity(
      title: 'Kisa Okuma 1',
      description: 'Ormandaki robotun hikayesini oku.',
      type: _OfflineType.reading,
    ),
    _OfflineActivity(
      title: 'Kisa Okuma 2',
      description: 'Deniz alti kesif metnini oku.',
      type: _OfflineType.reading,
    ),
    _OfflineActivity(
      title: 'Kelime Alistirmasi',
      description: '5 kelimeyi dogru yaz.',
      type: _OfflineType.vocabulary,
    ),
    _OfflineActivity(
      title: 'Hizli Matematik',
      description: 'Toplama-cikarma mini seti tamamla.',
      type: _OfflineType.math,
    ),
    _OfflineActivity(
      title: 'Hafiza Karti',
      description: '3 eslestirme turu yap.',
      type: _OfflineType.memory,
    ),
    _OfflineActivity(
      title: 'Kelime Alistirmasi 2',
      description: 'Karisik harfleri duzelt.',
      type: _OfflineType.vocabulary,
    ),
  ];

  Future<void> _complete(int index) async {
    if (_completed.contains(index)) return;

    final activity = _activities[index];
    if (activity.type == _OfflineType.reading) {
      await _progressService.recordStoryRead(minutes: 4);
    } else if (activity.type == _OfflineType.vocabulary) {
      await _progressService.recordVocabularyPractice(
        answered: 5,
        correct: 4,
        masteredWords: const ['kesif', 'denge', 'macera'],
        minutes: 3,
      );
    } else if (activity.type == _OfflineType.math) {
      await _progressService.recordQuickMathResult(
        correct: 6,
        total: 8,
        score: 60,
        minutes: 4,
      );
    } else {
      await _progressService.recordGameSession(
        gameId: 'offline_memory',
        won: true,
        score: 70,
        minutes: 4,
      );
    }

    if (!mounted) return;
    setState(() {
      _completed.add(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${activity.title} tamamlandi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _completed.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Paket'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              ),
            ),
            child: Text(
              'Tamamlanan aktivite: $done/${_activities.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _activities.length,
            (index) {
              final activity = _activities[index];
              final isDone = _completed.contains(index);

              return Card(
                child: ListTile(
                  leading: Icon(_iconForType(activity.type)),
                  title: Text(activity.title),
                  subtitle: Text(activity.description),
                  trailing: ElevatedButton(
                    onPressed: isDone ? null : () => _complete(index),
                    child: Text(isDone ? 'Tamam' : 'Yap'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _iconForType(_OfflineType type) {
    switch (type) {
      case _OfflineType.reading:
        return Icons.menu_book;
      case _OfflineType.vocabulary:
        return Icons.spellcheck;
      case _OfflineType.math:
        return Icons.calculate;
      case _OfflineType.memory:
        return Icons.psychology_alt;
    }
  }
}

enum _OfflineType { reading, vocabulary, math, memory }

class _OfflineActivity {
  const _OfflineActivity({
    required this.title,
    required this.description,
    required this.type,
  });

  final String title;
  final String description;
  final _OfflineType type;
}
