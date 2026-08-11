import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dadu_admin_panel/services/database_service.dart';

class Delivered extends StatefulWidget {
  const Delivered({super.key});

  @override
  State<Delivered> createState() => _DeliveredState();
}

class _DeliveredState extends State<Delivered> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> delivered = [];
  bool isLoading = true;
  String _searchQuery = '';
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpansion(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
  }

  Future<void> fetchOrders() async {
    final data = await _databaseService.getAllDelivered();
    data.sort((a, b) {
      try {
        final dateA = a['timestamp']?.toDate() ?? (a['order_date'] != null ? DateTime.fromMillisecondsSinceEpoch(a['order_date']) : DateTime(0));
        final dateB = b['timestamp']?.toDate() ?? (b['order_date'] != null ? DateTime.fromMillisecondsSinceEpoch(b['order_date']) : DateTime(0));
        return dateB.compareTo(dateA);
      } catch (e) { return 0; }
    });
    setState(() { delivered = data; isLoading = false; });
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _databaseService.deleteCompletedOrder(userDocId: order['user_document_id'], orderData: order);
        fetchOrders();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting order: $e')));
      }
    }
  }

  List<dynamic> getItems(Map<String, dynamic> order) {
    try { final items = order['items']; if (items is List) return items; return []; } catch (e) { return []; }
  }

  Widget buildSafeText(String label, dynamic value, {TextStyle? style}) {
    return Text("$label: ${value?.toString() ?? 'N/A'}", style: style ?? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
  }

  String _getFormattedTime(Map<String, dynamic> order) {
    try {
      if (order['timestamp'] != null) return DateFormat('dd-MM-yyyy hh:mm a').format(order['timestamp'].toDate());
      if (order['order_date'] != null) return DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(order['order_date']));
      return 'N/A';
    } catch (e) { return 'Invalid date'; }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _normalizeSearchText(_searchQuery);
    if (query.isEmpty) return delivered;
    final scoredOrders = delivered
        .map((order) => MapEntry(order, _orderSearchScore(order, query)))
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scoredOrders.map((entry) => entry.key).toList();
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _buildSearchableText(Map<String, dynamic> order) {
    final buffer = StringBuffer();
    void addValue(dynamic value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) buffer.write('$text ');
    }
    addValue(order['order_id']);
    addValue(order['transactionId']);
    addValue(order['moderator']);
    addValue(order['customerName'] ?? order['user_name']);
    addValue(order['customerEmail'] ?? order['user_email']);
    addValue(order['phone'] ?? order['user_phone']);
    addValue(order['district']);
    addValue(order['thana']);
    addValue(order['address']);
    addValue(order['paymentMethod']);
    final items = getItems(order);
    for (final item in items) { if (item is Map<String, dynamic>) { addValue(item['name']); addValue(item['size']); } }
    return _normalizeSearchText(buffer.toString());
  }

  Widget _buildModeratorBadge(dynamic modValue) {
    if (modValue == null || modValue.toString().trim().isEmpty) return const SizedBox.shrink();
    final modStr = modValue.toString().toLowerCase();
    final bool isMod1 = modStr == 'moderator-1';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMod1 ? Colors.purple.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMod1 ? Colors.purple : Colors.orange, width: 1.5),
      ),
      child: Text(
        modValue.toString().toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isMod1 ? Colors.purple.shade900 : Colors.orange.shade900,
        ),
      ),
    );
  }

  int _orderSearchScore(Map<String, dynamic> order, String query) {
    final searchableText = _buildSearchableText(order);
    if (searchableText.isEmpty || query.isEmpty) return 0;
    if (searchableText.contains(query)) return 1000 - (searchableText.length - query.length).clamp(0, 999);
    final queryTokens = query.split(' ').where((token) => token.isNotEmpty);
    int score = 0;
    for (final queryToken in queryTokens) { if (searchableText.contains(queryToken)) score += 90; }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      appBar: AppBar(
        title: const Text("Delivered", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search orders, customers, transaction ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }, icon: const Icon(Icons.clear)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: visibleOrders.isEmpty
                        ? Center(child: Text(delivered.isEmpty ? "No orders found." : "No matching orders found.", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))
                        : ListView.builder(
                            itemCount: visibleOrders.length,
                            itemBuilder: (context, index) {
                              final order = visibleOrders[index];
                              final items = getItems(order);
                              final bool isExpanded = _expandedIndices.contains(index);

                              return Card(
                                margin: const EdgeInsets.all(10),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () => _toggleExpansion(index),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                buildSafeText("Order No", index + 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)),
                                                _buildModeratorBadge(order['moderator']),
                                                buildSafeText("Customer Name", order['customerName'] ?? order['user_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                                buildSafeText("Phone", order['phone'] ?? order['user_phone'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                                buildSafeText("Item Count", items.length, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                                                if (order['transactionId'] != null)
                                                  buildSafeText("Transaction ID", order['transactionId'], style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                          ],
                                        ),
                                      ),
                                      if (isExpanded) ...[
                                        const Divider(),
                                        buildSafeText("Email", order['customerEmail'] ?? order['user_email']),
                                        buildSafeText("District", order['district'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                        buildSafeText("Thana", order['thana'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                        buildSafeText("Address", order['address'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                        const SizedBox(height: 10),
                                        Text("Items: (${items.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (items.isNotEmpty)
                                          ...items.map((item) {
                                            final itemMap = item is Map<String, dynamic> ? item : {};
                                            return ListTile(
                                              leading: itemMap['imageUrl'] != null ? Image.network(itemMap['imageUrl']!, width: 50, height: 50, errorBuilder: (context, error, stackTrace) => const Icon(Icons.error)) : const Icon(Icons.image),
                                              title: Text(itemMap['name']?.toString() ?? 'Unknown Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              subtitle: Text("Price: ${itemMap['price']} × ${itemMap['quantity']}Unit. Size: ${itemMap['size'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            );
                                          }).toList(),
                                        if (items.isEmpty) const Text("No items found", style: TextStyle(color: Colors.grey)),
                                        const SizedBox(height: 10),
                                        buildSafeText("Subtotal", order['subtotal']),
                                        buildSafeText("Total", order['total'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        buildSafeText("Delivery fee", order['deliveryCharge'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                        buildSafeText("Time", _getFormattedTime(order)),
                                        buildSafeText("Payment Method", order['paymentMethod']),
                                        buildSafeText("Point in account", order['deliveryPoints']),
                                        buildSafeText("Point in use", order['deliveryPointsUsed'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                        buildSafeText("Request for free delivery", order['freeDeliveryUsed'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteOrder(order)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
