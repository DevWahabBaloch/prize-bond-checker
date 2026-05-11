import 'package:hive/hive.dart';

part 'check_record_model.g.dart';

@HiveType(typeId: 2)
class CheckRecord extends HiveObject {
  @HiveField(0)
  late String bondNumber;

  @HiveField(1)
  late String denomination;

  @HiveField(2)
  late DateTime checkedAt;

  @HiveField(3)
  late String resultStatus;

  @HiveField(4)
  late String drawNumber;

  @HiveField(5)
  late String drawDate;
}
