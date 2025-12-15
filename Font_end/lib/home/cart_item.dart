import '../admin/category.dart';

class CartItem {
  final Drink drink;
  final Option? option;
  int quantity;

  CartItem({required this.drink, this.option, this.quantity = 1});
}
