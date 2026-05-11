import 'package:hive/hive.dart';

part 'draw_result_model.g.dart';

@HiveType(typeId: 0)
class DrawResult extends HiveObject {
  @HiveField(0)
  late String drawNumber;

  @HiveField(1)
  late String denomination;

  @HiveField(2)
  late String drawDate;

  @HiveField(3)
  late String city;

  @HiveField(4)
  late String status;

  @HiveField(5)
  late int daysLeft;

  @HiveField(6)
  late String firstPrize;

  @HiveField(7)
  late String firstPrizeAmount;

  @HiveField(8)
  String? secondPrize;

  @HiveField(9)
  String? secondPrizeAmount;

  @HiveField(10)
  String? thirdPrize;

  @HiveField(11)
  String? thirdPrizeAmount;

  @HiveField(12)
  late String totalPrizes;

  @HiveField(13)
  late DateTime seededAt;
}
