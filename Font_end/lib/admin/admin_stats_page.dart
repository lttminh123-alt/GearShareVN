import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  bool isLoading = true;

  // Fake data – bạn có thể thay bằng API real
  int totalUsers = 0;
  int totalProducts = 0;
  int totalOrders = 0;
  double totalRevenue = 0;

  List<double> monthlyRevenue = [];
  List<int> monthlyOrders = [];

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    await Future.delayed(const Duration(milliseconds: 800)); // Fake loading

    setState(() {
      totalUsers = 1560;
      totalProducts = 230;
      totalOrders = 980;
      totalRevenue = 154_500_000;

      monthlyRevenue = [
        12,
        18,
        14,
        20,
        30,
        25,
        28,
        35,
        40,
        38,
        45,
        50,
      ]; // đơn vị: triệu VNĐ

      monthlyOrders = [80, 95, 90, 120, 140, 160, 180, 170, 200, 210, 240, 260];

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("📊 Thống kê hệ thống"),
        backgroundColor: const Color(0xFF0F8B74),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  buildStatsOverview(),
                  const SizedBox(height: 20),
                  buildSectionTitle("📈 Doanh thu theo tháng"),
                  const SizedBox(height: 8),
                  buildRevenueChart(),
                  const SizedBox(height: 25),
                  buildSectionTitle("📦 Số lượng đơn hàng theo tháng"),
                  const SizedBox(height: 8),
                  buildOrdersChart(),
                ],
              ),
            ),
    );
  }

  // ==========================
  //   OVERVIEW CARDS
  // ==========================
  Widget buildStatsOverview() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        buildStatCard(
          "Người dùng",
          totalUsers.toString(),
          Icons.people,
          Colors.blue,
        ),
        buildStatCard(
          "Sản phẩm",
          totalProducts.toString(),
          Icons.inventory,
          Colors.green,
        ),
        buildStatCard(
          "Đơn hàng",
          totalOrders.toString(),
          Icons.list_alt,
          Colors.orange,
        ),
        buildStatCard(
          "Doanh thu",
          "${totalRevenue ~/ 100}đ",
          Icons.attach_money,
          Colors.red,
        ),
      ],
    );
  }

  Widget buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  // ==========================
  //  SECTION TITLE
  // ==========================
  Widget buildSectionTitle(String name) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  // ==========================
  //  REVENUE CHART
  // ==========================
  Widget buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          titlesData: FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: Colors.green,
              barWidth: 4,
              spots: [
                for (int i = 0; i < monthlyRevenue.length; i++)
                  FlSpot(i.toDouble(), monthlyRevenue[i]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================
  //  ORDERS CHART
  // ==========================
  Widget buildOrdersChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: BarChart(
        BarChartData(
          minY: 0,
          titlesData: FlTitlesData(show: false),
          barGroups: [
            for (int i = 0; i < monthlyOrders.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: monthlyOrders[i].toDouble(),
                    color: Colors.blue,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
