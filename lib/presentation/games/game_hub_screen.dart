import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'game_2048/game_2048_screen.dart';
import 'rps/rps_screen.dart';

class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyun Merkezi'),
        automaticallyImplyLeading: false,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        children: [
          _buildGameCard(
            context,
            title: '2048',
            icon: Icons.grid_4x4,
            color: Colors.orangeAccent,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const Game2048Screen()),
            ),
          ),
          _buildGameCard(
            context,
            title: 'Taş Kağıt Makas',
            icon: Icons.cut,
            color: Colors.blueAccent,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const RockPaperScissorsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
