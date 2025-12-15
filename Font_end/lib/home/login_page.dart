import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailPhoneCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> loginUser() async {
    final input = emailPhoneCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (input.isEmpty || password.isEmpty) {
      showSnack('Vui lòng nhập đầy đủ thông tin⚠️');
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = Uri.parse(getBaseUrl());
      final isEmail = input.contains('@');

      final body = isEmail
          ? {'email': input, 'password': password}
          : {'phone_number': input, 'password': password};

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // try to decode body safely
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        data = {};
      }

      if (res.statusCode == 200) {
        await saveUserData(data);
        showSnack('Đăng nhập thành công!✅');

        // determine role robustly
        final dynamic user = data['user'] ?? data['data'] ?? {};
        final role = (user != null && user['role'] != null)
            ? user['role']
            : 'user';

        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        showSnack(data['message'] ?? 'Sai tài khoản hoặc mật khẩu❌');
      }
    } catch (e) {
      showSnack('Không thể kết nối tới server.\nLỗi: $e🚫');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // token may be under different keys depending on backend
      String token = '';
      if (data.containsKey('token') && data['token'] != null) {
        token = data['token'].toString();
      } else if (data.containsKey('accessToken') &&
          data['accessToken'] != null) {
        token = data['accessToken'].toString();
      } else if (data['data'] != null && data['data']['token'] != null) {
        token = data['data']['token'].toString();
      }

      // user object may be in different shapes
      final dynamic user = data['user'] ?? data['data'] ?? data;

      String userId = '';
      if (user != null) {
        userId = (user['id'] ?? user['_id'] ?? '').toString();
      }

      final username = (user != null && user['username'] != null)
          ? user['username'].toString()
          : '';
      final email = (user != null && user['email'] != null)
          ? user['email'].toString()
          : '';
      final phone = (user != null && user['phone_number'] != null)
          ? user['phone_number'].toString()
          : '';
      final role = (user != null && user['role'] != null)
          ? user['role'].toString()
          : 'user';

      // walletBalance: make robust conversion
      double walletBalance = 0.0;
      try {
        final wb = (user != null) ? user['walletBalance'] : null;
        if (wb != null) {
          if (wb is num) {
            walletBalance = wb.toDouble();
          } else {
            walletBalance = double.tryParse(wb.toString()) ?? 0.0;
          }
        }
      } catch (_) {
        walletBalance = 0.0;
      }

      await prefs.setString('token', token);
      await prefs.setString('userId', userId);
      await prefs.setString('username', username);
      await prefs.setString('email', email);
      await prefs.setString('phone_number', phone);
      await prefs.setString('role', role);
      await prefs.setDouble('walletBalance', walletBalance);

      // optional: flag logged in
      await prefs.setBool('isLoggedIn', token.isNotEmpty);
    } catch (e) {
      // don't crash the app if saving fails; show debug print
      if (mounted) {
        showSnack('Lưu thông tin đăng nhập thất bại: $e');
      }
    }
  }

  String getBaseUrl() {
    const endpoint = '/api/users/login';

    if (kIsWeb) {
      return 'http://localhost:5000$endpoint';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000$endpoint';
    } else {
      return 'http://localhost:5000$endpoint';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F8B74),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('./assets/logo.jpg', height: 120),
              const Text(
                'GearShareVN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF02352B),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Chào mừng trở lại~!',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              // Email - Phone number
              TextField(
                controller: emailPhoneCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email hoặc Số điện thoại',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: passwordCtrl,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => isPasswordVisible = !isPasswordVisible);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),

              // Nút login
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF151515),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white70)
                      : const Text(
                          'Đăng nhập',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Nối đến form register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Chưa có tài khoản? "),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      "Đăng ký ngay!",
                      style: TextStyle(
                        color: Color(0xFF02352B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
