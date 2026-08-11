import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:dadu_admin_panel/services/database_service.dart';
import 'package:dadu_admin_panel/services/image_delete_service.dart';

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
        title: const Text('Permanently Delete Order'),
        content: const Text(
          'This will permanently delete the order and all associated images. This cannot be undone.\n\nAre you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        // Permanently delete Cloudinary image (payment proof)
        if (order['paymentProof'] != null &&
            order['paymentProof'].toString().isNotEmpty) {
          deleteImageFromCloudinaryUrl(order['paymentProof'].toString());
        }
        // Remove from Firestore
        await _databaseService.deleteCancelledOrder(
          userDocId: order['user_document_id'],
          orderData: order,
        );
        fetchOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order permanently deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting order: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleRefundStatus(Map<String, dynamic> order) async {
    final bool currentStatus = order['isRefunded'] == true;
    final bool newStatus = !currentStatus;

    final String customerName =
        (order['customerName'] ?? order['user_name'] ?? 'Customer').toString();
    final String refundNum = _getRefundNumber(order);
    final String amount = (order['total'] ?? 'N/A').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus ? 'Confirm Money Refund' : 'Unmark Refund Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              newStatus
                  ? 'Are you sure you have completed the money refund for this order?'
                  : 'Are you sure you want to uncheck refund status for this order?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: newStatus ? Colors.green[50] : Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: newStatus
                      ? Colors.green.shade300
                      : Colors.amber.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: $customerName',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (refundNum.isNotEmpty)
                    Text('Refund Phone: $refundNum',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900])),
                  Text('Total Amount: ৳$amount',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  newStatus ? Colors.green[700] : Colors.orange[800],
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus ? 'Yes, Money Refunded' : 'Yes, Unmark'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userDocId = order['user_document_id']?.toString() ?? '';
        if (userDocId.isEmpty) throw Exception('User document ID not found');

        await _databaseService.updateCancelledOrderRefundStatus(
          userDocId: userDocId,
          orderData: order,
          isRefunded: newStatus,
        );

        setState(() {
          order['isRefunded'] = newStatus;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus
                    ? 'Order marked as Refunded! ✅'
                    : 'Refund status updated.',
              ),
              backgroundColor: newStatus ? Colors.green[800] : Colors.black87,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating refund status: $e')),
          );
        }
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

  String _getRefundNumber(Map<String, dynamic> order) {
    final val = order['refundPhone'] ??
        order['refund_phone'] ??
        order['refundNumber'] ??
        order['refund_number'] ??
        order['refundAccount'] ??
        order['refund_account'] ??
        order['refundMobile'] ??
        order['refund_mobile'] ??
        order['bkashNumber'] ??
        order['bkash_number'] ??
        order['nagadNumber'] ??
        order['nagad_number'] ??
        order['rocketNumber'] ??
        order['rocket_number'];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
    return '';
  }

  String _getRefundMethod(Map<String, dynamic> order) {
    final val = order['refund_method'] ??
        order['refundMethod'] ??
        order['refundType'] ??
        order['refund_type'] ??
        order['refundProvider'] ??
        order['refund_provider'];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
    return '';
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
    addValue(order['moderator']);
    addValue(order['customerName'] ?? order['user_name']);
    addValue(order['customerEmail'] ?? order['user_email']);
    addValue(order['phone'] ?? order['user_phone']);
    addValue(order['district']);
    addValue(order['thana']);
    addValue(order['address']);
    addValue(order['paymentMethod']);
    addValue(order['cancelReason']);
    addValue(_getRefundNumber(order));
    addValue(_getRefundMethod(order));
    if (order['isRefunded'] == true) addValue('refunded');
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
                                                  _buildModeratorBadge(order['moderator']),
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
                                                  // Refund phone badge shown in header
                                                  if (_getRefundNumber(order).isNotEmpty)
                                                    Container(
                                                      margin: const EdgeInsets.only(top: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green[50],
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.green.shade400, width: 1.5),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.monetization_on, color: Colors.green[800], size: 18),
                                                          const SizedBox(width: 6),
                                                          Flexible(
                                                            child: Text(
                                                              'Refund Phone: ${_getRefundNumber(order)}${_getRefundMethod(order).isNotEmpty ? ' (${_getRefundMethod(order)})' : ''}',
                                                              style: TextStyle(
                                                                color: Colors.green[900],
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          InkWell(
                                                            onTap: () {
                                                              Clipboard.setData(ClipboardData(text: _getRefundNumber(order)));
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Copied refund number: ${_getRefundNumber(order)}')),
                                                              );
                                                            },
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green[700],
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(Icons.copy, size: 12, color: Colors.white),
                                                                  SizedBox(width: 4),
                                                                  Text(
                                                                    'Copy',
                                                                    style: TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 11,
                                                                        fontWeight: FontWeight.bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
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
                                             Column(
                                               children: [
                                                 InkWell(
                                                   onTap: () => _toggleRefundStatus(order),
                                                   child: Row(
                                                     mainAxisSize: MainAxisSize.min,
                                                     children: [
                                                       Checkbox(
                                                         value: order['isRefunded'] == true,
                                                         activeColor: Colors.green[700],
                                                         onChanged: (_) => _toggleRefundStatus(order),
                                                       ),
                                                       Text(
                                                         order['isRefunded'] == true ? 'REFUNDED ✅' : 'Refund',
                                                         style: TextStyle(
                                                           fontWeight: FontWeight.bold,
                                                           fontSize: 12,
                                                           color: order['isRefunded'] == true
                                                               ? Colors.green[800]
                                                               : Colors.red[800],
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
                                        if (_getRefundNumber(order).isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Refund Phone: ${_getRefundNumber(order)}${_getRefundMethod(order).isNotEmpty ? ' (${_getRefundMethod(order)})' : ''}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                      color: Colors.green[800],
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    Clipboard.setData(ClipboardData(text: _getRefundNumber(order)));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Copied refund number: ${_getRefundNumber(order)}')),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.copy, size: 16),
                                                  label: const Text('Copy Refund Phone'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green[700],
                                                    foregroundColor: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          buildSafeText('Refund Phone', 'N/A'),
                                         buildSafeText(
                                           'Refund Status',
                                           order['isRefunded'] == true ? 'COMPLETED ✅' : 'PENDING ⏳',
                                           style: TextStyle(
                                             fontWeight: FontWeight.bold,
                                             fontSize: 18,
                                             color: order['isRefunded'] == true ? Colors.green[800] : Colors.red[800],
                                           ),
                                         ),
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
                                         const SizedBox(height: 8),
                                         const Text(
                                           'Payment Proof:',
                                           style: TextStyle(
                                               fontWeight: FontWeight.bold,
                                               fontSize: 16),
                                         ),
                                         if (order['paymentProof'] != null &&
                                             order['paymentProof'].toString().isNotEmpty)
                                           ClipRRect(
                                             borderRadius: BorderRadius.circular(8),
                                             child: Image.network(
                                               order['paymentProof'].toString(),
                                               width: double.infinity,
                                               fit: BoxFit.cover,
                                               loadingBuilder: (context, child, loadingProgress) {
                                                 if (loadingProgress == null) return child;
                                                 return const Center(child: CircularProgressIndicator());
                                               },
                                               errorBuilder: (context, error, stackTrace) =>
                                                   const Text('Could not load payment proof image',
                                                       style: TextStyle(color: Colors.grey)),
                                             ),
                                           )
                                         else
                                           const Text('No payment proof provided',
                                               style: TextStyle(color: Colors.grey)),
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
