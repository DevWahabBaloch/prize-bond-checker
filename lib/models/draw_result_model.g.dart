// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draw_result_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DrawResultAdapter extends TypeAdapter<DrawResult> {
  @override
  final int typeId = 0;

  @override
  DrawResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DrawResult()
      ..drawNumber = fields[0] as String
      ..denomination = fields[1] as String
      ..drawDate = fields[2] as String
      ..city = fields[3] as String
      ..status = fields[4] as String
      ..daysLeft = fields[5] as int
      ..firstPrize = fields[6] as String
      ..firstPrizeAmount = fields[7] as String
      ..secondPrize = fields[8] as String?
      ..secondPrizeAmount = fields[9] as String?
      ..thirdPrize = fields[10] as String?
      ..thirdPrizeAmount = fields[11] as String?
      ..totalPrizes = fields[12] as String
      ..seededAt = fields[13] as DateTime;
  }

  @override
  void write(BinaryWriter writer, DrawResult obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.drawNumber)
      ..writeByte(1)
      ..write(obj.denomination)
      ..writeByte(2)
      ..write(obj.drawDate)
      ..writeByte(3)
      ..write(obj.city)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.daysLeft)
      ..writeByte(6)
      ..write(obj.firstPrize)
      ..writeByte(7)
      ..write(obj.firstPrizeAmount)
      ..writeByte(8)
      ..write(obj.secondPrize)
      ..writeByte(9)
      ..write(obj.secondPrizeAmount)
      ..writeByte(10)
      ..write(obj.thirdPrize)
      ..writeByte(11)
      ..write(obj.thirdPrizeAmount)
      ..writeByte(12)
      ..write(obj.totalPrizes)
      ..writeByte(13)
      ..write(obj.seededAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
