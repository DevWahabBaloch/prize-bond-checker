// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 6;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile()
      ..id = fields[0] as String
      ..firstName = fields[1] as String
      ..lastName = fields[2] as String
      ..mobile = fields[3] as String
      ..email = fields[4] as String
      ..pinHash = fields[5] as String
      ..address = fields[6] as String
      ..city = fields[7] as String
      ..role = fields[8] as String
      ..isApproved = fields[9] as bool
      ..registeredAt = fields[10] as DateTime
      ..isRejected = fields[11] == null ? false : fields[11] as bool;
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.firstName)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.mobile)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.pinHash)
      ..writeByte(6)
      ..write(obj.address)
      ..writeByte(7)
      ..write(obj.city)
      ..writeByte(8)
      ..write(obj.role)
      ..writeByte(9)
      ..write(obj.isApproved)
      ..writeByte(10)
      ..write(obj.registeredAt)
      ..writeByte(11)
      ..write(obj.isRejected);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
