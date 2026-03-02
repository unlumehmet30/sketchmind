import 'package:flutter/material.dart';

class TileWidget extends StatelessWidget {
  final int value;
  final double size;

  const TileWidget({super.key, required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getTileColor(value),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          value == 0 ? '' : '$value',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: _getTextColor(value),
          ),
        ),
      ),
    );
  }

  Color _getTileColor(int value) {
    switch (value) {
      case 0:
        return const Color(0xFFFFFFFF);
      case 2:
        return const Color(0xFFF2F6FF);
      case 4:
        return const Color(0xFFECEBFF);
      case 8:
        return const Color(0xFFE8DAFF);
      case 16:
        return const Color(0xFFFFDBF1);
      case 32:
        return const Color(0xFFFFC9EA);
      case 64:
        return const Color(0xFFFFB1DF);
      case 128:
        return const Color(0xFFC7D9FF);
      case 256:
        return const Color(0xFFB9CCFF);
      case 512:
        return const Color(0xFFAAC0FF);
      case 1024:
        return const Color(0xFF9AB4FF);
      case 2048:
        return const Color(0xFF8DA5FF);
      default:
        return const Color(0xFF829BFF);
    }
  }

  Color _getTextColor(int value) {
    if (value <= 64) return const Color(0xFF435174);
    return Colors.white;
  }
}
