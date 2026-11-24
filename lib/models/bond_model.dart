import 'package:hive/hive.dart';

part 'bond_model.g.dart';

@HiveType(typeId: 1)
class Bond extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String number;

  @HiveField(2)
  late String denomination;

  @HiveField(3)
  late String status;

  @HiveField(4)
  late DateTime addedDate;

  @HiveField(5)
  DateTime? lastChecked;

  @HiveField(6)
  String? lastResult;

  @HiveField(7)
  DateTime? issueDate;

  @HiveField(8)
  String? issueCity;
}
