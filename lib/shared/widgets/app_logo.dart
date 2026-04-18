import 'package:flutter/material.dart';

import '../../core/config/app_constants.dart';
import '../../core/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool withBackground;
  final bool withShadow;

  const AppLogo({
    super.key,
    this.size = 96,
    this.withBackground = true,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final logoImage = Image.asset(
      AppConstants.appLogoAsset,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.build_circle_outlined,
          color: AppColors.primary,
          size: 36,
        );
      },
    );

    if (!withBackground) {
      return SizedBox(width: size, height: size, child: logoImage);
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.07),
                ),
              ]
            : null,
      ),
      child: logoImage,
    );
  }
}
