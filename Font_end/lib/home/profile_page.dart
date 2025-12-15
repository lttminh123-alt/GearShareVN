import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'transaction_history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = '';
  String email = '';
  String phone = '';
  String role = 'user'; // default
  double walletBalance = 0;
  bool isOn = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  /// Load full user data từ SharedPreferences
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      username = prefs.getString('username') ?? 'Người dùng';
      email = prefs.getString('email') ?? 'user@example.com';
      phone = prefs.getString('phone_number') ?? '---';
      role = prefs.getString('role') ?? 'user';
      walletBalance = prefs.getDouble('walletBalance') ?? 0.0;
    });
  }

  void toggleSwitch() {
    setState(() => isOn = !isOn);
  }

  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF095244),
      appBar: AppBar(
        title: const Text(
          "Tài khoản",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F8B74),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          children: [
            _buildProfileHeader(),

            const SizedBox(height: 20),

            // =============================
            // QUYỀN USER
            // =============================
            if (role == "user") ...[
              _buildMenuItem(
                icon: Icons.history,
                title: "Lịch sử đơn hàng",
                color: Colors.grey,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionHistoryPage(),
                    ),
                  );
                },
              ),
            ],

            // =============================
            // QUYỀN ADMIN
            // =============================
            if (role == "admin") ...[
              _buildMenuItem(
                icon: Icons.admin_panel_settings,
                title: "Trang quản trị",
                color: Colors.orange,
                onTap: () {
                  Navigator.pushNamed(context, "/admin");
                },
              ),
              _buildMenuItem(
                icon: Icons.people_alt,
                title: "Quản lý người dùng",
                color: Colors.blueGrey,
                onTap: () {
                  Navigator.pushNamed(context, "/user_manager");
                },
              ),
              _buildMenuItem(
                icon: Icons.inventory,
                title: "Quản lý sản phẩm",
                color: Colors.green,
                onTap: () {
                  Navigator.pushNamed(context, "/product");
                },
              ),
              _buildMenuItem(
                icon: Icons.bar_chart,
                title: "Thống kê hệ thống",
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.pushNamed(context, "/admin/stats");
                },
              ),
            ],

            // =============================
            // SWITCH GIAO DIỆN
            // =============================
            buildThemeSwitch(),

            const SizedBox(height: 12),

            // =============================
            // LOGOUT
            // =============================
            logoutButton(),
          ],
        ),
      ),
    );
  }

  // =============================================
  // COMPONENT: Header Profile
  // =============================================
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 80, color: Color(0xFF0F8B74)),
          ),
          const SizedBox(height: 22),
          Text(
            username,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          // Text(
          //   "SĐT: $phone",
          //   style: const TextStyle(fontSize: 16, color: Colors.white70),
          // ),
          // const SizedBox(height: 6),
          if (role == "admin") ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.emoji_events, color: Colors.amberAccent, size: 22),
                SizedBox(width: 6),
                Text(
                  "Admin",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          // const SizedBox(height: 10),
          // Text(
          //   "Số dư: ${walletBalance.toStringAsFixed(0)} đ",
          //   style: const TextStyle(
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //     color: Colors.lightGreenAccent,
          //   ),
          // ),
        ],
      ),
    );
  }

  // =============================================
  // COMPONENT: Menu Item tile
  // =============================================
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  // =============================================
  // Giao diện sáng/tối
  // =============================================
  Widget buildThemeSwitch() {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: Icon(Icons.settings, color: Colors.grey),
        title: Text("Giao diện hệ thống"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOn ? Icons.wb_sunny : Icons.nightlight_round,
              color: isOn ? Colors.yellow : Colors.blueGrey,
            ),
            Switch(value: isOn, onChanged: (v) => toggleSwitch()),
          ],
        ),
      ),
    );
  }

  // =============================================
  // Logout Button
  // =============================================
  Widget logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: logout,
        icon: const Icon(Icons.logout_outlined),
        label: const Text("Đăng xuất"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
