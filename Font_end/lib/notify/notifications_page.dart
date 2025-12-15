// notifications_page.dart
import 'package:flutter/material.dart';
import 'package:gearshare_vn/notify/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<NotificationItem> _notifications = [];
  final NotificationService _service = NotificationService();
  StreamSubscription<String>? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToNotifications(); // Lắng nghe TRƯỚC
    _loadNotifications(); // Load sau
  }

  Future<void> _loadNotifications() async {
    debugPrint('💾 Đang load thông báo từ storage...');
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('notifications');

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        setState(() {
          _notifications.clear();
          _notifications.addAll(
            jsonList.map((item) => NotificationItem.fromJson(item)).toList(),
          );
          _isLoading = false;
        });
        debugPrint('✅ Đã load ${_notifications.length} thông báo');
      } catch (e) {
        debugPrint('❌ Lỗi parse JSON: $e');
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(
      _notifications.map((item) => item.toJson()).toList(),
    );
    await prefs.setString('notifications', jsonString);
    debugPrint('💾 Đã lưu ${_notifications.length} thông báo');
  }

  void _listenToNotifications() {
    debugPrint('🔊 Bắt đầu lắng nghe thông báo...');

    _subscription = _service.stream.listen(
      (message) {
        debugPrint('📥 Nhận được: "$message"');
        if (!mounted) return;

        setState(() {
          _notifications.insert(
            0,
            NotificationItem(
              message: message,
              timestamp: DateTime.now(),
              isRead: false,
            ),
          );
        });

        // Lưu ngay khi có thông báo mới
        _saveNotifications();
      },
      onError: (err) => debugPrint('‼️ Lỗi stream: $err'),
      cancelOnError: false,
    );
  }

  Future<void> _refresh() async {
    debugPrint('🔄 Làm mới danh sách...');

    // Không cần cancel/reinit stream, chỉ cần refresh UI
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        // UI đã được refresh
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông báo"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _notifications.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text("Không có thông báo")),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return Dismissible(
                          key: Key('${notif.timestamp.millisecondsSinceEpoch}'),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            setState(() {
                              _notifications.removeAt(index);
                            });
                            _saveNotifications();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã xóa thông báo')),
                            );
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: notif.isRead
                                  ? Colors.grey
                                  : Colors.blue,
                              child: const Icon(
                                Icons.notifications,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              notif.message,
                              style: TextStyle(
                                fontWeight: notif.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_formatTime(notif.timestamp)),
                            onTap: () {
                              setState(() {
                                notif.isRead = true;
                              });
                              _saveNotifications();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả'),
        content: const Text('Bạn có chắc muốn xóa tất cả thông báo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _notifications.clear();
      });
      _saveNotifications();
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inSeconds < 60) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
    if (difference.inHours < 24) return '${difference.inHours} giờ trước';
    return '${difference.inDays} ngày trước';
  }
}

class NotificationItem {
  final String message;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        message: json['message'],
        timestamp: DateTime.parse(json['timestamp']),
        isRead: json['isRead'] ?? false,
      );
}
