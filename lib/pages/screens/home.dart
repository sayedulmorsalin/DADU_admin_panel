import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu_admin_panel/pages/screens/banner.dart';
import 'package:dadu_admin_panel/pages/screens/delivered.dart';
import 'package:dadu_admin_panel/pages/screens/add_page.dart';
import 'package:dadu_admin_panel/pages/screens/flash_sell.dart';
import 'package:dadu_admin_panel/pages/screens/search.dart';
import 'package:dadu_admin_panel/pages/screens/shipping.dart';
import 'package:dadu_admin_panel/pages/screens/update_payment.dart';
import 'package:dadu_admin_panel/pages/screens/verify.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import 'gift_item.dart';
import 'new_arrival.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

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

class _AdminHomeState extends State<AdminHome> {
  final DatabaseService _dbService = DatabaseService();
  late Stream<int> todayLoginsStream;
  late Stream<int> verifyCount;
  late Stream<int> shippingCount;
  late Stream<int> deliveredCount;
  late final downloadCount;
  late final accountCount;

  @override
  void initState() {
    super.initState();
    todayLoginsStream = _dbService.getTodayLoginsStream();
    verifyCount = _dbService.getVerifyCountStream();
    shippingCount = _dbService.getShippingCountStream();
    deliveredCount = _dbService.getCompletedCountStream();
    downloadCount = _dbService.getTotalDownloadCount();
    accountCount = _dbService.getTotalRegisteredCountStream();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder<int>(
            stream: todayLoginsStream,
            builder: (context, snapshot) {
              return _buildLoginCircle(
                count: snapshot.data ?? 0,
                isLoading: snapshot.connectionState == ConnectionState.waiting,
              );
            },
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FutureBuilder<int>(
                future: accountCount,
                builder: (context, snapshot) {
                  return _buildCountCard(
                    title: 'Total Accounts',
                    count: snapshot.data ?? 0,
                    icon: Icons.people,
                    color: Colors.blue,
                    isLoading:
                        snapshot.connectionState == ConnectionState.waiting,
                  );
                },
              ),
              FutureBuilder<int>(
                future: downloadCount,
                builder: (context, snapshot) {
                  return _buildCountCard(
                    title: 'Total Downloads',
                    count: snapshot.data ?? 0,
                    icon: Icons.download,
                    color: Colors.green,
                    isLoading:
                        snapshot.connectionState == ConnectionState.waiting,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StreamBuilder<int>(
                stream: verifyCount,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return _buildActionButton(
                    icon: Icons.verified,
                    label: "Verify",
                    count: count,
                    color: Colors.orange,
                    onPressed: () => _navigateToVerification(context),
                  );
                },
              ),
              StreamBuilder<int>(
                stream: shippingCount,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return _buildActionButton(
                    icon: Icons.local_shipping,
                    label: "Shipping",
                    count: count,
                    color: Colors.indigo,
                    onPressed: () => _navigateToShipping(context),
                  );
                },
              ),
              StreamBuilder<int>(
                stream: deliveredCount,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return _buildActionButton(
                    icon: Icons.card_giftcard,
                    label: "Delivered",
                    count: count,
                    color: Colors.black,
                    onPressed: () => _navigateToDelivered(context),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.add,
                label: "Add Product",
                count: null,
                color: Colors.yellow.shade800,
                onPressed: () => _navigateToAddProduct(context),
              ),
              _buildActionButton(
                icon: Icons.upload,
                label: "Update banner",
                count: null,
                color: Colors.blueAccent,
                onPressed: () => _navigateToBannerPage(context),
              ),
              _buildActionButton(
                icon: Icons.flash_on,
                label: "flash sell",
                count: null,
                color: Colors.deepPurple,
                onPressed: () => _navigateToFlashSell(context),
              ),
            ],
          ),

          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.new_label,
                label: "New Arrival",
                count: null,
                color: Colors.yellow.shade600,
                onPressed: () => _navigateToNewArrivalPage(context),
              ),
              _buildActionButton(
                icon: Icons.card_giftcard,
                label: "Gift Item",
                count: null,
                color: Colors.blue,
                onPressed: () => _navigateToGiftItem(context),
              ),
              _buildActionButton(
                icon: Icons.search,
                label: "Search",
                count: null,
                color: Colors.purple,
                onPressed: () => _navigateToSearchUser(context),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.update,
                label: "Update payment",
                count: null,
                color: const Color.fromARGB(255, 249, 226, 119),
                onPressed: () => _navigateToUpdatePayment(context),
              ),
              _buildActionButton(
                icon: Icons.card_giftcard,
                label: "Draw gift",
                count: null,
                color: const Color.fromARGB(255, 102, 140, 172),
                onPressed: () => _navigateToGiftItem(context),
              ),
              _buildActionButton(
                icon: Icons.notification_add,
                label: "Send notification",
                count: null,
                color: const Color.fromARGB(255, 141, 101, 148),
                onPressed: () => _navigateToSearchUser(context),
              ),
            ],
          ),

          const SizedBox(height: 30),
          _buildLastLoginList(),
        ],
      ),
    );
  }

  Widget _buildLoginCircle({required int count, required bool isLoading}) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          const Text(
            "Today's Logins",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: Center(
              child:
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.blue)
                      : Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isLoading,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            isLoading
                ? const CircularProgressIndicator()
                : Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
          ],
        ),
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
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                if (count != null && count > 0)
                  Positioned(
                    top: 10,
                    right: 10,
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
        ),
      ],
    );
  }

  Widget _buildLastLoginList() {
    return Container(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Recent Logins:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _dbService.getRecentLogins(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  height: 100,
                  child: const Center(child: Text("No recent logins")),
                );
              }

              final users = snapshot.data!;

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;

                    final email = data['email'] ?? 'Anonymous User';
                    final timestamp = data['lastLogin'] as Timestamp?;

                    final time =
                        timestamp != null
                            ? DateFormat(
                              'MMM dd, hh:mm a',
                            ).format(timestamp.toDate())
                            : 'Unknown';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      title: Text(email),
                      subtitle: Text('Last login: $time'),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToAddProduct(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddPage()));
  }

  void _navigateToSearchUser(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Search()));
  }

  void _navigateToFlashSell(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FlashSell()),
    );
  }

  void _navigateToVerification(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Verify()));
  }

  void _navigateToShipping(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Shipping()),
    );
  }

  void _navigateToDelivered(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Delivered()),
    );
  }

  void _navigateToBannerPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BannerPage()),
    );
  }

  void _navigateToNewArrivalPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewArrival()),
    );
  }

  void _navigateToGiftItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GiftItem()),
    );
  }

  void _navigateToUpdatePayment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UpdatePayment()),
    );
  }
}
