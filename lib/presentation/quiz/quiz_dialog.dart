import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../data/dummy/stories.dart';

class QuizDialog extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizDialog({super.key, required this.questions});

  @override
  State<QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<QuizDialog> {
  int _currentIndex = 0;
  int _score = 0;
  bool _isFinished = false;

  void _answerQuestion(int selectedIndex) {
    if (selectedIndex == widget.questions[_currentIndex].correctIndex) {
      _score++;
    }

    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      setState(() {
        _isFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _isFinished ? _buildResult() : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = widget.questions[_currentIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Soru ${_currentIndex + 1}/${widget.questions.length}",
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          question.question,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ...List.generate(question.options.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElevatedButton(
              onPressed: () => _answerQuestion(index),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade900,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(question.options[index], style: const TextStyle(fontSize: 16)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResult() {
    final isSuccess = _score >= (widget.questions.length / 2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Lottie.asset(
          isSuccess ? 'assets/lottie/success_star.json' : 'assets/lottie/error_sad.json',
          width: 150,
          height: 150,
          repeat: false,
        ),
        const SizedBox(height: 10),
        Text(
          isSuccess ? "Harika İş!" : "Biraz Daha Çalışmalısın",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          "Skorun: $_score / ${widget.questions.length}",
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Tamamla"),
        ),
      ],
    );
  }
}
