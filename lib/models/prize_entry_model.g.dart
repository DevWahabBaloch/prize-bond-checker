// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prize_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrizeEntryAdapter extends TypeAdapter<PrizeEntry> {
  @override
  final int typeId = 5;

  @override
  PrizeEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrizeEntry()
      ..position = fields[0] as String
      ..number = fields[1] as String
      ..amount = fields[2] as String;
  }

  @override
  void write(BinaryWriter writer, PrizeEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.position)
      ..writeByte(1)
      ..write(obj.number)
      ..writeByte(2)
      ..write(obj.amount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrizeEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
