import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Сервис экспорта карточек 9:16 (1080x1920) в Instagram Stories / Telegram
class StoriesExportService {
  /// Рендерит RepaintBoundary в PNG с высоким разрешением и вызывает системный Share Sheet
  static Future<bool> captureAndShare({
    required GlobalKey boundaryKey,
    String shareText = 'KALKAN SPORT · СААТ-1 Прецизионная Биометрия #kalkansport',
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('StoriesExportService: boundary is null');
        return false;
      }

      // pixelRatio: 3.0 обеспечивает четкое разрешение 1080x1920 из логического 360x640
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/kalkan_story_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // ignore: deprecated_member_use
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: shareText,
        subject: 'KALKAN SPORT Story',
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('StoriesExportService error: $e');
      return false;
    }
  }

  /// Сохраняет готовый PNG в локальное хранилище и возвращает путь
  static Future<String?> captureToFile({
    required GlobalKey boundaryKey,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final docsDir = await getApplicationDocumentsDirectory();
      final filePath = '${docsDir.path}/kalkan_story_saved_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      return file.path;
    } catch (e) {
      debugPrint('StoriesExportService.captureToFile error: $e');
      return null;
    }
  }
}
