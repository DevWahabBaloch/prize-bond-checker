import 'package:hive/hive.dart';

part 'user_profile_model.g.dart';

@HiveType(typeId: 6)
class UserProfile extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String firstName;

  @HiveField(2)
  late String lastName;

  @HiveField(3)
  late String mobile;

  @HiveField(4)
  late String email;

  @HiveField(5)
  late String pinHash;

  @HiveField(6)
  late String address;

  @HiveField(7)
  late String city;

  @HiveField(8)
  late String role;

  @HiveField(9)
  late bool isApproved;

  @HiveField(10)
  late DateTime registeredAt;

  @HiveField(11, defaultValue: false)
  bool isRejected = false;

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? mobile,
    String? email,
    String? pinHash,
    String? city,
    bool? isApproved,
    bool? isRejected,
  }) => UserProfile()
    ..id = id ?? this.id
    ..firstName = firstName ?? this.firstName
    ..lastName = lastName ?? this.lastName
    ..mobile = mobile ?? this.mobile
    ..email = email ?? this.email
    ..pinHash = pinHash ?? this.pinHash
    ..address = address
    ..city = city ?? this.city
    ..role = role
    ..isApproved = isApproved ?? this.isApproved
    ..registeredAt = registeredAt
    ..isRejected = isRejected ?? this.isRejected;

  String get fullName {
    final joined = '$firstName $lastName'.trim();
    return joined.isEmpty ? 'User' : joined;
  }
}
