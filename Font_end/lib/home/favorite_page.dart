import 'package:gearshare_vn/admin/category.dart';
import 'package:flutter/material.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'favorite_event_bus.dart';
import '../utils/image_helper.dart' hide getImageUrl; // ✅ THÊM IMPORT

class FavoritePage extends StatefulWidget {
  final List<Drink> favoriteList;
  final VoidCallback refresh;

  const FavoritePage({
    super.key,
    required this.favoriteList,
    required this.refresh,
  });

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<Drink> serverFavorites = [];
  bool isLoading = true;
  String? token;

  late Function(FavoriteChangedEvent) _favoriteListener;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFavorites();

    _favoriteListener = (event) {
      if (event.isLiked) {
        if (!serverFavorites.any((d) => d.id == event.drink.id)) {
          setState(() {
            serverFavorites.add(event.drink);
          });
        }
      } else {
        setState(() {
          serverFavorites.removeWhere((d) => d.id == event.drink.id);
        });
      }
    };

    FavoriteEventBus().subscribe(_favoriteListener);
  }

  @override
  void dispose() {
    FavoriteEventBus().unsubscribe(_favoriteListener);
    super.dispose();
  }

  Future<void> _loadTokenAndFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");

    if (token != null) {
      await fetchFavoritesFromServer();
    } else {
      setState(() => isLoading = false);
      print("⚠️ Chưa đăng nhập!");
    }
  }

  Future<void> fetchFavoritesFromServer() async {
    if (token == null) return;

    final url = Uri.parse("http://10.0.2.2:5000/api/favorites");

    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> favoritesJson = jsonDecode(response.body);

        setState(() {
          serverFavorites = favoritesJson
              .map((json) {
                // ✅ FIX: Xử lý null values từ server
                try {
                  return Drink.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  print("❌ Lỗi parse Drink: $e");
                  return null;
                }
              })
              .whereType<Drink>() // ✅ Loại bỏ null values
              .toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        print("❌ Lỗi server: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("❌ Lỗi kết nối: $e");
    }
  }

  Future<void> removeFavorite(Drink drink) async {
    if (token == null || drink.id == null) return;

    final url = Uri.parse("http://10.0.2.2:5000/api/favorites/toggle");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"productId": drink.id}),
      );

      if (response.statusCode == 200) {
        setState(() {
          serverFavorites.removeWhere((d) => d.id == drink.id);
          widget.favoriteList.removeWhere((d) => d.id == drink.id);
        });
        widget.refresh();
      }
    } catch (e) {
      print("❌ Lỗi xóa yêu thích: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yêu thích"),
        backgroundColor: Color(0xFF0F8B74),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : serverFavorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Chưa có sản phẩm yêu thích",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchFavoritesFromServer,
              child: ListView.builder(
                itemCount: serverFavorites.length,
                padding: EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final drink = serverFavorites[index];

                  // ✅ FIX: Sử dụng helper functions
                  final imageUrl = getImageUrl(drink.image);
                  final name = getName(drink.name);
                  final price = formatPrice(drink.price);

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    child: ListTile(
                      // ✅ FIX: Xử lý ảnh
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey[300],
                              child: Icon(Icons.image, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        "${VnFormat.format(price)} đ",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.favorite, color: Colors.red),
                        onPressed: () => removeFavorite(drink),
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/product-detail',
                          arguments: {
                            "product": {
                              "id": drink.id ?? "",
                              "name": name,
                              "price": price,
                              "image": imageUrl,
                              "description": drink.description,
                              "category": drink.category,
                              "rating": drink.rating,
                            },
                            "isUser": true,
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
