// lib/cart_event.dart
import 'dart:async';

/// Global cart update stream. Add `true` when cart changed so listeners refresh.
final StreamController<bool> cartUpdateController =
    StreamController<bool>.broadcast();

/// Helper sink/getter
Stream<bool> get cartUpdateStream => cartUpdateController.stream;
void emitCartUpdated() => cartUpdateController.add(true);
