import 'package:hive/hive.dart';

part 'prize_entry_model.g.dart';

@HiveType(typeId: 5)
class PrizeEntry extends HiveObject {
  @HiveField(0)
  late String position;

  @HiveField(1)
  late String number;

  @HiveField(2)
  late String amount;
}
