import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dadu_admin_panel/services/database_service.dart';
import 'package:dadu_admin_panel/services/api_service.dart';

class UserAnalyticsPage extends StatefulWidget {
  const UserAnalyticsPage({super.key});

  @override
  State<UserAnalyticsPage> createState() => _UserAnalyticsPageState();
}

class _UserAnalyticsPageState extends State<UserAnalyticsPage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();

  late Stream<int> todayLoginsStream;
  late Future<int> downloadCountFuture;
  late Future<int> accountCountFuture;

  late TabController _tabController;

  bool _isLoadingApi = true;
  String? _apiError;

  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _topSearches = [];
  List<Map<String, dynamic>> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Firebase Streams / Futures
    todayLoginsStream = _dbService.getTodayLoginsStream();
    downloadCountFuture = _dbService.getTotalDownloadCount();
    accountCountFuture = _dbService.getTotalRegisteredCountStream();

    _loadApiAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApiAnalytics() async {
    setState(() {
      _isLoadingApi = true;
      _apiError = null;
    });

    try {
      final overview = await _apiService.fetchAnalyticsOverview();
      if (overview != null) {
        setState(() {
          _metrics = Map<String, dynamic>.from(overview['metrics'] ?? {});
          _topProducts = List<Map<String, dynamic>>.from(overview['topProducts'] ?? []);
          _topSearches = List<Map<String, dynamic>>.from(overview['topSearches'] ?? []);
          _recentEvents = List<Map<String, dynamic>>.from(overview['recentEvents'] ?? []);
          _isLoadingApi = false;
        });
      } else {
        setState(() {
          _apiError = 'Failed to load user analytics data';
          _isLoadingApi = false;
        });
      }
    } catch (e) {
      setState(() {
        _apiError = e.toString();
        _isLoadingApi = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      downloadCountFuture = _dbService.getTotalDownloadCount();
      accountCountFuture = _dbService.getTotalRegisteredCountStream();
    });
    await _loadApiAnalytics();
  }

  String _formatTimeAgo(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return dateVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        title: const Text(
          "User Analytics",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Data",
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 16),
                      _buildActivityMetricsCards(),
                      const SizedBox(height: 16),
                      _buildTabBarContainer(),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTopProductsTab(),
              _buildTopSearchesTab(),
              _buildRecentEventsTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header: Firebase Logins & Accounts ───────────────────────────────────────
  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.indigo.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Today's Logins Circular Highlight
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    const Text(
                      "Today's Logins",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<int>(
                      stream: todayLoginsStream,
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        final isLoading =
                            snapshot.connectionState == ConnectionState.waiting;
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(color: Colors.amberAccent, width: 3),
                          ),
                          child: Center(
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.amberAccent,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    count.toString(),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 70, color: Colors.white24),
              // Accounts & Downloads Summary
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Accounts
                      FutureBuilder<int>(
                        future: accountCountFuture,
                        builder: (context, snapshot) {
                          return _buildHeaderMiniStat(
                            icon: Icons.people_alt_rounded,
                            label: 'Total Accounts',
                            value: (snapshot.data ?? 0).toString(),
                            color: Colors.lightBlueAccent,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Total Downloads
                      FutureBuilder<int>(
                        future: downloadCountFuture,
                        builder: (context, snapshot) {
                          return _buildHeaderMiniStat(
                            icon: Icons.download_rounded,
                            label: 'Total Downloads',
                            value: (snapshot.data ?? 0).toString(),
                            color: Colors.greenAccent,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Cloudflare User Activity KPI Cards ──────────────────────────────────────
  Widget _buildActivityMetricsCards() {
    final totalViews = _metrics?['totalViews']?.toString() ?? '0';
    final totalSearches = _metrics?['totalSearches']?.toString() ?? '0';
    final todayViews = _metrics?['todayViews']?.toString() ?? '0';
    final todaySearches = _metrics?['todaySearches']?.toString() ?? '0';

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Product Views',
            total: totalViews,
            today: todayViews,
            icon: Icons.visibility_rounded,
            color: Colors.purple.shade600,
            bgColor: Colors.purple.shade50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Search Queries',
            total: totalSearches,
            today: todaySearches,
            icon: Icons.search_rounded,
            color: Colors.teal.shade700,
            bgColor: Colors.teal.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String total,
    required String today,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _isLoadingApi
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  total,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "+$today today",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tab Bar Container ───────────────────────────────────────────────────────
  Widget _buildTabBarContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue.shade800,
        indicatorWeight: 3,
        labelColor: Colors.blue.shade900,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.local_fire_department_rounded, size: 20),
            text: "Top Products",
          ),
          Tab(
            icon: Icon(Icons.manage_search_rounded, size: 20),
            text: "Top Searches",
          ),
          Tab(
            icon: Icon(Icons.bolt_rounded, size: 20),
            text: "Live Stream",
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: Top Visited Products ─────────────────────────────────────────────
  Widget _buildTopProductsTab() {
    if (_isLoadingApi) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apiError != null) {
      return _buildErrorState(_apiError!);
    }

    if (_topProducts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.visibility_off_outlined,
        title: "No Product Visits Yet",
        message: "When users browse product details, most visited items will be ranked here.",
      );
    }

    final maxViews = (_topProducts.first['viewCount'] as num?)?.toInt() ?? 1;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _topProducts.length,
      itemBuilder: (context, index) {
        final product = _topProducts[index];
        final rank = index + 1;
        final name = product['name'] ?? 'Product #${product['id']}';
        final price = product['price']?.toString() ?? '0';
        final brand = product['brand'] ?? '';
        final category = product['catagory'] ?? '';
        final viewCount = (product['viewCount'] as num?)?.toInt() ?? 0;
        final imageUrl = product['imagePrimary'] ?? '';

        final double ratio = maxViews > 0 ? (viewCount / maxViews).clamp(0.05, 1.0) : 0.05;

        Color rankColor = Colors.grey.shade700;
        if (rank == 1) rankColor = Colors.amber.shade700;
        if (rank == 2) rankColor = Colors.blueGrey.shade600;
        if (rank == 3) rankColor = Colors.brown.shade600;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank Badge
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 4, right: 10),
                  decoration: BoxDecoration(
                    color: rank <= 3 ? rankColor.withOpacity(0.15) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: rank <= 3 ? rankColor : Colors.grey.shade300,
                      width: rank <= 3 ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                      ),
                    ),
                  ),
                ),
                // Product Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey.shade200),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (brand.isNotEmpty) ...[
                            Text(
                              brand,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const Text(" • ", style: TextStyle(color: Colors.grey)),
                          ],
                          if (category.isNotEmpty)
                            Text(
                              category,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          const Spacer(),
                          Text(
                            "৳$price",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // View count bar & label
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  rank == 1 ? Colors.amber.shade700 : Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "$viewCount views",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 2: Top Search Queries ───────────────────────────────────────────────
  Widget _buildTopSearchesTab() {
    if (_isLoadingApi) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apiError != null) {
      return _buildErrorState(_apiError!);
    }

    if (_topSearches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: "No Search Data Yet",
        message: "When users search for items in the app, their popular queries will appear here.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _topSearches.length,
      itemBuilder: (context, index) {
        final item = _topSearches[index];
        final rank = index + 1;
        final query = item['query'] ?? '';
        final count = item['searchCount']?.toString() ?? '1';
        final lastSearchedAt = item['lastSearchedAt'];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: index < 3 ? Colors.teal.shade100 : Colors.grey.shade100,
              child: Text(
                "#$rank",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: index < 3 ? Colors.teal.shade900 : Colors.grey.shade700,
                ),
              ),
            ),
            title: Text(
              query,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              "Last searched: ${_formatTimeAgo(lastSearchedAt)}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 14, color: Colors.teal.shade800),
                  const SizedBox(width: 4),
                  Text(
                    "$count times",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 3: Recent Activity Stream ──────────────────────────────────────────
  Widget _buildRecentEventsTab() {
    if (_isLoadingApi) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apiError != null) {
      return _buildErrorState(_apiError!);
    }

    if (_recentEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: "No Activity Stream Yet",
        message: "Real-time user actions (product views, searches) will appear here.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _recentEvents.length,
      itemBuilder: (context, index) {
        final event = _recentEvents[index];
        final eventType = event['eventType'] ?? '';
        final isView = eventType == 'product_view';
        final isSearch = eventType == 'product_search';

        final productName = event['productName'];
        final productImage = event['productImage'];
        final searchQuery = event['searchQuery'];
        final userId = event['userId'] ?? 'Guest';
        final createdAt = event['createdAt'];

        String title;
        String subtitle;
        IconData icon;
        Color color;

        if (isView) {
          title = productName != null ? "Viewed $productName" : "Viewed Product #${event['productId'] ?? ''}";
          subtitle = "User: $userId";
          icon = Icons.visibility_rounded;
          color = Colors.purple.shade600;
        } else if (isSearch) {
          title = "Searched for \"$searchQuery\"";
          subtitle = "User: $userId";
          icon = Icons.search_rounded;
          color = Colors.teal.shade700;
        } else {
          title = "Action: $eventType";
          subtitle = "User: $userId";
          icon = Icons.touch_app_rounded;
          color = Colors.blue.shade700;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Event Icon or Product Thumbnail
                if (isView && productImage != null && productImage.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CachedNetworkImage(
                        imageUrl: productImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(icon, color: color, size: 22),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                const SizedBox(width: 12),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Timestamp
                Text(
                  _formatTimeAgo(createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Reusable Helper States ──────────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              "Could not load analytics data",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadApiAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
