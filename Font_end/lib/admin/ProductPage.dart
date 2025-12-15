// ignore: file_names
import 'dart:io';
import 'package:gearshare_vn/admin/DetailProductPage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List<dynamic> products = [];
  bool isLoading = false;
  String authToken = "";

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString("token") ?? "";
    });
    if (authToken.isNotEmpty) {
      fetchProducts();
    }
  }

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:5000';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  Future<void> fetchProducts() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse('${getBaseUrl()}/api/products');
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          products = decoded is List ? decoded : decoded['data'] ?? [];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Lỗi tải dữ liệu ❌")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi kết nối: $e 🚫")));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteProduct(String productId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: const Text("Bạn có chắc chắn muốn xóa sản phẩm này?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final url = Uri.parse(
                  '${getBaseUrl()}/api/products/$productId',
                );
                final response = await http.delete(
                  url,
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer $authToken",
                  },
                );

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Xóa sản phẩm thành công ✅")),
                  );
                  fetchProducts();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lỗi xóa sản phẩm ❌")),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Lỗi: $e 🚫")));
              }
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Danh sách sản phẩm"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchProducts),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Không có sản phẩm nào",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: fetchProducts,
                    child: const Text("Tải lại"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: products.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: product['image'] != null
                        ? Image.network(
                            product['image'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image),
                          ),
                    title: Text(product['name'] ?? "Không rõ tên"),
                    subtitle: Text(
                      "${VnFormat.format(product['price'] ?? 0)}đ",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text("Chỉnh sửa"),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailProductPage(
                                product: product,
                                isUser: true,
                              ),
                            ),
                          ).then((_) => fetchProducts()),
                        ),
                        PopupMenuItem(
                          child: const Text(
                            "Xóa",
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () =>
                              deleteProduct(product['_id'] ?? product['id']),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetailProductPage(product: product, isUser: true),
                      ),
                    ).then((_) => fetchProducts()),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F8B74),
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/add-product',
          ).then((_) => fetchProducts());
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
