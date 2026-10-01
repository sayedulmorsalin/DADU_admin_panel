import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class AdminUsedProductsScreen extends StatefulWidget {
  const AdminUsedProductsScreen({super.key});

  @override
  State<AdminUsedProductsScreen> createState() => _AdminUsedProductsScreenState();
}

class _AdminUsedProductsScreenState extends State<AdminUsedProductsScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _counts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'sold': 0,
    'total': 0,
  };

  bool _isLoading = true;
  String _selectedStatus = 'pending';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _statusTabs = [
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'approved', 'label': 'Approved'},
    {'key': 'rejected', 'label': 'Rejected'},
    {'key': 'sold', 'label': 'Sold'},
    {'key': 'all', 'label': 'All'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await _apiService.fetchAdminUsedProducts(
        status: _selectedStatus,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _counts = Map<String, dynamic>.from(res['counts'] ?? _counts);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> product) async {
    final String id = product['id'];
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Approve Old Product'),
        content: Text(
          'Approve "${product['name']}"? It will immediately show to customers in "Buy Old Boot".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve & Publish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _apiService.updateUsedProductStatus(id, 'approved');
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product approved! It is now live in Buy Old Boot.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadProducts();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve product.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> product) async {
    final String id = product['id'];
    final TextEditingController noteController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject Old Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for rejecting "${product['name']}" (visible to seller):'),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'e.g. Unclear photo, inaccurate brand, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject Listing'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _apiService.updateUsedProductStatus(
      id,
      'rejected',
      adminNote: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product rejected.'), backgroundColor: Colors.orange),
        );
        _loadProducts();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject product.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> product) async {
    final String id = product['id'];
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Product Listing'),
        content: Text(
          'Are you sure you want to permanently delete "${product['name']}"? This will also remove the image from storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _apiService.deleteAdminUsedProduct(id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully.')),
        );
        _loadProducts();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete product.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Manage Old / Used Products',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) => _buildProductCard(_products[idx]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusTabs.map((tab) {
            final String key = tab['key']!;
            final String label = tab['label']!;
            final isSelected = _selectedStatus == key;
            final int count = _counts[key] ?? (_counts['total'] ?? 0);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    if (count > 0 && key == 'pending') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.red : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                selected: isSelected,
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.grey.shade100,
                onSelected: (val) {
                  setState(() {
                    _selectedStatus = key;
                  });
                  _loadProducts();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: TextField(
        controller: _searchController,
        onSubmitted: (query) {
          setState(() {
            _searchQuery = query.trim();
          });
          _loadProducts();
        },
        decoration: InputDecoration(
          hintText: 'Search by product, seller, email, or phone...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _loadProducts();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String status = (product['status'] ?? 'pending').toString().toLowerCase();
    Color statusColor = Colors.orange;
    String statusLabel = 'Pending Review';

    if (status == 'approved') {
      statusColor = Colors.green;
      statusLabel = 'Approved / Live';
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusLabel = 'Rejected';
    } else if (status == 'sold') {
      statusColor = Colors.blueGrey;
      statusLabel = 'Sold';
    }

    final createdAt = product['createdAt'] != null
        ? DateTime.tryParse(product['createdAt'].toString())
        : null;
    final String dateStr = createdAt != null
        ? DateFormat('dd MMM, yyyy · hh:mm a').format(createdAt)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Date Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Image & Info Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: ApiService.resolveUrl(product['imagePrimary']?.toString() ?? ''),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? 'Untitled Product',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '৳${product['price'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (product['originalPrice'] != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '৳${product['originalPrice']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (product['brand'] != null)
                            _buildInfoChip(product['brand']),
                          if (product['size'] != null && product['size'].toString().isNotEmpty)
                            _buildInfoChip('Size: ${product['size']}'),
                          if (product['condition'] != null)
                            _buildInfoChip(product['condition'], color: Colors.orange.shade800),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description / Details
            if (product['details'] != null && product['details'].toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  product['details'],
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.3),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Seller Contact Information
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    product['userName'] ?? 'Unknown User',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.phone_outlined, size: 15, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text(
                    product['userPhone'] ?? 'No phone',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  if (product['userEmail'] != null)
                    Text(
                      product['userEmail'],
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),

            if (product['adminNote'] != null && product['adminNote'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Admin note: ${product['adminNote']}',
                style: const TextStyle(fontSize: 11.5, color: Colors.red, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),

            // Admin Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _handleDelete(product),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                if (status != 'rejected')
                  OutlinedButton.icon(
                    onPressed: () => _handleReject(product),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade800),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                  ),
                const SizedBox(width: 8),
                if (status != 'approved')
                  ElevatedButton.icon(
                    onPressed: () => _handleApprove(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey.shade700).withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No Used Products in "$_selectedStatus"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Submissions will appear here for your review and approval.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
