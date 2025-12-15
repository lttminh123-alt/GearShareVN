import 'package:flutter/material.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/category.dart';

class ProductDetailPage extends StatefulWidget {
  final Drink? drink;
  final String? productId;
  final List<CartItem> cartList;
  final List<Drink> favoriteList;
  final Set<String> favoriteIds;
  final VoidCallback refresh;

  const ProductDetailPage({
    super.key,
    this.drink,
    this.productId,
    required this.cartList,
    required this.favoriteList,
    required this.favoriteIds,
    required this.refresh,
    required String role,
  }) : assert(
         drink != null || productId != null,
         'Phải truyền hoặc drink hoặc productId',
       );

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int quantity = 1;
  Option? selectedOption;
  Drink? currentDrink;
  bool isLoading = false;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadToken();

    if (widget.drink != null) {
      currentDrink = widget.drink;
      _initializeOptions();
    } else if (widget.productId != null) {
      fetchProductDetail();
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString("token");
    });
  }

  void _initializeOptions() {
    if (currentDrink != null && currentDrink!.options.isNotEmpty) {
      selectedOption = currentDrink!.options.first;
    }
  }

  Future<void> fetchProductDetail() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/products/${widget.productId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentDrink = Drink.fromJson(data);
          _initializeOptions();
          isLoading = false;
        });
      } else {
        throw Exception('Không thể tải sản phẩm');
      }
    } catch (e) {
      print('❌ Lỗi: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải sản phẩm: $e')));
      }
    }
  }

  // ✅ Toggle yêu thích
  Future<void> toggleFavorite() async {
    if (currentDrink?.id == null || currentDrink!.id!.length != 24) {
      print("⚠️ Sản phẩm chưa có ID hợp lệ");
      return;
    }

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng đăng nhập để sử dụng tính năng này"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isFavorite = widget.favoriteIds.contains(currentDrink!.id);

    setState(() {
      if (isFavorite) {
        widget.favoriteIds.remove(currentDrink!.id);
        widget.favoriteList.removeWhere((d) => d.id == currentDrink!.id);
      } else {
        widget.favoriteIds.add(currentDrink!.id!);
        if (!widget.favoriteList.any((d) => d.id == currentDrink!.id)) {
          widget.favoriteList.add(currentDrink!);
        }
      }
    });

    final url = Uri.parse("http://10.0.2.2:5000/api/favorites/toggle");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"productId": currentDrink!.id}),
      );

      if (response.statusCode == 200) {
        print("✅ Cập nhật yêu thích thành công");
        widget.refresh();
      } else {
        print("❌ Lỗi đồng bộ: ${response.statusCode}");
        // Rollback
        setState(() {
          if (isFavorite) {
            widget.favoriteIds.add(currentDrink!.id!);
            if (!widget.favoriteList.any((d) => d.id == currentDrink!.id)) {
              widget.favoriteList.add(currentDrink!);
            }
          } else {
            widget.favoriteIds.remove(currentDrink!.id);
            widget.favoriteList.removeWhere((d) => d.id == currentDrink!.id);
          }
        });
      }
    } catch (e) {
      print("⚠️ Lỗi kết nối server: $e");
      // Rollback
      setState(() {
        if (isFavorite) {
          widget.favoriteIds.add(currentDrink!.id!);
          if (!widget.favoriteList.any((d) => d.id == currentDrink!.id)) {
            widget.favoriteList.add(currentDrink!);
          }
        } else {
          widget.favoriteIds.remove(currentDrink!.id);
          widget.favoriteList.removeWhere((d) => d.id == currentDrink!.id);
        }
      });
    }
  }

  // ✅ Thêm vào Đơn hàng qua API
  Future<void> addToCart() async {
    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng chọn số lượng ít nhất là 1"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (currentDrink?.id == null) {
      print("⚠️ Sản phẩm chưa có ID");
      return;
    }

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng đăng nhập để thêm vào Đơn hàng"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final url = Uri.parse("http://10.0.2.2:5000/api/cart/add");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "productId": currentDrink!.id,
          "quantity": quantity,
          "selectedOption": selectedOption != null
              ? {
                  "name": selectedOption!.name,
                  "extraPrice": selectedOption!.extraPrice,
                }
              : null,
        }),
      );

      // Đóng loading
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        print("✅ Đã thêm vào Đơn hàng thành công");

        // ✅ Cập nhật Đơn hàng local (optional, để UI mượt hơn)
        // final existingItem = widget.cartList.firstWhere(
        //   (item) =>
        //       item.drink.id == currentDrink!.id &&
        //       item.option?.name == selectedOption?.name,
        //   orElse: () => CartItem(
        //     drink: currentDrink!,
        //     option: selectedOption,
        //     quantity: 0,
        //   ),
        // );

        // setState(() {
        //   if (widget.cartList.contains(existingItem)) {
        //     existingItem.quantity += quantity;
        //   } else {
        //     widget.cartList.add(
        //       CartItem(
        //         drink: currentDrink!,
        //         option: selectedOption,
        //         quantity: quantity,
        //       ),
        //     );
        //   }
        // });
        final existingItemIndex = widget.cartList.indexWhere(
          (item) =>
              item.drink.id == currentDrink!.id &&
              ((item.option == null && selectedOption == null) ||
                  (item.option?.name == selectedOption?.name)),
        );

        setState(() {
          if (existingItemIndex != -1) {
            // Nếu đã có cùng sản phẩm và cùng option => cộng dồn số lượng
            widget.cartList[existingItemIndex].quantity += quantity;
          } else {
            // Nếu chưa có => thêm mới
            widget.cartList.add(
              CartItem(
                drink: currentDrink!,
                option: selectedOption,
                quantity: quantity,
              ),
            );
          }
        });

        widget.refresh();

        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Đã thêm ${currentDrink!.name} x$quantity vào Đơn hàng",
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: "Xem Đơn hàng",
              textColor: Colors.white,
              onPressed: () {
                // TODO: Navigate to cart page
              },
            ),
          ),
        );

        // Reset số lượng về 1
        setState(() => quantity = 1);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Lỗi không xác định');
      }
    } catch (e) {
      // Đóng loading nếu còn mở
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print("⚠️ Lỗi khi thêm vào Đơn hàng: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || currentDrink == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isFavorite =
        currentDrink!.id != null &&
        widget.favoriteIds.contains(currentDrink!.id);

    // ✅ Tính Tổng tiền thuê (giá sản phẩm + phụ phí option) * số lượng
    final extraPrice = selectedOption?.extraPrice ?? 0;
    final unitPrice = currentDrink!.price + extraPrice;
    final totalPrice = unitPrice * quantity;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📌 Ảnh sản phẩm
                    Stack(
                      children: [
                        Container(
                          color: Colors.white,
                          width: double.infinity,
                          child:
                              currentDrink!.image.startsWith('http') ||
                                  currentDrink!.image.startsWith('/uploads')
                              ? Image.network(
                                  currentDrink!.image.startsWith('http')
                                      ? currentDrink!.image
                                      : 'http://10.0.2.2:5000${currentDrink!.image}',
                                  height: 280,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported,
                                    size: 100,
                                  ),
                                )
                              : Image.asset(
                                  currentDrink!.image,
                                  height: 280,
                                  fit: BoxFit.contain,
                                ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 📌 Thông tin sản phẩm
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentDrink!.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${VnFormat.format(currentDrink!.price)} VND",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${currentDrink!.rating} | Đã bán 1.2k",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 📌 Tuỳ chọn
                    if (currentDrink!.options.isNotEmpty)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Chọn tuỳ chọn:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButton<Option>(
                              value: selectedOption,
                              isExpanded: true,
                              items: currentDrink!.options
                                  .map(
                                    (opt) => DropdownMenuItem<Option>(
                                      value: opt,
                                      child: Text(
                                        "${opt.name} ${opt.extraPrice > 0 ? "(+${VnFormat.format(opt.extraPrice)} VND)" : ""}",
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => selectedOption = value);
                              },
                            ),
                          ],
                        ),
                      ),

                    // 📌 Số lượng
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Số lượng:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  if (quantity > 1) setState(() => quantity--);
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "$quantity",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () => setState(() => quantity++),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 📌 Mô tả
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Mô tả sản phẩm",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          Text(
                            currentDrink!.description,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🔹 Thanh dưới cùng với Tổng tiền thuê
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // ✅ Hiển thị Tổng tiền thuê
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Tổng tiền thuê:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "${VnFormat.format(totalPrice)} VND",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // ❤️ Nút yêu thích
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: Colors.pink,
                          size: 32,
                        ),
                        onPressed: toggleFavorite,
                      ),
                      const SizedBox(width: 10),

                      // 🛒 Nút thêm Đơn hàng
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: addToCart,
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Thêm vào Đơn hàng",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
