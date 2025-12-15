import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/vn_format.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final imageCtrl = TextEditingController();
  String category = "Đồ điện tử";

  final List<String> categories = [
    "Đồ điện tử",
    "Đồ gia dụng",
    "Dụng cụ chụp ảnh",
  ];

  bool isLoading = false;
  String authToken = "";

  @override
  void initState() {
    super.initState();

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

    loadToken();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString("token") ?? "";
    });
  }

  Future<void> addProduct() async {
    final name = nameCtrl.text.trim();
    final price = priceCtrl.text.trim();
    final image = imageCtrl.text.trim();

    if (name.isEmpty || price.isEmpty || image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin⚠️")),
      );
      return;
    }

    if (authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lỗi: Chưa có token! Hãy đăng nhập lại ❌"),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    String getBaseUrl() {
      if (kIsWeb) return 'http://localhost:5000';
      if (Platform.isAndroid) return 'http://10.0.2.2:5000';
      return 'http://localhost:5000';
    }

    try {
      final url = Uri.parse('${getBaseUrl()}/api/products/add');

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "name": name,
          "price": VnFormat.parse(price),
          "category": category,
          "image": image, // gửi URL trực tiếp
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Thêm sản phẩm thành công ✅")),
        );
        Navigator.pop(context);
      } else {
        String bodyMsg = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            bodyMsg = decoded['message'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi server: $bodyMsg ❌")));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi kết nối tới server: $e 🚫")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text("Thêm sản phẩm")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Tên sản phẩm",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Giá thuê",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: imageCtrl,
              decoration: InputDecoration(
                labelText: "Link ảnh",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              value: category,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => category = v as String),
              decoration: InputDecoration(
                labelText: "Danh mục",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : addProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F8B74),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white70)
                    : const Text(
                        'Thêm sản phẩm',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
