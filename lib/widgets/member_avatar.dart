import 'package:flutter/material.dart';
import '../config/colors.dart';
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
      return AppColors.avatarDefault;
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
            color: AppColors.onPrimary,
          )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;
    if (!hasPhoto) return _fallback();

    final size = radius * 2;
    final crop = user.photoCropData;
    final ratio = size / _cropCircleSize;
    final double dx = (crop?.offsetX ?? 0) * ratio;
    final double dy = (crop?.offsetY ?? 0) * ratio;
    final double zoom = crop?.scale ?? 1.0;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(dx, dy, 0).multiplied(Matrix4.diagonal3Values(zoom, zoom, zoom)),
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