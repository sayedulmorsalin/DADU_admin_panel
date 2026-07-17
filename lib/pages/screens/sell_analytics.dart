import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SellAnalyticsPage extends StatefulWidget {
  const SellAnalyticsPage({super.key});

  @override
  State<SellAnalyticsPage> createState() => _SellAnalyticsPageState();
}

class _SellAnalyticsPageState extends State<SellAnalyticsPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _isSyncing = false;

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      await _dbService.syncMonthlyAnalytics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analytics synchronized successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _handleSync,
            icon: _isSyncing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync),
            tooltip: 'Sync Data',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No analytics data found.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _handleSync,
                    child: const Text('Sync Now'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return _buildAnalyticsCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsCard(Map<String, dynamic> data) {
    final String monthName = data['monthName'] ?? 'Unknown Month';
    final double totalSales = (data['totalSales'] as num?)?.toDouble() ?? 0.0;
    final int totalOrders = data['totalOrders'] ?? 0;

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
                const Icon(Icons.trending_up, color: Colors.green),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'Total Sales',
                    value: '৳${totalSales.toStringAsFixed(2)}',
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
          ],
        ),
      ),
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
