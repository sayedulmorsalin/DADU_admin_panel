import 'package:flutter/material.dart';
import 'package:dadu_admin_panel/services/database_service.dart';

class UserAnalyticsPage extends StatefulWidget {
  const UserAnalyticsPage({super.key});

  @override
  State<UserAnalyticsPage> createState() => _UserAnalyticsPageState();
}

class _UserAnalyticsPageState extends State<UserAnalyticsPage> {
  final DatabaseService _dbService = DatabaseService();
  late Stream<int> todayLoginsStream;
  late final Future<int> downloadCount;
  late final Future<int> accountCount;

  @override
  void initState() {
    super.initState();
    todayLoginsStream = _dbService.getTodayLoginsStream();
    downloadCount = _dbService.getTotalDownloadCount();
    accountCount = _dbService.getTotalRegisteredCountStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      appBar: AppBar(
        title: const Text(
          "User Analytics",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: const Color.fromARGB(255, 204, 223, 232),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            StreamBuilder<int>(
              stream: todayLoginsStream,
              builder: (context, snapshot) {
                return _buildLoginCircle(
                  count: snapshot.data ?? 0,
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),
            const SizedBox(height: 30),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCircle({required int count, required bool isLoading}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Today's Logins",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 4),
            ),
            child: Center(
              child:
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.blue)
                      : Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 40,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            isLoading
                ? const CircularProgressIndicator()
                : Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
