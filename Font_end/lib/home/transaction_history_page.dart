import 'package:flutter/material.dart';
import 'package:gearshare_vn/utils/vn_format.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  bool isLoading = false;
  String? token;
  List<Transaction> transactions = [];
  String selectedFilter = 'Tất cả';
  Timer? _refreshTimer;

  final String baseUrl = 'http://10.0.2.2:5000/api';

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchTransactions();
    // Tự động làm mới mỗi 3 giây để đồng bộ thời gian thực
    _refreshTimer = Timer.periodic(Duration(seconds: 3), (_) {
      if (mounted) {
        fetchTransactions(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTokenAndFetchTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");

    if (token != null) {
      await fetchTransactions();
    }
  }

  // 📥 Lấy lịch sử giao dịch từ server
  Future<void> fetchTransactions({bool silent = false}) async {
    if (token == null) return;

    if (!silent) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/orders/my-orders'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> ordersList = data['orders'] ?? data;

        if (mounted) {
          setState(() {
            transactions = ordersList
                .map((json) => Transaction.fromJson(json))
                .toList();
          });
        }

        if (!silent) {
          print("✅ Đã tải ${transactions.length} giao dịch");
        }
      } else {
        print("❌ Lỗi lấy lịch sử: ${response.statusCode}");
        if (!silent) {
          _showErrorSnackBar("Không thể tải lịch sử giao dịch");
        }
      }
    } catch (e) {
      print("⚠️ Lỗi kết nối: $e");
      if (!silent) {
        _showErrorSnackBar("Lỗi kết nối server");
      }
    } finally {
      if (!silent && mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // 🔍 Lọc giao dịch theo trạng thái
  List<Transaction> get filteredTransactions {
    if (selectedFilter == 'Tất cả') {
      return transactions;
    }

    String statusToFilter = '';
    switch (selectedFilter) {
      case 'Chờ xác nhận':
        statusToFilter = 'pending';
        break;
      case 'Chờ giao hàng':
        statusToFilter = 'confirmed';
        break;
      case 'Đang thuê':
        statusToFilter = 'renting';
        break;
      case 'Đã giao':
        statusToFilter = 'returned';
        break;
      case 'Đã hủy':
        statusToFilter = 'cancelled';
        break;
    }

    return transactions.where((t) => t.status == statusToFilter).toList();
  }

  // 🗑️ Hủy đơn hàng
  Future<void> cancelOrder(String orderId) async {
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận hủy đơn"),
        content: const Text("Bạn có chắc muốn hủy đơn hàng này?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Không"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hủy đơn", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': 'Khách hàng hủy đơn'}),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar("Đã hủy đơn hàng thành công");
        await fetchTransactions(); // Refresh danh sách
      } else {
        _showErrorSnackBar("Không thể hủy đơn hàng");
      }
    } catch (e) {
      print("⚠️ Lỗi: $e");
      _showErrorSnackBar("Lỗi kết nối server");
    }
  }

  // ✅ Xác nhận đã nhận được hàng (chuyển sang "renting")
  Future<void> confirmReceivedOrder(String orderId) async {
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận đã nhận hàng"),
        content: const Text("Bạn đã nhận được hàng chưa?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Chưa"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Rồi", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/received'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar("Đã xác nhận nhận hàng");
        await fetchTransactions();
      } else {
        _showErrorSnackBar("Không thể xác nhận nhận hàng");
      }
    } catch (e) {
      print("⚠️ Lỗi: $e");
      _showErrorSnackBar("Lỗi kết nối server");
    }
  }

  // 🏁 Xác nhận trả hàng (chuyển sang "returned")
  Future<void> confirmReturnedOrder(String orderId) async {
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận trả hàng"),
        content: const Text("Bạn đã trả hàng chưa?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Chưa"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Rồi", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/returned'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar("Đã xác nhận trả hàng");
        await fetchTransactions();
      } else {
        _showErrorSnackBar("Không thể xác nhận trả hàng");
      }
    } catch (e) {
      print("⚠️ Lỗi: $e");
      _showErrorSnackBar("Lỗi kết nối server");
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Lịch sử đơn hàng",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF0F8B74),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchTransactions,
            tooltip: "Làm mới",
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Bộ lọc
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    "Lọc: ",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tất cả'),
                  _buildFilterChip('Chờ xác nhận'),
                  _buildFilterChip('Chờ giao hàng'),
                  _buildFilterChip('Đang thuê'),
                  _buildFilterChip('Đã giao'),
                  _buildFilterChip('Đã hủy'),
                ],
              ),
            ),
          ),

          // 📋 Danh sách giao dịch
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Chưa có đơn hàng nào",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = filteredTransactions[index];
                        return _buildTransactionCard(transaction);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // 🎨 Filter Chip
  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedFilter = label;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.brown[100],
        checkmarkColor: Color(0xFF0F8B74),
        labelStyle: TextStyle(
          color: isSelected ? Color(0xFF0F8B74) : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  // 🎨 Transaction Card
  Widget _buildTransactionCard(Transaction transaction) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTransactionDetail(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Mã đơn và trạng thái
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Mã đơn
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt,
                            color: Color(0xFF0F8B74),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            transaction.orderNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Badge nằm sát mép phải
                      SizedBox(
                        width:
                            constraints.maxWidth, // lấy full width để căn phải
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildStatusBadge(transaction.status),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    transaction.customerPhone,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),

              Row(
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getPaymentMethodText(transaction.paymentMethod),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),

              const Divider(height: 16),

              // Danh sách sản phẩm
              ...transaction.items
                  .take(2)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${item.name} ${item.optionName.isNotEmpty ? '(${item.optionName})' : ''} x${item.quantity}",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          Text(
                            "${VnFormat.format(item.totalPrice)} đ",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

              if (transaction.items.length > 2)
                Text(
                  "+ ${transaction.items.length - 2} sản phẩm khác",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const Divider(height: 16),

              // Footer: Tổng tiền thuê và ngày
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Tổng cộng:",
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Text(
                        "${VnFormat.format(transaction.totalAmount)} đ",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDate(transaction.date),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Text(
                        _formatTime(transaction.date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Status Badge
  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText;

    switch (status) {
      case 'pending':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        icon = Icons.hourglass_empty;
        displayText = 'Chờ xác nhận';
        break;
      case 'confirmed':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[700]!;
        icon = Icons.check_circle;
        displayText = 'Chờ giao hàng';
        break;
      case 'renting':
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[700]!;
        icon = Icons.local_shipping;
        displayText = 'Đang thuê';
        break;
      case 'returned':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        icon = Icons.check_circle_outline;
        displayText = 'Đã giao';
        break;
      case 'cancelled':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        icon = Icons.cancel;
        displayText = 'Đã hủy';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        icon = Icons.info;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            displayText,
            softWrap: true,
            overflow: TextOverflow.visible,
            maxLines: 2,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 🔍 Chi tiết giao dịch
  void _showTransactionDetail(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F8B74),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      "Chi tiết đơn hàng",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mã đơn và trạng thái
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runAlignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Mã đơn
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt,
                                  color: Color(0xFF0F8B74),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  transaction.orderNumber,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            // Badge nằm sát mép phải
                            SizedBox(
                              width: constraints
                                  .maxWidth, // lấy full width để căn phải
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildStatusBadge(transaction.status),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    // Thông tin khách hàng
                    _buildDetailRow(
                      Icons.person,
                      "Tên khách hàng",
                      transaction.customerName,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.phone,
                      "Số điện thoại",
                      transaction.customerPhone,
                    ),
                    const SizedBox(height: 12),

                    // Thời gian
                    _buildDetailRow(
                      Icons.access_time,
                      "Thời gian đặt",
                      "${_formatDate(transaction.date)} - ${_formatTime(transaction.date)}",
                    ),
                    const SizedBox(height: 12),

                    // Địa chỉ
                    _buildDetailRow(
                      Icons.location_on,
                      "Địa chỉ giao hàng",
                      transaction.address,
                    ),
                    const SizedBox(height: 12),

                    // Ghi chú
                    if (transaction.note.isNotEmpty)
                      _buildDetailRow(Icons.note, "Ghi chú", transaction.note),
                    if (transaction.note.isNotEmpty) const SizedBox(height: 12),

                    // Phương thức thanh toán
                    _buildDetailRow(
                      Icons.payment,
                      "Phương thức thanh toán",
                      _getPaymentMethodText(transaction.paymentMethod),
                    ),

                    // Thông tin hủy đơn (nếu có)
                    if (transaction.status == 'cancelled') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Lý do hủy: ${transaction.cancellationReason}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red[700],
                              ),
                            ),
                            if (transaction.cancelledAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Hủy lúc: ${_formatDate(transaction.cancelledAt!)} ${_formatTime(transaction.cancelledAt!)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 32),

                    // Danh sách sản phẩm
                    const Text(
                      "Sản phẩm đã đặt",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...transaction.items.map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hình ảnh sản phẩm
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.image.startsWith('/uploads')
                                    ? Image.network(
                                        'http://10.0.2.2:5000${item.image}',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
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
                                        child: const Icon(
                                          Icons.local_cafe,
                                          color: Color(0xFF0F8B74),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (item.optionName.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          item.optionName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      "${VnFormat.format(item.unitPrice)} đ × ${VnFormat.format(item.quantity)}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${VnFormat.format(item.totalPrice)} đ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 32),

                    // Tổng tiền thuê
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Tổng cộng:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${VnFormat.format(transaction.totalAmount)} đ",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    if (transaction.status == 'pending') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            cancelOrder(transaction.id);
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text("Hủy đơn hàng"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (transaction.status == 'confirmed') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            confirmReceivedOrder(transaction.id);
                          },
                          icon: const Icon(Icons.local_shipping),
                          label: const Text("Xác nhận đã nhận được hàng"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (transaction.status == 'renting') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            confirmReturnedOrder(transaction.id);
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text("Xác nhận đã trả hàng"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Color(0xFF0F8B74)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'momo':
        return 'Ví Momo';
      case 'card':
        return 'Thẻ ngân hàng';
      default:
        return method;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}

// 📦 Model cho Transaction
class Transaction {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String address;
  final String note;
  final DateTime date;
  final List<TransactionItem> items;
  final int totalAmount;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String cancellationReason;
  final DateTime? cancelledAt;

  Transaction({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.note,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.cancellationReason = '',
    this.cancelledAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['_id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      address: json['deliveryAddress'] ?? '',
      note: json['note'] ?? '',
      date: DateTime.parse(json['orderDate'] ?? json['createdAt']),
      items: (json['items'] as List)
          .map((item) => TransactionItem.fromJson(item))
          .toList(),
      totalAmount: json['totalAmount'] ?? 0,
      status: json['status'] ?? '',
      paymentMethod: json['paymentMethod'] ?? '',
      paymentStatus: json['paymentStatus'] ?? '',
      cancellationReason: json['cancellationReason'] ?? '',
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
    );
  }
}

// 📦 Model cho Transaction Item
class TransactionItem {
  final String productId;
  final String name;
  final String image;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final String optionName;
  final int optionPrice;

  TransactionItem({
    required this.productId,
    required this.name,
    required this.image,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.optionName,
    required this.optionPrice,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      productId: json['productId'] ?? '',
      name: json['productName'] ?? '',
      image: json['productImage'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: json['basePrice'] ?? 0,
      totalPrice: json['basePrice'] ?? 0,
      optionName: json['selectedOption']?['name'] ?? '',
      optionPrice: json['selectedOption']?['extraPrice'] ?? 0,
    );
  }
}
