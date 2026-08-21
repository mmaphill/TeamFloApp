import 'package:flutter/material.dart';

class BeltRankBadge extends StatelessWidget {
  final String? beltRank;
  final double width;
  final double height;

  const BeltRankBadge({
    Key? key,
    required this.beltRank,
    this.width = 40,
    this.height = 40,
  }) : super(key: key);

  String _getBeltImagePath(String? belt) {
    switch (belt?.toLowerCase()) {
      case 'white':
        return 'lib/assets/images/belt_ranks/white_belt.png';
      case 'blue':
        return 'lib/assets/images/belt_ranks/blue_belt.png';
      case 'purple':
        return 'lib/assets/images/belt_ranks/purple_belt.png';
      case 'brown':
        return 'lib/assets/images/belt_ranks/brown_belt.png';
      case 'black':
        return 'lib/assets/images/belt_ranks/black_belt.png';
      case 'coral belt':
        return 'lib/assets/images/belt_ranks/coral_belt.png';
      case 'red-coral belt':
        return 'lib/assets/images/belt_ranks/red_coral_belt.png';
      case 'red belt':
        return 'lib/assets/images/belt_ranks/red_belt.png';
      default:
        return 'lib/assets/images/belt_ranks/white_belt.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing if no belt rank
    if (beltRank == null || beltRank!.isEmpty) {
      return const SizedBox();
    }

    return Image.asset(
      _getBeltImagePath(beltRank),
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Text(
              beltRank?.substring(0, 1).toUpperCase() ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}