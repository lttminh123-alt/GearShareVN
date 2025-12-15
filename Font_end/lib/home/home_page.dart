// ignore_for_file: unused_import

import 'dart:io';
import 'package:gearshare_vn/admin/DetailProductPage.dart';
import 'package:gearshare_vn/admin/category.dart' hide getImageUrl;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gearshare_vn/home/favorite_event_bus.dart';
import 'package:gearshare_vn/utils/image_helper.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RentHomePage extends StatefulWidget {
  const RentHomePage({
    super.key,
    required List<Drink> favoriteList,
    required List<CartItem> cartList,
    required void Function() refresh,
    required void Function() goToCart,
  });

  @override
  State<RentHomePage> createState() => _RentHomePageState();
}

class _RentHomePageState extends State<RentHomePage> {
  String selectedCategory = "Tất cả";
  List<dynamic> products = [];
  bool isLoading = false;
  String authToken = "";
  int? selectIndex;
  int? hoverMouse;
  TextEditingController searchController = TextEditingController();
  String searchText = "";

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

  Future<void> toggleLike(dynamic product) async {
    if (authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bạn cần đăng nhập để yêu thích sản phẩm ❌"),
        ),
      );
      return;
    }

    final productId = product['_id'] ?? product['id'];
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

      if (response.statusCode == 200) {
        final map = jsonDecode(response.body);
        final updatedProduct = map['product'] as Map<String, dynamic>? ?? {};

        setState(() {
          // Cập nhật lại product['likes'] cho sản phẩm này trong danh sách products
          int index = products.indexWhere(
            (p) => (p['_id'] ?? p['id']) == productId,
          );
          if (index != -1) {
            products[index]['likes'] = updatedProduct['likes'] ?? [];
          }
        });
      } else {
        final msg = jsonDecode(response.body)['message'] ?? response.body;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: $msg")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi kết nối server: $e")));
    } finally {
      setState(() => isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final filteredProducts = getFilteredProducts();

    return Scaffold(
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
        ],
      ),
      body: buildUserHome(filteredProducts),
    );
  }

  Widget buildUserHome(List<dynamic> list) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
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

          // Banner
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset("assets/banner.png"),
          ),

          // Danh mục
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

          // Danh sách sản phẩm
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
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200, // mỗi item tối đa 200px rộng
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio:
                        0.60, // vẫn có thể dùng tạm, nhưng sẽ ít cứng hơn
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final product = list[index];

                    // // Lấy danh sách likes hiện tại của sản phẩm
                    // final productLikes =
                    //     (product['likes'] as List<dynamic>?) ?? [];

                    // // Kiểm tra xem user đã like sản phẩm chưa
                    // final likedByMe =
                    //     authToken.isNotEmpty &&
                    //     productLikes.contains(authToken);

                    // // Số lượng like hiện tại
                    // final currentLikeCount = productLikes.length;

                    return MouseRegion(
                      onEnter: (_) {
                        setState(() {
                          hoverMouse = index;
                        });
                      },
                      onExit: (_) {
                        setState(() {
                          hoverMouse = null;
                        });
                      },
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectIndex = index;
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailProductPage(
                                product: product,
                                isUser: true,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() {
                                selectIndex = null;
                              });
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectIndex == index
                                  ? Colors.lightGreenAccent
                                  : Colors.grey.shade300,
                              width:
                                  (selectIndex == index || hoverMouse == index)
                                  ? 3
                                  : 0.7,
                            ),
                            boxShadow:
                                (selectIndex == index || hoverMouse == index)
                                ? [
                                    BoxShadow(
                                      color: Colors.lightGreen[100]!
                                          .withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.network(
                                    product['image'] ?? "",
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(
                                              product['category'],
                                            ),
                                            size: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            product['name'] ?? "Không rõ tên",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${VnFormat.format(product['price'] ?? 0)}đ",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 14,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          product['rating']?.toString() ??
                                              "4.9",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // // Nút Like trái tim đổi màu + số lượng
                                    // GestureDetector(
                                    //   onTap: () async {
                                    //     if (authToken.isEmpty) {
                                    //       ScaffoldMessenger.of(
                                    //         context,
                                    //       ).showSnackBar(
                                    //         const SnackBar(
                                    //           content: Text(
                                    //             "Bạn cần đăng nhập để yêu thích sản phẩm ❌",
                                    //           ),
                                    //         ),
                                    //       );
                                    //       return;
                                    //     }

                                    //     final productId =
                                    //         product['_id'] ?? product['id'];
                                    //     final url = Uri.parse(
                                    //       '${getBaseUrl()}/api/products/$productId/like',
                                    //     );

                                    //     setState(() => isLoading = true);

                                    //     try {
                                    //       final response = await http.put(
                                    //         url,
                                    //         headers: {
                                    //           "Content-Type":
                                    //               "application/json",
                                    //           "Authorization":
                                    //               "Bearer $authToken",
                                    //         },
                                    //       );

                                    //       if (response.statusCode == 200) {
                                    //         final map = jsonDecode(
                                    //           response.body,
                                    //         );
                                    //         final updatedProduct =
                                    //             map['product']
                                    //                 as Map<String, dynamic>? ??
                                    //             {};

                                    //         setState(() {
                                    //           // Cập nhật danh sách likes trong product hiện tại
                                    //           product['likes'] =
                                    //               updatedProduct['likes'] ?? [];
                                    //         });
                                    //       } else {
                                    //         final msg =
                                    //             jsonDecode(
                                    //               response.body,
                                    //             )['message'] ??
                                    //             response.body;
                                    //         ScaffoldMessenger.of(
                                    //           context,
                                    //         ).showSnackBar(
                                    //           SnackBar(
                                    //             content: Text("Lỗi: $msg"),
                                    //           ),
                                    //         );
                                    //       }
                                    //     } catch (e) {
                                    //       ScaffoldMessenger.of(
                                    //         context,
                                    //       ).showSnackBar(
                                    //         SnackBar(
                                    //           content: Text(
                                    //             "Lỗi kết nối server: $e",
                                    //           ),
                                    //         ),
                                    //       );
                                    //     } finally {
                                    //       setState(() => isLoading = false);
                                    //     }
                                    //   },
                                    //   child: Container(
                                    //     padding: const EdgeInsets.all(6),
                                    //     decoration: BoxDecoration(
                                    //       color: Colors.white.withOpacity(0.9),
                                    //       shape: BoxShape.circle,
                                    //     ),
                                    //     child: Row(
                                    //       mainAxisSize: MainAxisSize.min,
                                    //       children: [
                                    //         Icon(
                                    //           likedByMe
                                    //               ? Icons.favorite
                                    //               : Icons.favorite_border,
                                    //           color: likedByMe
                                    //               ? Colors.red
                                    //               : Colors.grey[700],
                                    //           size: 26,
                                    //         ),
                                    //         const SizedBox(width: 4),
                                    //         Text(
                                    //           "$currentLikeCount",
                                    //           style: const TextStyle(
                                    //             fontSize: 12,
                                    //             fontWeight: FontWeight.bold,
                                    //           ),
                                    //         ),
                                    //       ],
                                    //     ),
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
