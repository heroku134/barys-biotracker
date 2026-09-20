import 'dart:io';
import 'package:flutter/material.dart';

/// Универсальный загрузчик аватара атлета (поддерживает как локальные файлы с камеры/галереи, так и встроенные ассеты)
class AvatarImageProvider {
  static ImageProvider getImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/images/warrior_cutout_clean.png');
    }
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
    return const AssetImage('assets/images/warrior_cutout_clean.png');
  }

  static Widget buildAvatarWidget({
    required String? path,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.topCenter,
  }) {
    if (path != null && !path.startsWith('assets/')) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/warrior_cutout_clean.png',
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
            ),
          );
        }
      } catch (_) {}
    }

    return Image.asset(
      (path != null && path.isNotEmpty) ? path : 'assets/images/warrior_cutout_clean.png',
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
    );
  }
}
