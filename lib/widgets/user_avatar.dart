import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular avatar showing the user's uploaded profile picture when set,
/// falling back to the bundled placeholder art, and finally to an
/// initial-letter badge if even that fails to load.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.profilePictureUrl,
    this.fallbackName,
    this.borderWidth = 0,
  });

  final double size;
  final String? profilePictureUrl;
  final String? fallbackName;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final trimmedName = fallbackName?.trim() ?? '';
    final initial = trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : 'U';

    final hasPhoto = profilePictureUrl != null && profilePictureUrl!.isNotEmpty;

    final image = hasPhoto
        ? Image.network(
            profilePictureUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _initialBadge(initial),
          )
        : Image.asset(
            'assets/images/welcome_avatar.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _initialBadge(initial),
          );

    return Container(
      decoration: borderWidth > 0
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: borderWidth,
              ),
            )
          : null,
      child: ClipOval(child: SizedBox(width: size, height: size, child: image)),
    );
  }

  Widget _initialBadge(String initial) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.fieldFill,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}
