import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class OfflineAwareImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const OfflineAwareImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('local://')) {
      final localPath = imageUrl.substring(8);
      final file = File(localPath);
      return Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) =>
            errorWidget ?? const Icon(Icons.broken_image),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      errorWidget: (_, __, ___) =>
          errorWidget ?? const Icon(Icons.broken_image),
      placeholder: (_, __) => const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
