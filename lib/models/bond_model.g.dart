// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bond_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BondAdapter extends TypeAdapter<Bond> {
  @override
  final int typeId = 1;

  @override
  Bond read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bond()
      ..id = fields[0] as String
      ..number = fields[1] as String
      ..denomination = fields[2] as String
      ..status = fields[3] as String
      ..addedDate = fields[4] as DateTime
      ..lastChecked = fields[5] as DateTime?
      ..lastResult = fields[6] as String?
      ..issueDate = fields[7] as DateTime?
      ..issueCity = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, Bond obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.number)
      ..writeByte(2)
      ..write(obj.denomination)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.addedDate)
      ..writeByte(5)
      ..write(obj.lastChecked)
      ..writeByte(6)
      ..write(obj.lastResult)
      ..writeByte(7)
      ..write(obj.issueDate)
      ..writeByte(8)
      ..write(obj.issueCity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BondAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
