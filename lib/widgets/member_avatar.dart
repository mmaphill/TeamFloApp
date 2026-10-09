import 'package:flutter/material.dart';
import '../models/user_model.dart';

class MemberAvatar extends StatelessWidget {
  final UserModel user;
  final double radius;

  const MemberAvatar({
    super.key,
    required this.user,
    this.radius = 50,
  });

  static const double _cropCircleSize = 250.0;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _parseColor(user.avatarColor),
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        )
      ),
    );
  }

  Widget build(BuildContext context) {
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;
    if (!hasPhoto) return _fallback();

    final size = radius * 2;
    final crop = user.photoCropData;
    final ratio = size / _cropCircleSize;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(
                (crop?.offsetX ?? 0) * ratio,
                (crop?.offsetY ?? 0) * ratio,
            )
            ..scale(crop?.scale ?? 1.0),
          child: Image.network(
            user.photoUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      ),
    );
  }
}