import 'package:flutter/material.dart';
import 'package:gearshare_vn/notify/notification_service.dart';
import 'package:gearshare_vn/notify/notifications_page.dart';

class TestNotificationPage extends StatefulWidget {
  const TestNotificationPage({super.key});

  @override
  State<TestNotificationPage> createState() => _TestNotificationPageState();
}

class _TestNotificationPageState extends State<TestNotificationPage> {
  final NotificationService _service = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra thông báo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                debugPrint('--- TEST SINGLE NOTIFICATION ---');
                _service.sendNotification(
                  'Thông báo đơn lúc ${DateTime.now().toString().substring(11, 19)}',
                );
              },
              child: const Text('GỬI THÔNG BÁO NGAY'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                debugPrint('--- TEST MULTIPLE NOTIFICATIONS ---');
                for (int i = 1; i <= 5; i++) {
                  Future.delayed(Duration(seconds: i), () {
                    _service.sendNotification(
                      'Thông báo $i lúc ${DateTime.now().toString().substring(11, 19)}',
                    );
                  });
                }
              },
              child: const Text('GỬI 5 THÔNG BÁO LIÊN TIẾP'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
              child: const Text('MỞ TRANG THÔNG BÁO'),
            ),
          ],
        ),
      ),
    );
  }
}
