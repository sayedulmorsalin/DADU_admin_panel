import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import 'package:dadu_admin_panel/services/database_service.dart';

class Verify extends StatefulWidget {
  const Verify({super.key});

  @override
  State<Verify> createState() => _VerifyState();
}

class _VerifyState extends State<Verify> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> orders = [];
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
    try {
      final data = await _databaseService.getAllOrdersVerify();

      data.sort((a, b) {
        final dateA = _readOrderDate(a);
        final dateB = _readOrderDate(b);
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        orders = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching orders: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime _readOrderDate(Map<String, dynamic> order) {
    final value = order['timestamp'] ?? order['created_at'] ?? order['order_date'];
    try {
      if (value == null) return DateTime(0);
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
        final millis = int.tryParse(value);
        if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (_) {}
    return DateTime(0);
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

  num _safeNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value) ?? 0;
    }
    return 0;
  }

  Widget buildSafeText(String label, dynamic value, {TextStyle? style}) {
    return Text(
      "$label: ${value?.toString() ?? 'N/A'}",
      style:
          style ?? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Future<void> _copyEmail(String email) async {
    if (email.isNotEmpty && email != 'N/A') {
      try {
        await FlutterClipboard.copy(email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email copied to clipboard: $email'),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy email: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String label, String value) async {
    if (value.isNotEmpty && value != 'N/A') {
      try {
        await FlutterClipboard.copy(value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied: $value'),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy $label: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget buildCopyableRow(String label, dynamic value) {
    final text = value?.toString() ?? 'N/A';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: buildSafeText(label, text)),
        if (text.isNotEmpty && text != 'N/A')
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            onPressed: () => _copyToClipboard(label, text),
            tooltip: 'Copy',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    final String text = value.toString();
    if (text.trim().isEmpty) return 'N/A';
    return text;
  }

  String _buildOrderSummary(Map<String, dynamic> order, List<dynamic> items) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Customer Name: ${_formatValue(order['customerName'] ?? order['user_name'])}');
    buffer.writeln('Phone: ${_formatValue(order['phone'] ?? order['user_phone'])}');
    buffer.writeln('District: ${_formatValue(order['district'])}');
    buffer.writeln('Thana: ${_formatValue(order['thana'])}');
    buffer.writeln('Address: ${_formatValue(order['address'])}');
    buffer.writeln('Email: ${_formatValue(order['customerEmail'] ?? order['user_email'])}');
    buffer.writeln('Time: ${_getFormattedTime(order)}');
    buffer.writeln('Payment Method: ${_formatValue(order['paymentMethod'])}');
    buffer.writeln('Subtotal: ${_formatValue(order['subtotal'])}');
    buffer.writeln('Total: ${_formatValue(order['total'])}');
    buffer.writeln('Delivery fee: ${_formatValue(order['deliveryCharge'])}');
    buffer.writeln('Note: ${_formatValue(order['note'])}');
    buffer.writeln('Point in account: ${_formatValue(order['deliveryPoints'])}');
    buffer.writeln('Point in use: ${_formatValue(order['deliveryPointsUsed'])}');
    buffer.writeln('Request for free delivery: ${_formatValue(order['freeDeliveryUsed'])}');
    buffer.writeln('Payment Proof: ${_formatValue(order['paymentProof'])}');
    buffer.writeln('Items:');

    if (items.isEmpty) {
      buffer.writeln('- No items found');
    } else {
      for (final item in items) {
        final itemMap = item is Map<String, dynamic> ? item : <String, dynamic>{};
        buffer.writeln(
          '- ${_formatValue(itemMap['name'])} | Price: ${_formatValue(itemMap['price'])} '
          'x ${_formatValue(itemMap['quantity'])} Unit | Size: ${_formatValue(itemMap['size'])}',
        );
      }
    }
    return buffer.toString().trim();
  }

  String _getNotificationOrderLabel(Map<String, dynamic> order) {
    final dynamic explicitOrderId = order['orderId'] ?? order['order_id'];
    if (explicitOrderId != null && explicitOrderId.toString().trim().isNotEmpty) return explicitOrderId.toString().trim();
    final dynamic phone = order['phone'] ?? order['user_phone'];
    if (phone != null && phone.toString().trim().isNotEmpty) return phone.toString().trim();
    return 'your order';
  }

  Future<void> _copyAllOrderInfo(Map<String, dynamic> order) async {
    final List<dynamic> items = getItems(order);
    final String summary = _buildOrderSummary(order, items);
    try {
      await FlutterClipboard.copy(summary);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All order info copied to clipboard.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to copy order info: $e')));
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _normalizeSearchText(_searchQuery);
    if (query.isEmpty) return orders;

    final scoredOrders = orders
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
    addValue(order['note']);

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
    if (searchableText.contains(query)) return 1000 - (searchableText.length - query.length).clamp(0, 999);
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
      backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      appBar: AppBar(
        title: const Text("Verify Orders", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      hintText: 'Search orders, customers, items, transaction ID...',
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
                        ? Center(child: Text(orders.isEmpty ? "No orders found." : "No matching orders found.", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))
                        : ListView.builder(
                            itemCount: visibleOrders.length,
                            itemBuilder: (context, index) {
                              final order = visibleOrders[index];
                              final items = getItems(order);
                              final email = (order['customerEmail'] ?? order['user_email'] ?? '').toString();
                              final customerName = (order['customerName'] ?? order['user_name'] ?? 'N/A').toString();
                              final phone = (order['phone'] ?? order['user_phone'] ?? 'N/A').toString();
                              final bool isExpanded = _expandedIndices.contains(index);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
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
                                                buildSafeText("Order No", index + 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                                                buildSafeText("Customer Name", customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                                buildSafeText("Phone", phone),
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
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _copyAllOrderInfo(order),
                                            icon: const Icon(Icons.content_copy, size: 18),
                                            label: const Text('Copy All'),
                                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 12)),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        buildCopyableRow("District", order['district'] ?? 'N/A'),
                                        buildCopyableRow("Thana", order['thana'] ?? 'N/A'),
                                        buildCopyableRow("Address", order['address'] ?? 'N/A'),
                                        Row(
                                          children: [
                                            Expanded(child: buildSafeText("Email", email)),
                                            if (email.isNotEmpty && email != 'N/A')
                                              IconButton(icon: const Icon(Icons.content_copy, size: 18), onPressed: () => _copyEmail(email), tooltip: 'Copy email', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text("Items: (${items.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (items.isNotEmpty)
                                          ...items.map((item) {
                                            final itemMap = item is Map<String, dynamic> ? item : {};
                                            return ListTile(
                                              leading: itemMap['imageUrl']?.toString().trim().isNotEmpty == true ? Image.network(itemMap['imageUrl'].toString(), width: 50, height: 50, errorBuilder: (context, error, stackTrace) => const Icon(Icons.error)) : const Icon(Icons.image),
                                              title: Text(itemMap['name']?.toString() ?? 'Unknown Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              subtitle: Text("Price: ${itemMap['price']} × ${itemMap['quantity']}Unit. Size: ${itemMap['size'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            );
                                          }).toList(),
                                        if (items.isEmpty) const Text("No items found", style: TextStyle(color: Colors.grey)),
                                        const SizedBox(height: 10),
                                        buildSafeText("Subtotal", order['subtotal']),
                                        buildSafeText("Total", order['total'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        buildSafeText("Delivery fee", order['deliveryCharge'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                        buildCopyableRow("Note", order['note'] ?? 'No note'),
                                        buildSafeText("Time", _getFormattedTime(order)),
                                        buildSafeText("Payment Method", order['paymentMethod']),
                                        if ((order['refundPhone'] ?? order['refund_number'] ?? '').toString().trim().isNotEmpty)
                                          buildCopyableRow("Refund Number", (order['refundPhone'] ?? order['refund_number']).toString().trim()),
                                        buildSafeText("Point in account", order['deliveryPoints']),
                                        buildSafeText("Point in use", order['deliveryPointsUsed'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                        buildSafeText("Request for free delivery", order['freeDeliveryUsed'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                        const SizedBox(height: 8),
                                        const Text("Payment Proof:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (order['paymentProof'] != null && order['paymentProof'].toString().isNotEmpty)
                                          Image.network(order['paymentProof'].toString(), width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Text("Could not load image"))
                                        else
                                          const Text("No payment proof provided", style: TextStyle(color: Colors.grey)),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _rejectOrder(order, index), child: const Text('Reject', style: TextStyle(fontSize: 16, color: Colors.white))),
                                            const SizedBox(width: 40),
                                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _acceptOrder(order, index), child: const Text('Accept', style: TextStyle(fontSize: 16, color: Colors.white))),
                                          ],
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

  String _getFormattedTime(Map<String, dynamic> order) {
    try {
      if (order['timestamp'] != null) return DateFormat('dd-MM-yyyy hh:mm a').format(order['timestamp'].toDate());
      if (order['order_date'] != null) return DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(order['order_date']));
      return 'N/A';
    } catch (e) { return 'Invalid date'; }
  }

  Future<void> _rejectOrder(Map<String, dynamic> order, int index) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final String userEmail = (order['customerEmail'] ?? order['user_email'] ?? '').toString();
      if (userEmail.isEmpty) throw Exception('User email not found for this order');
      final orderLabel = _getNotificationOrderLabel(order);

      // Move to cancelled (preserves all data + images — no permanent delete)
      await _databaseService.moveToCancelled(
        userEmail: userEmail,
        sourceField: 'to_verify',
        order: order,
        cancelledFrom: 'to_verify',
      );

      // If free delivery was used, reset the flag
      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(userEmail, {'freeDeliveryUsed': false});
      }

      await _databaseService.sendPushNotification(email: userEmail, title: 'Order Rejected', body: 'Your order $orderLabel was rejected. Please contact support if you need help.');
      if (mounted) Navigator.pop(context);
      setState(() { orders.removeAt(index); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order moved to Cancelled')));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> order, int index) async {
    final TextEditingController transactionController = TextEditingController();
    final String? transactionId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Transaction ID'),
        content: TextField(controller: transactionController, decoration: const InputDecoration(hintText: 'e.g. STEADFAST-123456', labelText: 'Transaction ID'), textCapitalization: TextCapitalization.characters),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            final id = transactionController.text.trim();
            if (id.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction ID is required'))); return; }
            Navigator.pop(context, id);
          }, child: const Text('Confirm & Accept')),
        ],
      ),
    );
    if (transactionId == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final String userEmail = (order['customerEmail'] ?? order['user_email'] ?? '').toString();
      if (userEmail.isEmpty) throw Exception('User email not found for this order');
      final orderLabel = _getNotificationOrderLabel(order);
      await _databaseService.moveItemsToShip(userEmail: userEmail, transactionId: transactionId, targetOrder: order);
      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(userEmail, {'free_delivery_info': _safeNum(order['deliveryPoints']) - _safeNum(order['baseDeliveryCharge']), 'freeDeliveryUsed': false});
      }
      await _databaseService.sendPushNotification(email: userEmail, title: 'Order Accepted', body: 'Your order $orderLabel has been accepted (TXN: $transactionId) and is now being prepared for shipping.');
      if (mounted) Navigator.pop(context);
      setState(() { orders.removeWhere((o) => o == order); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted and moved to shipping.')));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
