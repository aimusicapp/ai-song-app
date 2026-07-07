import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  /// Writes generated audio bytes to a temp file. Deleted automatically
  /// if the user doesn't explicitly save it.
  static Future<File> writeTemp(Uint8List bytes, String fileName) async {
    final Directory tempDir = await getTemporaryDirectory();
    final File file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // ignore cleanup errors
    }
  }

  /// Requests storage permission then copies the temp file to a permanent,
  /// user-visible folder on the device (Music/AISongs).
  static Future<String?> saveToDevice(File tempFile, String fileName) async {
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();
      if (!status.isGranted) {
        final legacyStatus = await Permission.storage.request();
        if (!legacyStatus.isGranted) {
          return null;
        }
      }
    }

    try {
      final Directory targetDir = Directory('/storage/emulated/0/Music/AISongs');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final String targetPath = '${targetDir.path}/$fileName';
      await tempFile.copy(targetPath);
      return targetPath;
    } catch (_) {
      // fallback to app-specific external storage if the public Music
      // folder isn't writable on this device/Android version
      try {
        final Directory? fallbackDir = await getExternalStorageDirectory();
        if (fallbackDir == null) return null;
        final String targetPath = '${fallbackDir.path}/$fileName';
        await tempFile.copy(targetPath);
        return targetPath;
      } catch (_) {
        return null;
      }
    }
  }
}
