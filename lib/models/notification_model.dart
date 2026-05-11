import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 3)
class NotificationModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late int typeIndex;

  @HiveField(2)
  late String title;

  @HiveField(3)
  late String body;

  @HiveField(4)
  late DateTime timestamp;

  @HiveField(5)
  late bool isRead;
}
