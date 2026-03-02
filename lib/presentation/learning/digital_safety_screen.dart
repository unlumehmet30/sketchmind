import 'package:flutter/material.dart';

import '../../data/services/learning_progress_service.dart';

class DigitalSafetyScreen extends StatefulWidget {
  const DigitalSafetyScreen({super.key});

  @override
  State<DigitalSafetyScreen> createState() => _DigitalSafetyScreenState();
}

class _DigitalSafetyScreenState extends State<DigitalSafetyScreen> {
  final LearningProgressService _progressService = LearningProgressService();

  static const List<_SafetyQuestion> _questions = [
    _SafetyQuestion(
      title: 'Tanınmayan Mesaj',
      prompt:
          'Sosyal bir oyunda tanımadığın biri senden adını ve okulunu istiyor. Ne yaparsın?',
      options: [
        'Bilgi vermeden yetişkine haber veririm.',
        'Sadece adımı veririm, sorun olmaz.',
        'Hepsini yazarım, yeni arkadaş kazanırım.',
      ],
      correctIndex: 0,
      explanation:
          'Kişisel bilgi paylaşmadan güvenilir bir yetişkine haber vermek en doğru adımdır.',
    ),
    _SafetyQuestion(
      title: 'Şifre Güvenliği',
      prompt: 'En güvenli şifre seçimi hangisidir?',
      options: [
        'Doğum yılı + isim',
        'Karışık harf, rakam ve sembol',
        '123456',
      ],
      correctIndex: 1,
      explanation:
          'Güçlü şifreler tahmini zor birden fazla karakter türü içerir.',
    ),
    _SafetyQuestion(
      title: 'Şüpheli Link',
      prompt:
          'Ödül kazandın diyen bir link geliyor ve hemen tıklamanı istiyor. Ne yaparsın?',
      options: [
        'Hemen tıklarım, fırsatı kaçırmam.',
        'Linki arkadaşlara da yollarım.',
        'Tıklamadan önce ebeveyn/öğretmene sorarım.',
      ],
      correctIndex: 2,
      explanation:
          'Şüpheli linkler oltalama olabilir. Yetişkin onayı olmadan tıklamamak gerekir.',
    ),
    _SafetyQuestion(
      title: 'Siber Zorbalık',
      prompt: 'Bir grupta bir çocuğa hakaret ediliyor. Doğru davranış nedir?',
      options: [
        'Ben de katılırım.',
        'Ekran görüntüsü alıp yetişkine bildiririm.',
        'Hiçbir şey olmamış gibi devam ederim.',
      ],
      correctIndex: 1,
      explanation:
          'Zorbalığı belgeleyip güvenilir bir yetişkine bildirmek koruyucu bir davranıştır.',
    ),
    _SafetyQuestion(
      title: 'Konum Paylaşımı',
      prompt:
          'Uygulama konum izni istiyor ama gerekcesi belirsiz. Ne yaparsin?',
      options: [
        'Her zaman izin veririm.',
        'İzin vermeden önce neden istendiğini kontrol ederim.',
        'Arkadaşım izin verdiyse ben de veririm.',
      ],
      correctIndex: 1,
      explanation:
          'Gereksiz konum paylaşımı gizlilik riski doğurur. İhtiyaç olmayan izni vermemek gerekir.',
    ),
  ];

  int _index = 0;
  int _score = 0;
  bool _isFinished = false;
  bool _saved = false;

  Future<void> _answer(int selectedIndex) async {
    final question = _questions[_index];
    final isCorrect = selectedIndex == question.correctIndex;

    if (isCorrect) {
      _score += 1;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isCorrect ? 'Doğru' : 'Yanlış'}: ${question.explanation}',
          ),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    if (_index >= _questions.length - 1) {
      setState(() {
        _isFinished = true;
      });
      await _saveIfNeeded();
      return;
    }

    setState(() {
      _index += 1;
    });
  }

  Future<void> _saveIfNeeded() async {
    if (_saved) return;
    _saved = true;
    await _progressService.recordDigitalSafetySession(
      score: _score,
      total: _questions.length,
      minutes: 4,
    );
  }

  void _restart() {
    setState(() {
      _index = 0;
      _score = 0;
      _isFinished = false;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dijital Güvenlik'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isFinished ? _buildResult() : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Soru ${_index + 1}/${_questions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Puan: $_score',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ((_index + 1) / _questions.length).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
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
              const SizedBox(height: 8),
              Text(
                question.prompt,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          question.options.length,
          (optionIndex) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElevatedButton(
              onPressed: () => _answer(optionIndex),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: Text(
                question.options[optionIndex],
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final ratio = _score / _questions.length;
    final title = ratio >= 0.8
        ? 'Güvenlik seviyesi çok iyi'
        : (ratio >= 0.5
            ? 'Güvenlik seviyesi iyi'
            : 'Biraz daha tekrar gerekli');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          ratio >= 0.8 ? Icons.shield : Icons.health_and_safety,
          size: 92,
          color: ratio >= 0.8 ? Colors.green : Colors.blueAccent,
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Skor: $_score / ${_questions.length}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.replay),
          label: const Text('Tekrar Çöz'),
        ),
      ],
    );
  }
}

class _SafetyQuestion {
  const _SafetyQuestion({
    required this.title,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String title;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}
