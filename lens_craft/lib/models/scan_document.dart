import 'package:hive/hive.dart';

part 'scan_document.g.dart';

@HiveType(typeId: 0)
class ScanDocument extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  int pageCount;

  @HiveField(5)
  String? thumbnailPath;

  @HiveField(6)
  List<String> imagePaths; // List of image file paths

  @HiveField(7)
  List<String> filterTypes; // Corresponding filter for each page

  ScanDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.pageCount = 0,
    this.thumbnailPath,
    required this.imagePaths,
    required this.filterTypes,
  });
}

