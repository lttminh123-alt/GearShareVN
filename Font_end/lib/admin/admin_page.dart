import 'dart:io';
import 'package:gearshare_vn/admin/DetailProductPage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/category.dart';

class AdminPage extends StatefulWidget {
  final List<Drink> productList;
  final Future<void> Function() refresh;
  final List<Drink> favoriteList;
  final List<CartItem> cartList;
  final void Function() goToCart;
  final Function(AdminPageState)? onStateCreated;

  const AdminPage({
    super.key,
    this.productList = const [],
    this.favoriteList = const [],
    this.cartList = const [],
    this.refresh = _defaultRefresh,
    this.goToCart = _defaultGoToCart,
    this.onStateCreated,
  });

  static Future<void> _defaultRefresh() async {}
  static void _defaultGoToCart() {}

  @override
  State<AdminPage> createState() => AdminPageState();
}

typedef AdminPageState = _AdminPageState;

class _AdminPageState extends State<AdminPage> {
  String selectedCategory = "Tất cả";
  List<dynamic> products = [];
  bool isLoading = false;
  bool isUser = false;
  String authToken = "";
  TextEditingController searchController = TextEditingController();
  String searchText = "";

  @override
  void initState() {
    super.initState();
    loadToken();
    loadRole();
    widget.onStateCreated?.call(this);
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

  List<dynamic> getFilteredProducts() {
    return products.where((item) {
      final matchCategory =
          selectedCategory == "Tất cả" || item['category'] == selectedCategory;

      final name = (item['name'] ?? "").toString().toLowerCase();
      final query = searchText.toLowerCase();

      final matchSearch = name.contains(query);

      return matchCategory && matchSearch;
    }).toList();
  }

  Future<void> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? 'user';
    setState(() {
      isUser = role == 'user';
    });
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
    final filteredProducts = getFilteredProducts();

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Image.asset("assets/logo_noWall.png", height: 190, width: 90),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications,
              color: Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/notification');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black, size: 28),
            onPressed: fetchProducts,
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.black,
            size: 28,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: buildAdminHome(filteredProducts),
    );
  }

  Widget buildAdminHome(List<dynamic> list) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() {
                searchText = value;
              });
            },
            decoration: InputDecoration(
              hintText: "Tìm sản phẩm...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.greenAccent[300],
            ),
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset("assets/banner.png"),
          ),

          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  [
                    "Tất cả",
                    "Đồ điện tử",
                    "Đồ gia dụng",
                    "Dụng cụ chụp ảnh",
                  ].map((cat) {
                    bool isSelected = cat == selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.brown[100] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0F8B74)
                                : Colors.grey,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getCategoryIcon(cat),
                              color: isSelected
                                  ? const Color(0xFF0F8B74)
                                  : Colors.grey,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF0F8B74)
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          isLoading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
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
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCategory,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final product = list[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: product['image'] != null
                                ? Image.network(
                                    product['image'],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                              ),
                                            ),
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image),
                                  ),
                            title: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    product['name'] ?? "Không rõ tên",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(product['category']),
                                    size: 18,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              "${(VnFormat.format(product['price'] ?? 0).toString())}đ",
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailProductPage(
                                  product: product,
                                  isUser: false,
                                ),
                              ),
                            ).then((_) => fetchProducts()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case "Đồ điện tử":
        return Icons.smartphone;
      case "Đồ gia dụng":
        return Icons.home_rounded;
      case "Dụng cụ chụp ảnh":
        return Icons.camera_alt_rounded;
      default:
        return Icons.all_out;
    }
  }
}
