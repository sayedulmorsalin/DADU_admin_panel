import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dadu_admin_panel/services/database_service.dart';

class CancelledOrders extends StatefulWidget {
  const CancelledOrders({super.key});

  @override
  State<CancelledOrders> createState() => _CancelledOrdersState();
}

class _CancelledOrdersState extends State<CancelledOrders> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> cancelled = [];
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
    final data = await _databaseService.getAllCancelled();
    data.sort((a, b) {
      try {
        final dateA = a['timestamp']?.toDate() ??
            (a['order_date'] != null
                ? DateTime.fromMillisecondsSinceEpoch(a['order_date'])
                : DateTime(0));
        final dateB = b['timestamp']?.toDate() ??
            (b['order_date'] != null
                ? DateTime.fromMillisecondsSinceEpoch(b['order_date'])
                : DateTime(0));
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });
    setState(() {
      cancelled = data;
      isLoading = false;
    });
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this cancelled order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _databaseService.deleteCancelledOrder(
          userDocId: order['user_document_id'],
          orderData: order,
        );
        fetchOrders();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting order: $e')),
        );
      }
    }
  }

  List<dynamic> getItems(Map<String, dynamic> order) {
    try {
      final items = order['items'];
      if (items is List) return items;
      return [];
    } catch (e) {
      return [];
    }
  }

  Widget buildSafeText(String label, dynamic value, {TextStyle? style}) {
    return Text(
      '$label: ${value?.toString() ?? 'N/A'}',
      style: style ??
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  String _getFormattedTime(Map<String, dynamic> order) {
    try {
      if (order['timestamp'] != null) {
        return DateFormat('dd-MM-yyyy hh:mm a').format(order['timestamp'].toDate());
      }
      if (order['order_date'] != null) {
        return DateFormat('dd-MM-yyyy hh:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(order['order_date']));
      }
      return 'N/A';
    } catch (e) {
      return 'Invalid date';
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _normalizeSearchText(_searchQuery);
    if (query.isEmpty) return cancelled;
    final scoredOrders = cancelled
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
    addValue(order['customerName'] ?? order['user_name']);
    addValue(order['customerEmail'] ?? order['user_email']);
    addValue(order['phone'] ?? order['user_phone']);
    addValue(order['district']);
    addValue(order['thana']);
    addValue(order['address']);
    addValue(order['paymentMethod']);
    addValue(order['cancelReason']);
    final items = getItems(order);
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        addValue(item['name']);
        addValue(item['size']);
      }
    }
    return _normalizeSearchText(buffer.toString());
  }

  int _orderSearchScore(Map<String, dynamic> order, String query) {
    final searchableText = _buildSearchableText(order);
    if (searchableText.isEmpty || query.isEmpty) return 0;
    if (searchableText.contains(query)) {
      return 1000 - (searchableText.length - query.length).clamp(0, 999);
    }
    final queryTokens = query.split(' ').where((token) => token.isNotEmpty);
    int score = 0;
    for (final queryToken in queryTokens) {
      if (searchableText.contains(queryToken)) score += 90;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F3),
      appBar: AppBar(
        title: const Text(
          'Cancelled Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFCDD2),
        foregroundColor: Colors.red[900],
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Summary chip
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Total Cancelled: ${cancelled.length} orders',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search orders, customers, transaction ID...',
                      prefixIcon: const Icon(Icons.search, color: Colors.red),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: visibleOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel_outlined,
                                    size: 64, color: Colors.red[200]),
                                const SizedBox(height: 12),
                                Text(
                                  cancelled.isEmpty
                                      ? 'No cancelled orders found.'
                                      : 'No matching orders found.',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: visibleOrders.length,
                            itemBuilder: (context, index) {
                              final order = visibleOrders[index];
                              final items = getItems(order);
                              final bool isExpanded =
                                  _expandedIndices.contains(index);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 2),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: Colors.red.shade200, width: 1),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () => _toggleExpansion(index),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  buildSafeText(
                                                    'Order No',
                                                    index + 1,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  buildSafeText(
                                                    'Customer Name',
                                                    order['customerName'] ??
                                                        order['user_name'],
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                  buildSafeText(
                                                    'Phone',
                                                    order['phone'] ??
                                                        order['user_phone'],
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                  buildSafeText(
                                                    'Item Count',
                                                    items.length,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                  if (order['transactionId'] !=
                                                      null)
                                                    buildSafeText(
                                                      'Transaction ID',
                                                      order['transactionId'],
                                                      style: const TextStyle(
                                                        color: Colors.teal,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  // Cancel reason shown in collapsed view too
                                                  if (order['cancelReason'] !=
                                                          null &&
                                                      order['cancelReason']
                                                          .toString()
                                                          .isNotEmpty)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 4),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                      decoration:
                                                          BoxDecoration(
                                                        color:
                                                            Colors.red[50],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                            color: Colors
                                                                .red.shade300),
                                                      ),
                                                      child: Text(
                                                        'Reason: ${order['cancelReason']}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.red[800],
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              isExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: Colors.red[400],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isExpanded) ...[
                                        const Divider(color: Colors.redAccent),
                                        buildSafeText(
                                            'Email',
                                            order['customerEmail'] ??
                                                order['user_email']),
                                        buildSafeText(
                                          'District',
                                          order['district'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20),
                                        ),
                                        buildSafeText(
                                          'Thana',
                                          order['thana'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20),
                                        ),
                                        buildSafeText(
                                          'Address',
                                          order['address'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Items: (${items.length})',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        if (items.isNotEmpty)
                                          ...items.map((item) {
                                            final itemMap =
                                                item is Map<String, dynamic>
                                                    ? item
                                                    : {};
                                            return ListTile(
                                              leading: itemMap['imageUrl'] !=
                                                      null
                                                  ? Image.network(
                                                      itemMap['imageUrl']!,
                                                      width: 50,
                                                      height: 50,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const Icon(
                                                              Icons.error),
                                                    )
                                                  : const Icon(Icons.image),
                                              title: Text(
                                                itemMap['name']?.toString() ??
                                                    'Unknown Product',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              subtitle: Text(
                                                'Price: ${itemMap['price']} × ${itemMap['quantity']}Unit. Size: ${itemMap['size'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                            );
                                          }),
                                        if (items.isEmpty)
                                          const Text('No items found',
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                        const SizedBox(height: 10),
                                        buildSafeText(
                                            'Subtotal', order['subtotal']),
                                        buildSafeText(
                                          'Total',
                                          order['total'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                        buildSafeText(
                                          'Delivery fee',
                                          order['deliveryCharge'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.blue),
                                        ),
                                        buildSafeText(
                                            'Time', _getFormattedTime(order)),
                                        buildSafeText('Payment Method',
                                            order['paymentMethod']),
                                        buildSafeText('Point in account',
                                            order['deliveryPoints']),
                                        buildSafeText(
                                          'Point in use',
                                          order['deliveryPointsUsed'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.blue),
                                        ),
                                        buildSafeText(
                                          'Request for free delivery',
                                          order['freeDeliveryUsed'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.blue),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteOrder(order),
                                          ),
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
