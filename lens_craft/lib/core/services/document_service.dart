import 'package:hive_flutter/hive_flutter.dart';
import 'package:lens_craft/models/scan_document.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DocumentService {
  static const String _boxName = 'documents';
  static Box<ScanDocument>? _box;

  static Box<ScanDocument>? get box => _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ScanDocumentAdapter());
    _box = await Hive.openBox<ScanDocument>(_boxName);
  }

  static Future<void> saveDocument(ScanDocument document) async {
    await _box?.put(document.id, document);
  }

  static List<ScanDocument> getAllDocuments() {
    return _box?.values.toList() ?? [];
  }

  static Future<void> deleteDocument(String documentId) async {
    final document = _box?.get(documentId);
    if (document != null) {
      // Delete associated image files
      for (var path in document.imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore deletion errors
        }
      }
      // Delete thumbnail if exists
      if (document.thumbnailPath != null) {
        try {
          final thumbFile = File(document.thumbnailPath!);
          if (await thumbFile.exists()) {
            await thumbFile.delete();
          }
        } catch (e) {
          // Ignore
        }
      }
      await _box?.delete(documentId);
    }
  }

  static Future<String> getDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final docsDir = Directory('${directory.path}/lens_craft');
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir.path;
  }
}

