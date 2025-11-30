// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanDocumentAdapter extends TypeAdapter<ScanDocument> {
  @override
  final int typeId = 0;

  @override
  ScanDocument read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanDocument(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
      pageCount: fields[4] as int,
      thumbnailPath: fields[5] as String?,
      imagePaths: (fields[6] as List).cast<String>(),
      filterTypes: (fields[7] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ScanDocument obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.pageCount)
      ..writeByte(5)
      ..write(obj.thumbnailPath)
      ..writeByte(6)
      ..write(obj.imagePaths)
      ..writeByte(7)
      ..write(obj.filterTypes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanDocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
