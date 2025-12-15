// ignore_for_file: file_names

import 'dart:io';
import 'package:gearshare_vn/admin/category.dart' hide getImageUrl;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_/cart_event.dart';
import '../utils/vn_format.dart';
import 'package:gearshare_vn/home/favorite_event_bus.dart';
import '../utils/image_helper.dart'; // ✅ THÊM IMPORT

class DetailProductPage extends StatefulWidget {
  final dynamic product;
  final bool isUser;

  const DetailProductPage({
    super.key,
    required this.product,
    this.isUser = false,
  });

  @override
  State<DetailProductPage> createState() => _DetailProductPageState();
}

class _DetailProductPageState extends State<DetailProductPage> {
  late TextEditingController nameCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController imageCtrl;
  late String category;

  final NumberFormat formatter = NumberFormat.decimalPattern('vi_VN');
  final List<String> categories = [
    "Đồ điện tử",
    "Đồ gia dụng",
    "Dụng cụ chụp ảnh",
  ];

  bool isLoading = false;
  String authToken = "";
  bool isEditing = false;

  bool isLiked = false;
  int likeCount = 0;

  @override
  void initState() {
    super.initState();

    // ✅ FIX: Xử lý null values từ product
    final name = getName(widget.product['name']);
    final price = formatPrice(widget.product['price']);
    final image = widget.product['image']?.toString() ?? "";

    nameCtrl = TextEditingController(text: name);
    priceCtrl = TextEditingController(text: VnFormat.format(price));

    priceCtrl.addListener(() {
      final raw = VnFormat.parse(priceCtrl.text).toString();
      final formatted = VnFormat.format(raw);

      if (priceCtrl.text != formatted) {
        priceCtrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });

    imageCtrl = TextEditingController(text: image);
    category = widget.product['category']?.toString() ?? "Đồ điện tử";
    loadToken();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString("token") ?? "";
    });

    await fetchProductDetail();
  }

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:5000';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    if (Platform.isIOS) return 'http://localhost:5000';
    return 'http://localhost:5000';
  }

  // ==================== THÊM VÀO Đơn hàng ====================
  Future<void> addToCart({int quantity = 1, String optionName = ""}) async {
    if (authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bạn cần đăng nhập để thêm vào Đơn hàng ❌"),
        ),
      );
      return;
    }

    final productId = widget.product['_id'] ?? widget.product['id'];
    final url = Uri.parse("${getBaseUrl()}/api/cart/update");

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "productId": productId,
          "optionName": optionName,
          "quantity": quantity,
          "action": "add",
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Đã thêm vào Đơn hàng ✅")));

        try {
          emitCartUpdated();
        } catch (_) {}
      } else {
        final msg = jsonDecode(response.body)['message'] ?? response.body;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Thêm thất bại: $msg ❌")));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi kết nối server: $e 🚫")));
    }
  }

  void showAddToCartDialog() {
    int selectedQty = 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thêm vào Đơn hàng"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Chọn số lượng"),
              const SizedBox(height: 12),
              DropdownButton<int>(
                value: selectedQty,
                items: List.generate(
                  10,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text("${i + 1}")),
                ),
                onChanged: (v) => setStateDialog(() => selectedQty = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              addToCart(quantity: selectedQty, optionName: "");
            },
            child: const Text("Thêm"),
          ),
        ],
      ),
    );
  }

  // ==================== LIKE / UNLIKE ====================
  Future<void> fetchProductDetail() async {
    try {
      final productId = widget.product['_id'] ?? widget.product['id'];
      final url = Uri.parse('${getBaseUrl()}/api/products/$productId');
      final headers = <String, String>{"Content-Type": "application/json"};
      if (authToken.isNotEmpty) headers["Authorization"] = "Bearer $authToken";

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final product = map['product'] as Map<String, dynamic>? ?? {};
        final likedByMe = map['likedByMe'] == true;

        setState(() {
          isLiked = likedByMe;
          likeCount = (product['likes'] as List<dynamic>?)?.length ?? 0;
          widget.product['likes'] = product['likes'];
        });
      }
    } catch (e) {
      print("❌ Lỗi thêm Yêu thích không thành công: $e");
    }
  }

  Future<void> toggleLike() async {
    if (authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bạn cần đăng nhập để yêu thích sản phẩm ❌"),
        ),
      );
      return;
    }

    final productId = widget.product['_id'] ?? widget.product['id'];
    final url = Uri.parse('${getBaseUrl()}/api/products/$productId/like');

    setState(() => isLoading = true);
    try {
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
      );
      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final map = jsonDecode(response.body);
        final liked = map['liked'] == true;
        final product = map['product'] as Map<String, dynamic>? ?? {};

        setState(() {
          isLiked = liked;
          likeCount =
              (product['likes'] as List<dynamic>?)?.length ??
              (liked ? likeCount + 1 : (likeCount - 1));
          widget.product['likes'] = product['likes'];
        });

        // ✅ PHÁT SỰ KIỆN THAY ĐỔI YÊU THÍCH
        final drink = Drink(
          id: productId,
          name: getName(widget.product['name']),
          price: widget.product['price'],
          image: getImageUrl(widget.product['image']),
          description: widget.product['description'] ?? "Không có mô tả",
          category: widget.product['category'] ?? "Khác",
          rating: widget.product['rating'] ?? 0,
        );

        FavoriteEventBus().emit(
          FavoriteChangedEvent(drink: drink, isLiked: liked),
        );
      } else {
        final msg = jsonDecode(response.body)['message'] ?? response.body;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: $msg")));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi kết nối server: $e")));
    }
  }

  // ==================== UPDATE + DELETE ====================
  Future<void> updateProduct() async {
    final name = nameCtrl.text.trim();
    final price = priceCtrl.text.trim();
    final image = imageCtrl.text.trim();

    if (name.isEmpty || price.isEmpty || image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin ⚠️")),
      );
      return;
    }

    if (authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chưa có token! Vui lòng đăng nhập ❌")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final productId = widget.product['_id'] ?? widget.product['id'];
      final url = Uri.parse('${getBaseUrl()}/api/products/$productId');

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "name": name,
          "price": VnFormat.parse(price),
          "category": category,
          "image": image,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật sản phẩm thành công ✅")),
        );
        setState(() => isEditing = false);
        Navigator.pop(context, true);
      } else {
        final msg = jsonDecode(response.body)['message'] ?? response.body;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi server: $msg ❌")));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi kết nối server: $e 🚫")));
    }
  }

  Future<void> deleteProduct() async {
    if (authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chưa có token! Vui lòng đăng nhập ❌")),
      );
      return;
    }

    final productId = widget.product['_id'] ?? widget.product['id'];
    final url = Uri.parse('${getBaseUrl()}/api/products/$productId');

    setState(() => isLoading = true);

    final response = await http.delete(
      url,
      headers: {"Authorization": "Bearer $authToken"},
    );

    setState(() => isLoading = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Xóa sản phẩm thành công 🗑️")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể xóa: ${response.body}")),
      );
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    imageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Sử dụng helper functions cho tất cả dữ liệu
    final imageUrl = getImageUrl(widget.product['image']);
    final name = getName(widget.product['name']);
    final price = formatPrice(widget.product['price']);
    final category_display = widget.product['category']?.toString() ?? "Khác";

    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết sản phẩm")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 80),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: isLoading ? null : toggleLike,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.grey[700],
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "$likeCount",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!isEditing) ...[
                infoBox("Tên sản phẩm", name),
                const SizedBox(height: 12),
                infoBox(
                  "Giá thuê",
                  "${VnFormat.format(price)}đ",
                  isPrice: true,
                ),
                const SizedBox(height: 12),
                infoBox("Danh mục", category_display),
                const SizedBox(height: 20),
                if (!widget.isUser)
                  mainButton(
                    "Chỉnh sửa",
                    Colors.blue,
                    () => setState(() => isEditing = true),
                  ),
              ] else ...[
                textField(nameCtrl, "Tên sản phẩm"),
                const SizedBox(height: 12),
                textField(priceCtrl, "Giá", isNumber: true),
                const SizedBox(height: 12),
                textField(imageCtrl, "Link ảnh"),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  value: category,
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!),
                  decoration: InputDecoration(
                    labelText: "Danh mục",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                mainButton(
                  "Cập nhật sản phẩm",
                  const Color(0xFF0F8B74),
                  isLoading ? null : updateProduct,
                ),
                const SizedBox(height: 12),
                outlineButton("Hủy", () => setState(() => isEditing = false)),
              ],
              const SizedBox(height: 24),
              if (!widget.isUser)
                mainButton(
                  "Xóa sản phẩm",
                  Colors.red,
                  isLoading ? null : deleteProduct,
                ),
              if (widget.isUser)
                mainButton(
                  "Thêm vào Đơn hàng",
                  Colors.green,
                  isLoading ? null : showAddToCartDialog,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoBox(String title, String value, {bool isPrice = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: isPrice ? Colors.red : Colors.black,
              fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget textField(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget mainButton(String text, Color color, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget outlineButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
