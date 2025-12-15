// notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  StreamController<String>? _controller;
  final List<String> _pendingMessages = [];
  bool _isFlushing = false;
  bool _isDisposed = false;

  NotificationService._internal() {
    _initController();
  }

  void _initController() {
    _controller?.close();
    _controller = StreamController<String>.broadcast(
      onListen: () {
        debugPrint(
          '🎯 Stream có listener | Total: ${_controller?.hasListener}',
        );
        // Flush pending messages ngay khi listener attach
        _flushPendingMessages();
      },
      onCancel: () {
        debugPrint('💤 Listener bị cancel');
      },
    );
  }

  StreamController<String> get _safeController {
    if (_isDisposed) {
      throw Exception('🚫 NotificationService đã dispose!');
    }
    if (_controller == null || _controller!.isClosed) {
      debugPrint('⚠️ Stream null/closed! Reinitializing...');
      _initController();
    }
    return _controller!;
  }

  /// Lấy stream để listen thông báo
  Stream<String> get stream {
    // Flush pending messages ngay lập tức, không delay
    _flushPendingMessages();
    return _safeController.stream;
  }

  /// Gửi thông báo
  void sendNotification(String message) {
    if (_isDisposed) {
      debugPrint('🛑 NotificationService đã dispose, bỏ qua message: $message');
      return;
    }

    debugPrint('📤 Gửi thông báo: "$message"');

    // Thêm vào pending messages
    _pendingMessages.add(message);

    // Flush ngay nếu có listener
    if (_safeController.hasListener) {
      debugPrint('✅ Có listener - flush ngay');
      _flushPendingMessages();
    } else {
      debugPrint('📦 Chưa có listener - đợi khi có');
    }
  }

  /// Flush các message đang chờ tới listener
  void _flushPendingMessages() {
    if (_isFlushing || _pendingMessages.isEmpty) return;

    _isFlushing = true;
    debugPrint('🚀 Xử lý ${_pendingMessages.length} thông báo đang chờ');

    final messages = List<String>.from(_pendingMessages);
    _pendingMessages.clear();

    for (var msg in messages) {
      if (_controller != null && !_controller!.isClosed) {
        _controller!.add(msg);
      }
    }

    _isFlushing = false;
  }

  /// Dispose service
  void dispose() {
    _isDisposed = true;
    _controller?.close();
    _pendingMessages.clear();
    debugPrint('♻️ NotificationService đã dispose');
  }
}
