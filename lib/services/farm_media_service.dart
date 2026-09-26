import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps compressed farmer photos inside the app's private documents directory.
class FarmMediaService {
  FarmMediaService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<List<String>> pickCompressedPhotos() async {
    final selected = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (selected.isEmpty) return const [];
    final appDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory(p.join(appDir.path, 'npk_photos'));
    await photoDir.create(recursive: true);
    final paths = <String>[];
    for (final photo in selected) {
      final ext = p.extension(photo.path).toLowerCase();
      final name = '${DateTime.now().microsecondsSinceEpoch}_${paths.length}${ext.isEmpty ? '.jpg' : ext}';
      final target = File(p.join(photoDir.path, name));
      await File(photo.path).copy(target.path);
      paths.add(target.path);
    }
    return paths;
  }

  Future<void> deletePhotoFile(String path) async {
    if (kIsWeb) return;
    final appDir = await getApplicationDocumentsDirectory();
    final photoDir = p.normalize(p.join(appDir.path, 'npk_photos'));
    final normalized = p.normalize(path);
    if (p.isWithin(photoDir, normalized) && await File(normalized).exists()) {
      await File(normalized).delete();
    }
  }
}
