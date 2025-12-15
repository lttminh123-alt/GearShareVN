import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Khởi tạo plugin toàn cục
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Hàm hiển thị thông báo local
Future<void> showLocalNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'demo_channel_id', // id của channel
    'Demo Notification', // tên channel
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  await notificationsPlugin.show(
    0, // id thông báo
    'Xin chào!', // tiêu đề
    'Đây là thông báo local trên Android.', // nội dung
    platformDetails,
  );
}
