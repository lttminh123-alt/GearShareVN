import 'package:gearshare_vn/admin/category.dart';

// ==================== EVENT CLASSES ====================
class FavoriteChangedEvent {
  final Drink drink;
  final bool isLiked;

  FavoriteChangedEvent({required this.drink, required this.isLiked});
}

// ==================== EVENT BUS ====================
class FavoriteEventBus {
  static final FavoriteEventBus _instance = FavoriteEventBus._internal();

  factory FavoriteEventBus() {
    return _instance;
  }

  FavoriteEventBus._internal();

  final List<Function(FavoriteChangedEvent)> _listeners = [];

  void subscribe(Function(FavoriteChangedEvent) callback) {
    _listeners.add(callback);
  }

  void unsubscribe(Function(FavoriteChangedEvent) callback) {
    _listeners.remove(callback);
  }

  void emit(FavoriteChangedEvent event) {
    for (var listener in _listeners) {
      listener(event);
    }
  }
}
