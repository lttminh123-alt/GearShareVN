import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'user_manager_page.dart';
import 'order_manager_page.dart';
import '../home/profile_page.dart';
import 'AddProductPage.dart';

class AdminMainApp extends StatefulWidget {
  const AdminMainApp({super.key});

  @override
  State<AdminMainApp> createState() => _AdminMainAppState();
}

class _AdminMainAppState extends State<AdminMainApp> {
  int _index = 0;
  late AdminPageState _adminPageState;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminPage(
        onStateCreated: (state) {
          _adminPageState = state;
        },
      ),
      const UserManagerPage(),
      const OrderManagerPage(),
      const ProfilePage(),
    ];

    Widget navItem({
      required IconData icon,
      required String label,
      required int idx,
    }) {
      return GestureDetector(
        onTap: () => setState(() => _index = idx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _index == idx ? Color(0xFF0F8B74) : Colors.grey),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _index == idx ? Color(0xFF0F8B74) : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: pages[_index],
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 0,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  navItem(icon: Icons.home, label: "Trang chủ", idx: 0),
                  navItem(
                    icon: Icons.manage_accounts,
                    label: "Người dùng",
                    idx: 1,
                  ),
                  SizedBox(width: 56),
                  navItem(icon: Icons.assignment, label: "Đơn hàng", idx: 2),
                  navItem(icon: Icons.person, label: "Hồ sơ", idx: 3),
                ],
              ),
            ),
          ),
          Positioned(
            top: -28, // điều chỉnh cho FAB “lơ lửng” dính sát thanh dưới
            left: MediaQuery.of(context).size.width / 2 - 28, // căn giữa
            child: FloatingActionButton(
              backgroundColor: Color(0xFF0F8B74),
              child: const Icon(Icons.add, size: 30, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddProductPage()),
                ).then((_) => _adminPageState.fetchProducts());
              },
            ),
          ),
        ],
      ),
    );
  }
}
