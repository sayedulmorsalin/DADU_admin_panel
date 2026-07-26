import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class SellAnalyticsPage extends StatefulWidget {
  const SellAnalyticsPage({super.key});

  @override
  State<SellAnalyticsPage> createState() => _SellAnalyticsPageState();
}

class _SellAnalyticsPageState extends State<SellAnalyticsPage> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sell Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Monthly Summary', icon: Icon(Icons.calendar_month)),
              Tab(text: 'Sales Ledger', icon: Icon(Icons.receipt_long)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMonthlySummaryTab(),
            _buildSalesLedgerTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummaryTab() {
    return RefreshIndicator(
      onRefresh: () async {
        // Forcing a small delay to show the refresh animation
        // The StreamBuilder will handle the data update automatically
        await Future.delayed(const Duration(seconds: 1));
        setState(() {});
      },
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _dbService.getMonthlyAnalyticsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 400,
                child: _EmptyState(
                  icon: Icons.analytics_outlined,
                  message: 'No analytics data yet. Deliveries will appear here.',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return _buildMonthlyCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildSalesLedgerTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {});
      },
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _dbService.getSalesRecordsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 400,
                child: _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No sales recorded yet.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            physics: const AlwaysScrollableScrollPhysics(),
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return _buildLedgerEntry(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildMonthlyCard(Map<String, dynamic> data) {
    final String monthName = data['monthName'] ?? 'Unknown Month';
    final double totalSales = (data['totalSales'] as num?)?.toDouble() ?? 0.0;
    final int totalOrders = data['totalOrders'] ?? 0;
    final int totalProducts = data['totalProductsCount'] ?? 0;
    final double totalDelivery = (data['totalDeliveryCharges'] as num?)?.toDouble() ?? 0.0;
    final double totalCommission = (data['totalDeveloperCommission'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  monthName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Comm: ৳${totalCommission.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'Total Sales',
                    value: '৳${totalSales.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    label: 'Orders',
                    value: totalOrders.toString(),
                    icon: Icons.shopping_bag,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'Products Sold',
                    value: totalProducts.toString(),
                    icon: Icons.inventory_2_outlined,
                    color: Colors.blueGrey,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    label: 'Delivery Fees',
                    value: '৳${totalDelivery.toStringAsFixed(0)}',
                    icon: Icons.local_shipping_outlined,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerEntry(Map<String, dynamic> data) {
    final String customer = data['customerName'] ?? 'Unknown';
    final double total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final double commission = (data['calculatedCommission'] as num?)?.toDouble() ?? 0.0;
    final Timestamp? recordedAt = data['recordedAt'] as Timestamp?;
    final String dateStr = recordedAt != null 
        ? DateFormat('dd MMM, hh:mm a').format(recordedAt.toDate()) 
        : 'Unknown Date';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.person_outline, size: 20, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                dateStr,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Items: ${data['productsCount'] ?? 0} | Total: ৳${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Commission',
              style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            Text(
              '৳${commission.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
