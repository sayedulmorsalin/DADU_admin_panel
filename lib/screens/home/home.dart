import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu_admin_panel/screens/marketing/banner.dart';
import 'package:dadu_admin_panel/screens/orders/cancelled.dart';
import 'package:dadu_admin_panel/screens/orders/delivered.dart';
import 'package:dadu_admin_panel/screens/products/manage_product.dart';
import 'package:dadu_admin_panel/screens/marketing/draw.dart';
import 'package:dadu_admin_panel/screens/products/flash_sell.dart';
import 'package:dadu_admin_panel/screens/products/search.dart';
import 'package:dadu_admin_panel/screens/marketing/send_notification.dart';
import 'package:dadu_admin_panel/screens/orders/shipping.dart';
import 'package:dadu_admin_panel/screens/orders/update_payment.dart';
import 'package:dadu_admin_panel/screens/orders/verify.dart';
import 'package:dadu_admin_panel/screens/orders/receive.dart';
import 'package:dadu_admin_panel/screens/chat/message_threads.dart';
import 'package:dadu_admin_panel/screens/reviews/admin_reviews_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadu_admin_panel/services/database_service.dart';
import 'package:dadu_admin_panel/screens/products/gift_item.dart';
import 'package:dadu_admin_panel/screens/products/new_arrival.dart';
import 'package:dadu_admin_panel/screens/analytics/sell_analytics.dart';
import 'package:dadu_admin_panel/screens/analytics/user_analytics.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('login_timestamp');
      await FirebaseAuth.instance.signOut();
      // Navigation is handled by StreamBuilder in main.dart
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DADU Admin Panel',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.yellow,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await _logout(context);
                  }
                },
                itemBuilder:
                    (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ],
                child: const CircleAvatar(
                  backgroundColor: Colors.yellow,
                  child: Icon(Icons.person, color: Colors.blue),
                ),
              ),
            ),
          ),
        ],
      ),
      body: const AdminHome(),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

// ─── Dashboard item model ────────────────────────────────────────────────────
// Each menu button is described by one _DashboardItem.
// - [countStream] is optional: supply it to show a live red badge.
// To ADD a new button in future → just add one _DashboardItem to the list
// inside _buildItems(). The rows-of-3 layout is automatic.
class _DashboardItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final Stream<int>? countStream; // optional live badge

  const _DashboardItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.countStream,
  });
}

// ─── State ───────────────────────────────────────────────────────────────────
class _AdminHomeState extends State<AdminHome> {
  final DatabaseService _dbService = DatabaseService();

  // Live-count streams (only for items that need a badge)
  late final Stream<int> _verifyCount;
  late final Stream<int> _shippingCount;
  late final Stream<int> _receiveCount;
  late final Stream<int> _deliveredCount;
  late final Stream<int> _cancelledCount;

  @override
  void initState() {
    super.initState();
    _verifyCount   = _dbService.getVerifyCountStream();
    _shippingCount = _dbService.getShippingCountStream();
    _receiveCount  = _dbService.getReceiveCountStream();
    _deliveredCount  = _dbService.getCompletedCountStream();
    _cancelledCount  = _dbService.getCancelledCountStream();
  }

  // ── Master item list ───────────────────────────────────────────────────────
  // ADD NEW BUTTONS HERE — layout updates automatically.
  List<_DashboardItem> _buildItems(BuildContext context) => [
    // ── Orders ──────────────────────────────────────────────────────────────
    _DashboardItem(
      icon: Icons.verified,
      label: 'Verify',
      color: Colors.deepOrange,
      countStream: _verifyCount,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Verify())),
    ),
    _DashboardItem(
      icon: Icons.local_shipping,
      label: 'Shipping',
      color: Colors.indigo,
      countStream: _shippingCount,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Shipping())),
    ),
    _DashboardItem(
      icon: Icons.assignment_return,
      label: 'Receive',
      color: Colors.teal,
      countStream: _receiveCount,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivePage())),
    ),
    _DashboardItem(
      icon: Icons.check_circle,
      label: 'Delivered',
      color: Colors.green.shade700,
      countStream: _deliveredCount,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Delivered())),
    ),
    _DashboardItem(
      icon: Icons.cancel,
      label: 'Cancelled',
      color: Colors.red.shade700,
      countStream: _cancelledCount,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CancelledOrders())),
    ),
    // ── Products ─────────────────────────────────────────────────────────────
    _DashboardItem(
      icon: Icons.inventory_2,
      label: 'Manage Product',
      color: Colors.orange.shade800,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageProductPage())),
    ),
    _DashboardItem(
      icon: Icons.flash_on,
      label: 'Flash Sell',
      color: Colors.purple.shade600,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashSell())),
    ),
    _DashboardItem(
      icon: Icons.new_label,
      label: 'New Arrival',
      color: Colors.amber.shade900,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewArrival())),
    ),
    _DashboardItem(
      icon: Icons.card_giftcard,
      label: 'Gift Item',
      color: Colors.pink,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GiftItem())),
    ),
    // ── Marketing ────────────────────────────────────────────────────────────
    _DashboardItem(
      icon: Icons.upload,
      label: 'Update Banner',
      color: Colors.blue.shade600,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BannerPage())),
    ),
    _DashboardItem(
      icon: Icons.notification_add,
      label: 'Send Notification',
      color: Colors.purple.shade800,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SendNotification())),
    ),
    _DashboardItem(
      icon: Icons.casino,
      label: 'Draw Gift',
      color: Colors.red.shade700,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Draw())),
    ),
    // ── Utility ──────────────────────────────────────────────────────────────
    _DashboardItem(
      icon: Icons.search,
      label: 'Search',
      color: Colors.deepPurple,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Search())),
    ),
    _DashboardItem(
      icon: Icons.update,
      label: 'Update Payment',
      color: Colors.amber.shade800,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatePayment())),
    ),
    // ── Analytics ────────────────────────────────────────────────────────────
    _DashboardItem(
      icon: Icons.insights,
      label: 'User Analytics',
      color: Colors.blue.shade800,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAnalyticsPage())),
    ),
    _DashboardItem(
      icon: Icons.analytics_outlined,
      label: 'Sell Analytics',
      color: Colors.teal.shade800,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SellAnalyticsPage())),
    ),
    // ── Communication ─────────────────────────────────────────────────────────
    _DashboardItem(
      icon: Icons.message,
      label: 'Messages',
      color: Colors.pink.shade800,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageThreadsPage())),
    ),
    _DashboardItem(
      icon: Icons.rate_review,
      label: 'Reviews',
      color: Colors.amber.shade900,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewsScreen())),
    ),
  ];

  // ── Auto-layout: groups items into rows of 3 ──────────────────────────────
  List<Widget> _buildRows(BuildContext context) {
    final items = _buildItems(context);
    final rows = <Widget>[];

    for (int i = 0; i < items.length; i += 3) {
      final rowItems = items.sublist(i, (i + 3).clamp(0, items.length));

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: rowItems.map((item) {
            if (item.countStream != null) {
              return StreamBuilder<int>(
                stream: item.countStream,
                builder: (context, snapshot) {
                  return _buildActionButton(
                    icon: item.icon,
                    label: item.label,
                    color: item.color,
                    count: snapshot.data ?? 0,
                    onPressed: item.onPressed,
                  );
                },
              );
            }
            return _buildActionButton(
              icon: item.icon,
              label: item.label,
              color: item.color,
              count: null,
              onPressed: item.onPressed,
            );
          }).toList(),
        ),
      );

      if (i + 3 < items.length) rows.add(const SizedBox(height: 15));
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          ..._buildRows(context),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required int? count,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                if (count != null && count > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
