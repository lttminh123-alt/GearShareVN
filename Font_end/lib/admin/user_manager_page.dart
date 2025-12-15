import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserManagerPage extends StatefulWidget {
  const UserManagerPage({super.key});

  @override
  State<UserManagerPage> createState() => _UserManagerPageState();
}

class _UserManagerPageState extends State<UserManagerPage> {
  List users = [];
  bool isLoading = true;

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:5000';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  String _formatEmail(String? email) {
    if (email == null) return "-";
    return email.length > 20 ? "${email.substring(0, 20)}..." : email;
  }

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          users = jsonDecode(response.body);
        });
      } else {
        showMessage("Lỗi lấy danh sách user ❌");
      }
    } catch (e) {
      showMessage("Lỗi kết nối: $e ❌");
    }

    setState(() => isLoading = false);
  }

  Future<void> deleteUser(String id) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users/$id');
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        showMessage("Đã xóa người dùng thành công ✔");
        fetchUsers();
      } else {
        // show server message nếu có
        try {
          final body = jsonDecode(response.body);
          if (body != null && body['message'] != null) {
            showMessage(body['message']);
          } else {
            showMessage("Không thể xóa ❌");
          }
        } catch (_) {
          showMessage("Không thể xóa ❌");
        }
      }
    } catch (e) {
      showMessage("Lỗi kết nối: $e ❌");
    }
  }

  Future<void> toggleBlock(String id, bool currentBlocked) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users/$id');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'blocked': !currentBlocked}),
      );

      if (response.statusCode == 200) {
        showMessage(
          !currentBlocked ? "Đã chặn tài khoản" : "Đã bỏ chặn tài khoản",
        );
        fetchUsers();
      } else {
        try {
          final body = jsonDecode(response.body);
          if (body != null && body['message'] != null) {
            showMessage(body['message']);
          } else {
            showMessage("Không thể thay đổi trạng thái ❌");
          }
        } catch (_) {
          showMessage("Không thể thay đổi trạng thái ❌");
        }
      }
    } catch (e) {
      showMessage("Lỗi kết nối: $e ❌");
    }
  }

  Future<void> _confirmDelete(BuildContext context, user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Xác nhận xóa"),
        content: Text("Bạn chắc chắn muốn xóa ${user['username']}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      deleteUser(user['_id']);
    }
  }

  Future<void> showEditDialog(Map user) async {
    if (user['role'] == 'admin') {
      showMessage("Không thể chỉnh sửa ADMIN");
      return;
    }

    final _usernameCtrl = TextEditingController(text: user['username'] ?? "");
    final _phoneCtrl = TextEditingController(text: user['phone_number'] ?? "");
    final _passwordCtrl = TextEditingController();
    String role = user['role'] ?? "user";

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Chỉnh sửa người dùng"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: "Số điện thoại"),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: "Mật khẩu (để trống nếu không đổi)",
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Role: "),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(value: "user", child: Text("user")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          role = v;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("Email: ${user['email'] ?? '-'} (không đổi)"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop({
                'username': _usernameCtrl.text.trim(),
                'phone_number': _phoneCtrl.text.trim(),
                if (_passwordCtrl.text.trim().isNotEmpty)
                  'password': _passwordCtrl.text.trim(),
              });
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    ).then((result) async {
      if (result != null && result is Map) {
        await editUser(user['_id'], result);
      }
    });
  }

  Future<void> editUser(String id, Map payload) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users/$id');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        showMessage("Cập nhật thành công ✔");
        fetchUsers();
      } else {
        try {
          final body = jsonDecode(response.body);
          if (body != null && body['message'] != null) {
            showMessage(body['message']);
          } else {
            showMessage("Không thể cập nhật ❌");
          }
        } catch (_) {
          showMessage("Không thể cập nhật ❌");
        }
      }
    } catch (e) {
      showMessage("Lỗi kết nối: $e ❌");
    }
  }

  Widget buildUserTile(dynamic user) {
    final isBlocked = user['blocked'] == true;
    final isAdmin = user['role'] == 'admin';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isAdmin
                      ? Colors.orange
                      : (isBlocked ? Colors.grey : Colors.green),
                  child: Text(
                    (user['username'] ?? "U")[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),

                // Info area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NAME + ADMIN BADGE
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['username'] ?? "Không rõ tên",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "ADMIN",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // EMAIL (Text được cắt nếu > 20 ký tự)
                      Text(
                        "Email: ${_formatEmail(user['email'])}",
                        softWrap: true,
                        style: const TextStyle(fontSize: 14),
                      ),

                      // PHONE
                      Text(
                        "SĐT: ${user['phone_number'] ?? '-'}",
                        softWrap: true,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ACTION BUTTONS — cố định góc phải
          if (!isAdmin)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    tooltip: isBlocked ? "Bỏ chặn" : "Chặn",
                    icon: Icon(
                      isBlocked ? Icons.lock_open : Icons.lock,
                      color: isBlocked ? Colors.green : Colors.red,
                    ),
                    onPressed: () => toggleBlock(user['_id'], isBlocked),
                  ),
                  IconButton(
                    tooltip: "Sửa",
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => showEditDialog(user),
                  ),
                  IconButton(
                    tooltip: "Xóa",
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, user),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0F8B74),
        title: const Text("Quản lý người dùng"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchUsers),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text("Không có người dùng nào"))
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                return buildUserTile(users[i]);
              },
            ),
    );
  }
}
