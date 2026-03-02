import 'package:flutter/material.dart';

import 'blokus/blokus_screen.dart';
import 'game_2048/game_2048_screen.dart';
import 'gobblet/gobblet_screen.dart';
import 'hexapawn/hexapawn_screen.dart';
import 'hive/hive_screen.dart';
import 'memory/memory_match_screen.dart';
import 'mini_tournament/mini_tournament_screen.dart';
import 'quarto/quarto_screen.dart';
import 'quick_math/quick_math_screen.dart';
import 'rps/rps_screen.dart';
import 'santorini/santorini_screen.dart';
import '../learning/digital_safety_screen.dart';
import '../learning/interleaved_practice_screen.dart';
import '../theme/playful_theme.dart';

class GameHubScreen extends StatelessWidget {
  const GameHubScreen({
    super.key,
    this.onGameStarted,
  });

  final ValueChanged<String>? onGameStarted;

  @override
  Widget build(BuildContext context) {
    final games = <_GameItem>[
      _GameItem(
        title: '2048',
        subtitle: 'Strateji ve sayı birleştirme',
        icon: Icons.grid_4x4,
        color: const Color(0xFF8FBFFF),
        difficulty: 'Odak',
        builder: () => const Game2048Screen(),
      ),
      _GameItem(
        title: 'Taş Kağıt Makas',
        subtitle: 'Yapay zeka destekli klasik oyun',
        icon: Icons.cut,
        color: const Color(0xFFFFACDA),
        difficulty: 'Refleks',
        builder: () => const RockPaperScissorsScreen(),
      ),
      _GameItem(
        title: 'Hexapawn',
        subtitle: 'Az taşlı mini satranç oyunu',
        icon: Icons.sports_esports,
        color: const Color(0xFFB9A7FF),
        difficulty: 'Strateji',
        builder: () => const HexapawnScreen(),
      ),
      _GameItem(
        title: 'Gobblet',
        subtitle: 'İç içe geçen taşlarla 4\'lü sıra kur',
        icon: Icons.layers,
        color: const Color(0xFFE8A87C),
        difficulty: 'Strateji',
        builder: () => const GobbletScreen(),
      ),
      _GameItem(
        title: 'Quarto',
        subtitle: 'Taşı seç, rakip yerleştirsin',
        icon: Icons.extension,
        color: const Color(0xFFD4A5FF),
        difficulty: 'Mantık',
        builder: () => const QuartoScreen(),
      ),
      _GameItem(
        title: 'Santorini',
        subtitle: 'İnşa et ve zirveye ulaş',
        icon: Icons.terrain,
        color: const Color(0xFF85D0E7),
        difficulty: 'İnşa',
        builder: () => const SantoriniScreen(),
      ),
      _GameItem(
        title: 'Hive',
        subtitle: 'Hexagonal strateji, arıyı sar',
        icon: Icons.hexagon,
        color: const Color(0xFFFBC87A),
        difficulty: 'Strateji',
        builder: () => const HiveScreen(),
      ),
      _GameItem(
        title: 'Blokus',
        subtitle: 'Geometrik parçalarla alan kapla',
        icon: Icons.dashboard,
        color: const Color(0xFFFF9AA2),
        difficulty: 'Geometri',
        builder: () => const BlokusScreen(),
      ),
      _GameItem(
        title: 'Mini Turnuva',
        subtitle: 'Kısa challenge serisi ve kupa modu',
        icon: Icons.emoji_events,
        color: const Color(0xFFA693FF),
        difficulty: 'Karışık',
        builder: () => const MiniTournamentScreen(),
      ),
      _GameItem(
        title: 'Karma Pratik',
        subtitle: 'Interleaving odaklı karışık egzersiz',
        icon: Icons.shuffle,
        color: const Color(0xFF9AB3FF),
        difficulty: 'Transfer',
        builder: () => const InterleavedPracticeScreen(),
      ),
      _GameItem(
        title: 'Hafıza Eşleştirme',
        subtitle: 'Kartları aç ve eşleri bul',
        icon: Icons.psychology_alt,
        color: const Color(0xFFFFB4E1),
        difficulty: 'Hafıza',
        builder: () => const MemoryMatchScreen(),
      ),
      _GameItem(
        title: 'Dijital Güvenlik',
        subtitle: 'Güvenli internet senaryoları',
        icon: Icons.security,
        color: const Color(0xFFBCAAFF),
        difficulty: 'Farkındalık',
        builder: () => const DigitalSafetyScreen(),
      ),
      _GameItem(
        title: 'Hızlı Matematik',
        subtitle: 'Zamana karşı soru çözüm',
        icon: Icons.calculate,
        color: const Color(0xFF97C4FF),
        difficulty: 'Hız',
        builder: () => const QuickMathScreen(),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(gradient: PlayfulPalette.gamesBackground),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1100
                ? 4
                : width >= 760
                    ? 3
                    : 2;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: _buildHero(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _GameCard(
                        game: games[index],
                        delayIndex: index,
                        onLaunch: onGameStarted,
                      ),
                      childCount: games.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: width >= 760 ? 1.05 : 0.88,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF97BBFF), Color(0xFFA99CFF), Color(0xFFFFB3DC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2838559D),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x3DFFFFFF),
            child: Icon(Icons.sports_esports, color: Colors.white, size: 30),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oyun Merkezi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Kısa oyunlar, hızlı geri bildirim ve bol rozet!',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.delayIndex,
    this.onLaunch,
  });

  final _GameItem game;
  final int delayIndex;
  final ValueChanged<String>? onLaunch;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 260 + (delayIndex * 55)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () {
          onLaunch?.call(game.title);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => game.builder()),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                game.color.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: game.color.withValues(alpha: 0.35),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F3F5A86),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: game.color.withValues(alpha: 0.2),
                      child: Icon(game.icon, size: 28, color: game.color),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: game.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        game.difficulty,
                        style: TextStyle(
                          color: game.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
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

class _GameItem {
  const _GameItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.difficulty,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String difficulty;
  final Widget Function() builder;
}
