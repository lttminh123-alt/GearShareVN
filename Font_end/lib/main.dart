import 'package:gearshare_vn/admin/DetailProductPage.dart';
import 'package:gearshare_vn/admin/ProductPage.dart';
import 'package:gearshare_vn/admin/admin_main_app.dart';
import 'package:flutter/material.dart';
import 'package:gearshare_vn/admin/admin_stats_page.dart';
import 'package:gearshare_vn/admin/user_manager_page.dart';
import 'home/home_page.dart';
import 'home/favorite_page.dart';
import 'home/cart_page.dart';
import 'home/profile_page.dart';
import 'admin/category.dart';
import 'home/login_page.dart';
import 'home/register_page.dart';
import 'notify/notifications_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),

      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const RentShopApp(),
        '/admin': (_) => AdminMainApp(),
        '/product': (_) => const ProductPage(),
        '/notification': (context) => NotificationsPage(),

        '/user_manager': (_) => const UserManagerPage(),
        "/admin/stats": (_) => const AdminStatsPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/product-detail') {
          final args = settings.arguments as Map<String, dynamic>;

          return MaterialPageRoute(
            builder: (_) => DetailProductPage(
              product: args["product"],
              isUser: args["isUser"] ?? true,
            ),
          );
        }
        return null;
      },
    );
  }
}

class RentShopApp extends StatefulWidget {
  const RentShopApp({super.key});

  @override
  State<RentShopApp> createState() => _RentShopAppState();
}

class _RentShopAppState extends State<RentShopApp> {
  int _selectedIndex = 0;

  List<Drink> favoriteList = [];
  List<CartItem> cartList = [];

  void refresh() => setState(() {});
  void goToCart() => setState(() => _selectedIndex = 2);

  @override
  Widget build(BuildContext context) {
    final pages = [
      RentHomePage(
        favoriteList: favoriteList,
        cartList: cartList,
        refresh: refresh,
        goToCart: goToCart,
      ),
      FavoritePage(favoriteList: [], refresh: () {}),
      CartPage(cartList: cartList, refresh: refresh),
      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF0F8B74),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Trang chủ"),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Yêu thích",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Đơn hàng",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Hồ sơ"),
        ],
      ),
    );
  }
}
