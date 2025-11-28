import 'dart:math';
import 'package:flutter/material.dart';
import 'logic/rps_predictor.dart';

class RockPaperScissorsScreen extends StatefulWidget {
  const RockPaperScissorsScreen({super.key});

  @override
  State<RockPaperScissorsScreen> createState() => _RockPaperScissorsScreenState();
}

class _RockPaperScissorsScreenState extends State<RockPaperScissorsScreen> {
  String? _userChoice;
  String? _computerChoice;
  String _result = '';
  int _userScore = 0;
  int _computerScore = 0;
  
  // ML State
  final RPSPredictor _predictor = RPSPredictor();
  String? _lastUserChoice;
  int _gameCount = 0;
  bool _isAiActive = false;

  final List<String> _choices = ['Taş', 'Kağıt', 'Makas'];
  final Map<String, IconData> _icons = {
    'Taş': Icons.landscape,
    'Kağıt': Icons.note,
    'Makas': Icons.cut,
  };

  final Random _random = Random();
  bool _isThinking = false;

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
    
    // AI Logic
    if (_gameCount >= 10 && _lastUserChoice != null) {
       final predictedUserMove = _predictor.predictNextUserMove(_lastUserChoice!);
       computerSelection = _predictor.getCounterMove(predictedUserMove);
       _isAiActive = true;
    } else {
       computerSelection = _choices[_random.nextInt(_choices.length)];
       _isAiActive = false;
    }

    // Record the move for learning
    if (_lastUserChoice != null) {
      _predictor.recordMove(_lastUserChoice, choice);
    }
    _lastUserChoice = choice;
    _gameCount++;

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
      _lastUserChoice = null;
      _isAiActive = false;
      // Note: We don't reset the predictor's memory so it keeps learning!
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taş Kağıt Makas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isAiActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purpleAccent),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Yapay Zeka Modu Aktif', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScoreCard('Sen', _userScore),
              _buildScoreCard('Bilgisayar', _computerScore),
            ],
          ),
          const SizedBox(height: 40),
          if (_isThinking)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Bilgisayar düşünüyor...', style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
              ],
            )
          else if (_userChoice != null && _computerChoice != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChoiceDisplay(_userChoice!, 'Sen'),
                const SizedBox(width: 20),
                const Text('VS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 20),
                _buildChoiceDisplay(_computerChoice!, 'Bilgisayar'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _result,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _result == 'Kazandın!' ? Colors.green : (_result == 'Kaybettin!' ? Colors.red : Colors.orange),
              ),
            ),
          ] else
            const Text('Bir seçim yap!', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _choices.map((choice) => _buildChoiceButton(choice)).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Oyun Sayısı: $_gameCount', 
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int score) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('$score', style: const TextStyle(fontSize: 24)),
      ],
    );
  }

  Widget _buildChoiceDisplay(String choice, String label) {
    return Column(
      children: [
        Icon(_icons[choice], size: 64, color: Colors.blueAccent),
        Text(label),
      ],
    );
  }

  Widget _buildChoiceButton(String choice) {
    return ElevatedButton(
      onPressed: _isThinking ? null : () => _play(choice),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        shape: const CircleBorder(),
      ),
      child: Icon(_icons[choice], size: 32),
    );
  }
}
