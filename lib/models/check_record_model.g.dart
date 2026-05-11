// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CheckRecordAdapter extends TypeAdapter<CheckRecord> {
  @override
  final int typeId = 2;

  @override
  CheckRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CheckRecord()
      ..bondNumber = fields[0] as String
      ..denomination = fields[1] as String
      ..checkedAt = fields[2] as DateTime
      ..resultStatus = fields[3] as String
      ..drawNumber = fields[4] as String
      ..drawDate = fields[5] as String;
  }

  @override
  void write(BinaryWriter writer, CheckRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.bondNumber)
      ..writeByte(1)
      ..write(obj.denomination)
      ..writeByte(2)
      ..write(obj.checkedAt)
      ..writeByte(3)
      ..write(obj.resultStatus)
      ..writeByte(4)
      ..write(obj.drawNumber)
      ..writeByte(5)
      ..write(obj.drawDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
