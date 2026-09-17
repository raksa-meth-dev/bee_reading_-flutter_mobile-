import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A cached network image widget specialized for book covers with disk and memory caching.
class CachedBookCover extends StatelessWidget {
  const CachedBookCover({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.memCacheWidth,
    this.width,
    this.height,
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final int? memCacheWidth;
  final double? width;
  final double? height;

  bool get _isNetwork => imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (!_isNetwork) {
      final cleanPath = imageUrl.startsWith('file://') ? imageUrl.replaceFirst('file://', '') : imageUrl;
      final file = File(cleanPath);
      return Image.file(
        file,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheWidth: memCacheWidth,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Image.network(
        imageUrl,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheWidth: memCacheWidth,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
      fadeInDuration: const Duration(milliseconds: 250),
    );
  }
}
