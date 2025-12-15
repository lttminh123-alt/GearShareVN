import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class OrderManagerPage extends StatefulWidget {
  const OrderManagerPage({super.key});

  @override
  State<OrderManagerPage> createState() => _OrderManagerPageState();
}

class _OrderManagerPageState extends State<OrderManagerPage> {
  List orders = [];
  bool isLoading = true;
  String? authToken;
  Timer? _refreshTimer;

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:5000';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetch();
    // Tự động làm mới mỗi 2 giây để đồng bộ thời gian thực
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) {
        fetchOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTokenAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString("token");
    if (authToken != null) {
      await fetchOrders();
    } else {
      showMsg("Chưa đăng nhập ❌");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => isLoading = true);
    }

    try {
      final url = Uri.parse('${getBaseUrl()}/api/orders/all');
      final response = await http
          .get(url, headers: {'Authorization': 'Bearer $authToken'})
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            orders = jsonDecode(response.body);
          });
        }
      } else if (response.statusCode == 403) {
        if (!silent) {
          showMsg("Không có quyền truy cập ❌");
        }
      } else {
        if (!silent) {
          showMsg("Không thể tải đơn hàng ❌");
        }
      }
    } catch (e) {
      if (!silent) {
        showMsg("Lỗi kết nối: $e ❌");
      }
    }

    if (!silent && mounted) {
      setState(() => isLoading = false);
    }
  }

  void showMsg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Hiển thị dialog nhập số ngày giao hàng
  Future<void> showConfirmDialog(String orderId, String orderNumber) async {
    int deliveryDays = 1;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận đơn hàng"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Đơn hàng: $orderNumber"),
              const SizedBox(height: 16),
              const Text(
                "Nhập số ngày giao hàng:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Ví dụ: 3",
                  suffixText: "ngày",
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    deliveryDays = parsed;
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                "Ngày giao hàng dự kiến: ${_calculateDeliveryDate(deliveryDays)}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, deliveryDays),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await confirmOrder(orderId, result);
    }
  }

  String _calculateDeliveryDate(int days) {
    final date = DateTime.now().add(Duration(days: days));
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> confirmOrder(String orderId, int deliveryDays) async {
    if (authToken == null) {
      showMsg("Chưa đăng nhập ❌");
      return;
    }

    try {
      final url = Uri.parse('${getBaseUrl()}/api/orders/$orderId/confirm');
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({"deliveryDays": deliveryDays}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        showMsg("✅ ${data['message']}");
        fetchOrders();
      } else {
        final msg =
            jsonDecode(response.body)['message'] ?? "Không thể xác nhận";
        showMsg("❌ $msg");
      }
    } catch (e) {
      showMsg("Lỗi kết nối: $e ❌");
    }
  }

  // Hiển thị dialog xác nhận hủy
  Future<void> showCancelDialog(String orderId, String orderNumber) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hủy đơn hàng"),
        content: Text("Bạn có chắc muốn hủy đơn $orderNumber ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Không"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hủy đơn"),
          ),
        ],
      ),
    );

    if (result == true) {
      await cancelOrder(orderId);
    }
  }

  Future<void> cancelOrder(String orderId) async {
    if (authToken == null) {
      showMsg("Chưa đăng nhập ❌");
      return;
    }

    try {
      final url = Uri.parse('${getBaseUrl()}/api/orders/$orderId/cancel');
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        showMsg("✅ ${data['message']}");
        fetchOrders();
      } else {
        final msg = (response.body.isNotEmpty)
            ? jsonDecode(response.body)['message'] ?? "Không thể hủy đơn"
            : "Không thể hủy đơn";
        showMsg("❌ $msg");
      }
    } catch (e) {
      showMsg("Lỗi kết nối: $e ❌");
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Chờ giao hàng';
      case 'renting':
        return 'Đang thuê';
      case 'returned':
        return 'Đã giao';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty; // đang chờ
      case 'confirmed':
        return Icons.check_circle; // đã xác nhận
      case 'renting':
        return Icons.directions_car; // đang thuê
      case 'returned':
        return Icons.reply; // đã trả
      case 'cancelled':
        return Icons.cancel; // bị hủy
      default:
        return Icons.help_outline; // icon mặc định
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'renting':
        return Colors.green;
      case 'returned':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0F8B74),
        title: const Text("Quản lý đơn hàng"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchOrders,
            tooltip: "Làm mới",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Không có đơn hàng nào",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: orders.length,
                itemBuilder: (context, i) {
                  final order = orders[i];
                  final status = order['status'] ?? 'pending';
                  final isPending = status == 'pending';
                  final userName = order['userId']?['username'] ?? 'N/A';
                  final userPhone = order['userId']?['phone_number'] ?? 'N/A';
                  final orderNumber = order['orderNumber'] ?? 'N/A';
                  final totalAmount = order['totalAmount'] ?? 0;
                  final items = order['items'] as List? ?? [];
                  final createdAt = order['createdAt'] != null
                      ? DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(DateTime.parse(order['createdAt']))
                      : 'N/A';

                  final canCancel =
                      status == 'pending' || status == 'confirmed';
                  final cancelledBy = order['cancelledBy'];
                  final cancelledAt = order['cancelledAt'];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      collapsedShape: const RoundedRectangleBorder(
                        side: BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: getStatusColor(status).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          getStatusIcon(status),
                          color: getStatusColor(status),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        "Đơn hàng: $orderNumber",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Khách hàng: $userName",
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            "SĐT: $userPhone",
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            "Thời gian: $createdAt",
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor(status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              getStatusText(status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: getStatusColor(status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(color: Colors.black12),
                              const Text(
                                "Chi tiết đơn hàng:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...items.map((item) {
                                final productName =
                                    item['productName'] ?? 'N/A';
                                final quantity = item['quantity'] ?? 1;
                                final basePrice = item['basePrice'] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.shopping_bag,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "$productName x$quantity",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        "${VnFormat.format(basePrice * quantity)} VND",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Tổng tiền thuê:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    "${VnFormat.format(totalAmount)} VND",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (order['deliveryAddress'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "Địa chỉ: ${order['deliveryAddress']}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (order['note'] != null &&
                                  (order['note'] as String).isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Ghi chú: ${order['note']}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              // Hiển thị thông tin hủy đơn
                              if (cancelledBy != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cancel,
                                        color: Colors.red[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cancelledBy == 'admin'
                                                  ? 'Đơn hàng đã bị hủy bởi Admin'
                                                  : 'Khách hàng đã hủy đơn hàng này',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red[700],
                                              ),
                                            ),
                                            if (cancelledAt != null)
                                              Text(
                                                'Hủy lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(cancelledAt))}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.red[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (isPending) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text("Xác nhận đơn hàng"),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => showConfirmDialog(
                                      order['_id'],
                                      orderNumber,
                                    ),
                                  ),
                                ),
                              ],
                              if (canCancel) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.cancel),
                                    label: const Text("Hủy đơn hàng"),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => showCancelDialog(
                                      order['_id'],
                                      orderNumber,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
