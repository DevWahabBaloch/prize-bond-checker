import 'package:hive/hive.dart';

part 'listing_model.g.dart';

@HiveType(typeId: 4)
class Listing extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String sellerName;

  @HiveField(2)
  late String sellerPhone;

  @HiveField(3)
  late String denomination;

  @HiveField(4)
  late int quantity;

  @HiveField(5)
  late double price;

  @HiveField(6)
  late String location;

  @HiveField(7)
  late DateTime postedDate;

  @HiveField(8)
  late bool isActive;
}
