import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/category.dart';
import 'checkout.dart';
import '../admin/cart_/cart_event.dart';
// <-- import stream event

class CartPage extends StatefulWidget {
  final List<CartItem> cartList;
  final VoidCallback refresh;

  const CartPage({super.key, required this.cartList, required this.refresh});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool isLoading = false;
  String? token;
  int serverTotalAmount = 0;
  int serverItemCount = 0;

  // lưu ngày trả chỉ với phần ngày (year, month, day) để tránh lỗi timezone
  final Map<String, DateTime?> _returnDates = {};
  final String baseUrl = 'http://10.0.2.2:5000/api';

  StreamSubscription<bool>? _cartSub;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchCart();

    // Lắng nghe event để fetch lại cart khi có cập nhật từ các nơi khác (ví dụ DetailProductPage)
    try {
      _cartSub = cartUpdateStream.listen((_) {
        // nếu đang ở trên màn hình này thì fetch lại
        if (mounted) {
          fetchCartFromServer();
        }
      });
    } catch (e) {
      // nếu chưa có cart_event.dart thì không crash
      print("⚠️ Không thể subscribe cartUpdateStream: $e");
    }
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartList.length != widget.cartList.length) {
      setState(() {});
      widget.refresh();
    } else {
      bool changed = false;
      for (int i = 0; i < widget.cartList.length; i++) {
        if (i >= oldWidget.cartList.length) {
          changed = true;
          break;
        }
        final a = widget.cartList[i];
        final b = oldWidget.cartList[i];
        if (a.quantity != b.quantity ||
            a.option?.name != b.option?.name ||
            a.drink.id != b.drink.id) {
          changed = true;
          break;
        }
      }
      if (changed) {
        setState(() {});
        widget.refresh();
      }
    }
  }

  Future<void> _loadTokenAndFetchCart() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");

    if (token != null) {
      await fetchCartFromServer();
    } else {
      print("⚠️ Không tìm thấy token");
    }
  }

  Future<void> fetchCartFromServer() async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cart'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          serverTotalAmount = data['totalAmount'] ?? 0;
          serverItemCount = data['itemCount'] ?? 0;
        });

        if (data['items'] != null && data['items'].isNotEmpty) {
          _syncCartFromServer(data['items']);
        } else {
          widget.cartList.clear();
          widget.refresh();
        }

        print(
          "✅ Đã tải Đơn hàng: $serverItemCount items, $serverTotalAmount VND",
        );
      } else {
        print("❌ Lỗi lấy Đơn hàng: ${response.statusCode}");
        _showErrorSnackBar("Không thể tải Đơn hàng");
      }
    } catch (e) {
      print("⚠️ Lỗi kết nối server: $e");
      _showErrorSnackBar("Lỗi kết nối server");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _syncCartFromServer(List<dynamic> serverItems) {
    widget.cartList.clear();

    print("🔄 Bắt đầu đồng bộ ${serverItems.length} items từ server");

    for (var item in serverItems) {
      try {
        print("📦 Processing item: $item");

        String? productId;
        if (item['productId'] is String) {
          productId = item['productId'];
        } else if (item['productId'] is Map) {
          productId = item['productId']['_id'];
        }

        final drink = Drink(
          id: productId ?? '',
          name: item['productName'] ?? '',
          image: item['productImage'] ?? '',
          price: (item['basePrice'] is int)
              ? item['basePrice']
              : int.tryParse(item['basePrice'].toString()) ?? 0,
          rating: 0.0,
          category: '',
          description: '',
        );

        Option? option;
        if (item['selectedOption'] != null &&
            item['selectedOption']['name'] != null &&
            item['selectedOption']['name'].toString().isNotEmpty) {
          option = Option(
            name: item['selectedOption']['name'].toString(),
            extraPrice: (item['selectedOption']['extraPrice'] is int)
                ? item['selectedOption']['extraPrice']
                : int.tryParse(
                        item['selectedOption']['extraPrice'].toString(),
                      ) ??
                      0,
          );
        }

        final cartItem = CartItem(
          drink: drink,
          option: option,
          quantity: (item['quantity'] is int)
              ? item['quantity']
              : int.tryParse(item['quantity'].toString()) ?? 1,
        );

        widget.cartList.add(cartItem);

        // --- SỬA: parse returnDate an toàn, lưu chỉ (year,month,day)
        if (item['returnDate'] != null &&
            (item['returnDate'] as String).isNotEmpty) {
          try {
            final parsed = DateTime.tryParse(item['returnDate']);
            if (parsed != null) {
              // đảm bảo convert về local rồi chỉ lấy phần ngày
              final local = parsed.toLocal();
              _returnDates[productId ?? ''] = DateTime(
                local.year,
                local.month,
                local.day,
              );
            } else {
              // fallback: next day (year-month-day)
              final fallback = DateTime.now().add(const Duration(days: 1));
              _returnDates[productId ?? ''] = DateTime(
                fallback.year,
                fallback.month,
                fallback.day,
              );
            }
          } catch (_) {
            final fallback = DateTime.now().add(const Duration(days: 1));
            _returnDates[productId ?? ''] = DateTime(
              fallback.year,
              fallback.month,
              fallback.day,
            );
          }
        } else {
          final defaultDate = DateTime.now().add(const Duration(days: 1));
          _returnDates[productId ?? ''] = DateTime(
            defaultDate.year,
            defaultDate.month,
            defaultDate.day,
          );
        }

        print("✅ Đã thêm: ${drink.name} x ${cartItem.quantity}");
      } catch (e) {
        print("❌ Lỗi khi parse item: $e");
        print("❌ Item data: $item");
      }
    }

    print("✅ Đồng bộ xong! Tổng: ${widget.cartList.length} items");
    widget.refresh();
  }

  Future<void> increaseQuantity(CartItem item) async {
    final oldQuantity = item.quantity;

    setState(() {
      item.quantity++;
    });
    widget.refresh();

    final success = await updateCartOnServer(item);

    if (!success) {
      setState(() {
        item.quantity = oldQuantity;
      });
      widget.refresh();
    }
  }

  Future<void> decreaseQuantity(CartItem item) async {
    if (item.quantity > 1) {
      final oldQuantity = item.quantity;

      setState(() {
        item.quantity--;
      });
      widget.refresh();

      final success = await updateCartOnServer(item);

      if (!success) {
        setState(() {
          item.quantity = oldQuantity;
        });
        widget.refresh();
      }
    } else {
      await removeFromCart(item);
    }
  }

  Future<bool> updateCartOnServer(CartItem item) async {
    if (token == null || item.drink.id == null) {
      _showErrorSnackBar("Thiếu thông tin xác thực");
      return false;
    }

    try {
      final returnDate = _returnDates[item.drink.id];
      final body = {
        'productId': item.drink.id,
        'optionName': item.option?.name ?? '',
        'quantity': item.quantity,
      };
      if (returnDate != null) {
        // gửi dạng ISO của ngày ở thời gian local 00:00,
        // hoặc bạn có thể dùng toUtc() tuỳ server; ở đây gửi local date ở 00:00 kiểu ISO w/o Z.
        // Quan trọng: server nên hiểu đây là date-only hoặc xử lý timezone phù hợp.
        body['returnDate'] = DateTime(
          returnDate.year,
          returnDate.month,
          returnDate.day,
        ).toIso8601String();
      }

      final response = await http.put(
        Uri.parse('$baseUrl/cart/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['cart'] != null) {
          setState(() {
            serverTotalAmount =
                data['cart']['totalAmount'] ?? serverTotalAmount;
            serverItemCount = data['cart']['itemCount'] ?? serverItemCount;
          });
          if (data['cart']['items'] != null) {
            _syncCartFromServer(data['cart']['items']);
          }
        }
        // Phát event để các nơi khác cập nhật nếu cần
        try {
          emitCartUpdated();
        } catch (_) {}
        print("✅ Đã cập nhật số lượng: ${item.quantity}");
        return true;
      } else {
        print("❌ Lỗi cập nhật: ${response.statusCode}");
        _showErrorSnackBar("Không thể cập nhật số lượng");
        return false;
      }
    } catch (e) {
      print("⚠️ Lỗi kết nối: $e");
      _showErrorSnackBar("Lỗi kết nối server");
      return false;
    }
  }

  Future<void> removeFromCart(CartItem item) async {
    if (token == null || item.drink.id == null) {
      _showErrorSnackBar("Thiếu thông tin xác thực");
      return;
    }

    final itemIndex = widget.cartList.indexOf(item);
    final removedItem = item;

    setState(() {
      widget.cartList.remove(item);
    });
    widget.refresh();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': item.drink.id,
          'optionName': item.option?.name ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          serverTotalAmount = data['cart']['totalAmount'] ?? 0;
          serverItemCount = data['cart']['itemCount'] ?? 0;
        });

        // Phát event
        try {
          emitCartUpdated();
        } catch (_) {}

        print("✅ Đã xóa sản phẩm: ${item.drink.name}");
        _showSuccessSnackBar("Đã xóa sản phẩm khỏi Đơn hàng");
      } else {
        print("❌ Lỗi xóa: ${response.statusCode}");
        setState(() {
          widget.cartList.insert(itemIndex, removedItem);
        });
        widget.refresh();
        _showErrorSnackBar("Không thể xóa sản phẩm");
      }
    } catch (e) {
      print("⚠️ Lỗi kết nối: $e");
      setState(() {
        widget.cartList.insert(itemIndex, removedItem);
      });
      widget.refresh();
      _showErrorSnackBar("Lỗi kết nối server");
    }
  }

  Future<void> clearCart() async {
    if (token == null) {
      _showErrorSnackBar("Thiếu thông tin xác thực");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận"),
        content: const Text("Bạn có chắc muốn xóa toàn bộ Đơn hàng?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Xóa",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final oldCartList = List<CartItem>.from(widget.cartList);
    final oldTotalAmount = serverTotalAmount;
    final oldItemCount = serverItemCount;

    setState(() {
      widget.cartList.clear();
      serverTotalAmount = 0;
      serverItemCount = 0;
    });
    widget.refresh();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/clear'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Đã xóa toàn bộ Đơn hàng");
        _showSuccessSnackBar("Đã xóa toàn bộ Đơn hàng");
        _returnDates.clear();

        // Phát event
        try {
          emitCartUpdated();
        } catch (_) {}
      } else {
        print("❌ Lỗi xóa: ${response.statusCode}");
        setState(() {
          widget.cartList.addAll(oldCartList);
          serverTotalAmount = oldTotalAmount;
          serverItemCount = oldItemCount;
        });
        widget.refresh();
        _showErrorSnackBar("Không thể xóa Đơn hàng");
      }
    } catch (e) {
      print("⚠️ Lỗi kết nối: $e");
      setState(() {
        widget.cartList.addAll(oldCartList);
        serverTotalAmount = oldTotalAmount;
        serverItemCount = oldItemCount;
      });
      widget.refresh();
      _showErrorSnackBar("Lỗi kết nối server");
    }
  }

  Future<void> _pickReturnDateAndUpdate(CartItem item) async {
    // ensure initial date is date-only (year,month,day)
    final current =
        _returnDates[item.drink.id] ??
        DateTime.now().add(const Duration(days: 1));
    final initial = DateTime(current.year, current.month, current.day);

    // firstDate as today date-only
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      // normalize picked to date-only (drop time)
      final normalized = DateTime(picked.year, picked.month, picked.day);

      final id = item.drink.id ?? '';
      if (id.isEmpty) {
        _showErrorSnackBar("Không xác định sản phẩm để lưu ngày trả");
      } else {
        setState(() {
          _returnDates[id] = normalized;
        });
        widget.refresh();
        await _updateReturnDateOnServer(item, normalized);
      }
    }
  }

  Future<void> _updateReturnDateOnServer(
    CartItem item,
    DateTime pickedDate,
  ) async {
    if (token == null || item.drink.id == null) {
      _showErrorSnackBar("Thiếu thông tin xác thực");
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/cart/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': item.drink.id,
          'optionName': item.option?.name ?? '',
          'quantity': item.quantity,
          // gửi ngày ở dạng date-only ISO (local 00:00)
          'returnDate': DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
          ).toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['cart'] != null) {
          setState(() {
            serverTotalAmount =
                data['cart']['totalAmount'] ?? serverTotalAmount;
            serverItemCount = data['cart']['itemCount'] ?? serverItemCount;
          });
          if (data['cart']['items'] != null) {
            _syncCartFromServer(data['cart']['items']);
          }
        }

        // Phát event
        try {
          emitCartUpdated();
        } catch (_) {}

        _showSuccessSnackBar("Đã cập nhật ngày thuê");
      } else {
        _showErrorSnackBar("Không thể cập nhật ngày thuê");
      }
    } catch (e) {
      _showErrorSnackBar("Lỗi kết nối server");
    }
  }

  Future<void> _handleCheckout(Map<String, dynamic> checkoutData) async {
    if (token == null) {
      Navigator.pop(context);
      _showErrorSnackBar("Thiếu thông tin xác thực");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'customerName': checkoutData['name'],
          'customerPhone': checkoutData['phone'],
          'deliveryAddress': checkoutData['address'],
          'note': checkoutData['note'],
          'paymentMethod': checkoutData['paymentMethod'],
          'totalAmount': checkoutData['totalAmount'],
        }),
      );

      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Xóa cart và reset state
        widget.cartList.clear();
        setState(() {
          serverTotalAmount = 0;
          serverItemCount = 0;
        });
        widget.refresh();

        // Đồng bộ cart với server
        try {
          emitCartUpdated();
        } catch (_) {}

        if (!mounted) return;

        // Hiển thị dialog đặt hàng thành công
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 40,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Đặt hàng thành công!",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Mã đơn hàng: ${data['order']?['orderNumber'] ?? 'N/A'}",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tổng tiền thuê: ${checkoutData['totalAmount']} VND",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Cảm ơn bạn đã thuê hàng! Chúng tôi sẽ liên hệ với bạn sớm nhất có thể.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Đóng"),
              ),
            ],
          ),
        );

        print("✅ Đặt hàng thành công");
      } else {
        print("❌ Lỗi đặt hàng: ${response.statusCode}");
        print("Response: ${response.body}");
        _showErrorSnackBar("Không thể đặt hàng. Vui lòng thử lại!");
      }
    } catch (e) {
      Navigator.pop(context);
      print("⚠️ Lỗi kết nối: $e");
      _showErrorSnackBar("Lỗi kết nối server");
    }
  }

  void _showCheckoutBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CheckoutBottomSheet(
        totalAmount: serverTotalAmount > 0
            ? serverTotalAmount
            : localTotalPrice,
        onCheckout: _handleCheckout,
      ),
    );
  }

  int get localTotalPrice {
    int sum = 0;
    for (var item in widget.cartList) {
      int optionPrice = item.option?.extraPrice ?? 0;
      sum += (item.drink.price + optionPrice) * item.quantity;
    }
    return sum;
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.cartList;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0F8B74),
        title: Text(
          "Đơn hàng (${items.length})",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: clearCart,
              tooltip: "Xóa toàn bộ",
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchCartFromServer,
            tooltip: "Làm mới",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Đơn hàng trống",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            )
          : Column(
              children: [
                // Header with totals
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color.fromARGB(150, 0, 0, 0),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              TextSpan(
                                text: "Lưu ý: ",
                                style: TextStyle(
                                  color: const Color.fromARGB(200, 255, 153, 0),
                                ),
                              ),
                              const TextSpan(text: "Tổng giá thuê sẽ "),
                              TextSpan(
                                text: "tăng 3% ",
                                style: TextStyle(color: Colors.red.shade400),
                              ),
                              const TextSpan(text: "cho mỗi ngày thuê thêm."),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Cart items list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      int optionPrice = item.option?.extraPrice ?? 0;
                      int unitPrice = item.drink.price + optionPrice;
                      final dt = _returnDates[item.drink.id];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product info row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        item.drink.image.startsWith('http') ||
                                            item.drink.image.startsWith(
                                              '/uploads',
                                            )
                                        ? Image.network(
                                            item.drink.image.startsWith('http')
                                                ? item.drink.image
                                                : 'http://10.0.2.2:5000${item.drink.image}',
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.image_not_supported,
                                                  size: 30,
                                                ),
                                          )
                                        : Image.asset(
                                            item.drink.image,
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Product details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.drink.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (item.option != null &&
                                            item.option!.name.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.option!.name,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        Text(
                                          "${VnFormat.format(unitPrice)} VND",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Tổng: ${VnFormat.format(unitPrice * item.quantity)} VND",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Quantity controls
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text('Số lượng:'),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                          size: 24,
                                        ),
                                        onPressed: () => decreaseQuantity(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "${item.quantity}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.green,
                                          size: 24,
                                        ),
                                        onPressed: () => increaseQuantity(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: () => removeFromCart(item),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text("Xóa đơn"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Date picker section
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.date_range,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        dt != null
                                            ? "Ngày trả: ${dt.day}/${dt.month}/${dt.year}"
                                            : "Chưa chọn ngày trả",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _pickReturnDateAndUpdate(item),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                      child: const Text(
                                        "Chọn",
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Checkout footer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 5,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Tổng tiền thuê:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${VnFormat.format(serverTotalAmount > 0 ? serverTotalAmount : localTotalPrice)} VND",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          onPressed: items.isEmpty
                              ? null
                              : _showCheckoutBottomSheet,
                          child: const Text(
                            "Thanh toán",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
