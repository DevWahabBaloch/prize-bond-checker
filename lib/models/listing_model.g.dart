// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ListingAdapter extends TypeAdapter<Listing> {
  @override
  final int typeId = 4;

  @override
  Listing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Listing()
      ..id = fields[0] as String
      ..sellerName = fields[1] as String
      ..sellerPhone = fields[2] as String
      ..denomination = fields[3] as String
      ..quantity = fields[4] as int
      ..price = fields[5] as double
      ..location = fields[6] as String
      ..postedDate = fields[7] as DateTime
      ..isActive = fields[8] as bool;
  }

  @override
  void write(BinaryWriter writer, Listing obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sellerName)
      ..writeByte(2)
      ..write(obj.sellerPhone)
      ..writeByte(3)
      ..write(obj.denomination)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.price)
      ..writeByte(6)
      ..write(obj.location)
      ..writeByte(7)
      ..write(obj.postedDate)
      ..writeByte(8)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
