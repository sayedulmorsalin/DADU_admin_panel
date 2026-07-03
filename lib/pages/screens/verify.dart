import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import '../services/database_service.dart';
import '../services/image_delete_service.dart';
import '../services/steadfast_service.dart';

class Verify extends StatefulWidget {
  const Verify({super.key});

  @override
  State<Verify> createState() => _VerifyState();
}

class _VerifyState extends State<Verify> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    fetchOrders();
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

  // Generic copy function for all fields
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
    if (value == null) {
      return 'N/A';
    }
    final String text = value.toString();
    if (text.trim().isEmpty) {
      return 'N/A';
    }
    return text;
  }

  String _buildOrderSummary(Map<String, dynamic> order, List<dynamic> items) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Customer Name: ${_formatValue(order['customerName'] ?? order['user_name'])}',
    );
    buffer.writeln(
      'Phone: ${_formatValue(order['phone'] ?? order['user_phone'])}',
    );
    buffer.writeln('District: ${_formatValue(order['district'])}');
    buffer.writeln('Thana: ${_formatValue(order['thana'])}');
    buffer.writeln('Address: ${_formatValue(order['address'])}');
    buffer.writeln(
      'Email: ${_formatValue(order['customerEmail'] ?? order['user_email'])}',
    );
    buffer.writeln('Time: ${_getFormattedTime(order)}');
    buffer.writeln('Payment Method: ${_formatValue(order['paymentMethod'])}');
    buffer.writeln('Subtotal: ${_formatValue(order['subtotal'])}');
    buffer.writeln('Total: ${_formatValue(order['total'])}');
    buffer.writeln('Delivery fee: ${_formatValue(order['deliveryCharge'])}');
    buffer.writeln(
      'Point in account: ${_formatValue(order['deliveryPoints'])}',
    );
    buffer.writeln(
      'Point in use: ${_formatValue(_safeNum(order['baseDeliveryCharge']) - _safeNum(order['deliveryCharge']))}',
    );
    buffer.writeln(
      'Request for free delivery: ${_formatValue(order['freeDeliveryUsed'])}',
    );
    buffer.writeln('Payment Proof: ${_formatValue(order['paymentProof'])}');
    buffer.writeln('Items:');

    if (items.isEmpty) {
      buffer.writeln('- No items found');
    } else {
      for (final item in items) {
        final itemMap =
            item is Map<String, dynamic> ? item : <String, dynamic>{};
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
    if (explicitOrderId != null && explicitOrderId.toString().trim().isNotEmpty) {
      return explicitOrderId.toString().trim();
    }

    final dynamic phone = order['phone'] ?? order['user_phone'];
    if (phone != null && phone.toString().trim().isNotEmpty) {
      return phone.toString().trim();
    }

    return 'your order';
  }

  Future<void> _copyAllOrderInfo(Map<String, dynamic> order) async {
    final List<dynamic> items = getItems(order);
    final String summary = _buildOrderSummary(order, items);
    try {
      await FlutterClipboard.copy(summary);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All order info copied to clipboard.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy order info: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      appBar: AppBar(
        title: const Text(
          "Verify Orders",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : orders.isEmpty
              ? const Center(child: Text("No orders found."))
              : ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final items = getItems(order);
                  final email =
                      (order['customerEmail'] ?? order['user_email'] ?? '')
                          .toString();
                  final customerName =
                      (order['customerName'] ?? order['user_name'] ?? 'N/A')
                          .toString();
                  final phone =
                      (order['phone'] ?? order['user_phone'] ?? 'N/A')
                          .toString();
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
                                    buildSafeText("Customer Name", customerName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    buildSafeText("Phone", phone),
                                  ],
                                ),
                                Icon(isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more),
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
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            buildCopyableRow(
                              "District",
                              order['district'] ?? 'N/A',
                            ),
                            buildCopyableRow("Thana", order['thana'] ?? 'N/A'),
                            buildCopyableRow(
                              "Address",
                              order['address'] ?? 'N/A',
                            ),
                            Row(
                              children: [
                                Expanded(child: buildSafeText("Email", email)),
                                if (email.isNotEmpty && email != 'N/A')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.content_copy,
                                      size: 18,
                                    ),
                                    onPressed: () => _copyEmail(email),
                                    tooltip: 'Copy email',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Items:",
                              style: TextStyle(
                                decoration: TextDecoration.none,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (items.isNotEmpty)
                              ...items.map((item) {
                                final itemMap =
                                    item is Map<String, dynamic> ? item : {};
                                return ListTile(
                                  leading: itemMap['imageUrl']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? Image.network(
                                          itemMap['imageUrl'].toString(),
                                          width: 50,
                                          height: 50,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(Icons.error),
                                        )
                                      : const Icon(Icons.image),
                                  title: Text(
                                    itemMap['name']?.toString() ??
                                        'Unknown Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Price: ${itemMap['price']} × ${itemMap['quantity']}Unit. Size: ${itemMap['size'] ?? 'N/A'}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              }).toList(),
                            if (items.isEmpty)
                              const Text(
                                "No items found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(height: 10),
                            buildSafeText("Subtotal", order['subtotal']),
                            buildSafeText(
                              "Total",
                              order['total'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            buildSafeText(
                              "Delivery fee",
                              order['deliveryCharge'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue,
                              ),
                            ),
                            buildSafeText("Time", _getFormattedTime(order)),
                            buildSafeText(
                              "Payment Method",
                              order['paymentMethod'],
                            ),
                            buildSafeText(
                              "Point in account",
                              order['deliveryPoints'],
                            ),
                            buildSafeText(
                              "Point in use",
                              _safeNum(order['baseDeliveryCharge']) -
                                  _safeNum(order['deliveryCharge']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue,
                              ),
                            ),
                            buildSafeText(
                              "Request for free delivery",
                              order['freeDeliveryUsed'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Payment Proof:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (order['paymentProof'] != null &&
                                order['paymentProof'].toString().isNotEmpty)
                              Image.network(
                                order['paymentProof'].toString(),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text("Could not load image"),
                              )
                            else
                              const Text(
                                "No payment proof provided",
                                style: TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => _rejectOrder(order, index),
                                  child: const Text(
                                    'Reject',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => _acceptOrder(order, index),
                                  child: const Text(
                                    'Accept',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  String _getFormattedTime(Map<String, dynamic> order) {
    try {
      if (order['timestamp'] != null) {
        return DateFormat(
          'dd-MM-yyyy hh:mm a',
        ).format(order['timestamp'].toDate());
      } else if (order['order_date'] != null) {
        return DateFormat(
          'dd-MM-yyyy hh:mm a',
        ).format(DateTime.fromMillisecondsSinceEpoch(order['order_date']));
      }
      return 'N/A';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _rejectOrder(Map<String, dynamic> order, int index) async {
    try {
      final String userEmail =
          (order['customerEmail'] ?? order['user_email'] ?? '').toString();
      if (userEmail.isEmpty) {
        throw Exception('User email not found for this order');
      }
      final orderLabel = _getNotificationOrderLabel(order);

      if(true){
        await _databaseService.removeItemsFromVerify(userEmail: userEmail);
      }

      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(userEmail, {
          'freeDeliveryUsed': false,
        });
      } else if (order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof'].toString());
      }

      await _databaseService.sendPushNotification(
        email: userEmail,
        title: 'Order Rejected',
        body: 'Your order $orderLabel was rejected. Please contact support if you need help.',
      );

      setState(() {
        orders.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order rejected successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> order, int index) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final String userEmail =
          (order['customerEmail'] ?? order['user_email'] ?? '').toString();
      if (userEmail.isEmpty) {
        throw Exception('User email not found for this order');
      }
      final orderLabel = _getNotificationOrderLabel(order);

      // --- Steadfast Courier Integration ---
      final SteadfastService steadfastService = SteadfastService();
      
      // Construct address with District and Thana
      String fullAddress = order['address'] ?? '';
      if (order['thana'] != null) fullAddress += ', ${order['thana']}';
      if (order['district'] != null) fullAddress += ', ${order['district']}';
      
      if (fullAddress.length > 250) {
        fullAddress = fullAddress.substring(0, 250);
      }

      // Determine COD amount based on payment method
      double codAmount = 0;
      final String paymentMethod = order['paymentMethod']?.toString().toLowerCase() ?? '';
      if (paymentMethod == 'cod' || paymentMethod.contains('cash')) {
        codAmount = _safeNum(order['total']).toDouble();
      }

      // Generate a unique invoice if not present
      String invoice = order['orderId']?.toString() ?? order['order_id']?.toString() ?? 
                       'INV-${DateTime.now().millisecondsSinceEpoch}';

      // Clean phone number (Must be 11 digits)
      String phone = (order['phone'] ?? order['user_phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('88')) {
        phone = phone.substring(2);
      }
      if (phone.length > 11) {
        phone = phone.substring(phone.length - 11);
      }

      if (phone.length != 11) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid phone number: $phone. Must be 11 digits.')),
        );
        return;
      }

      String recipientName = (order['customerName'] ?? order['user_name'] ?? 'Customer').toString();
      if (recipientName.length > 100) {
        recipientName = recipientName.substring(0, 100);
      }

      try {
        await steadfastService.createOrder(
          invoice: invoice,
          recipientName: recipientName,
          recipientPhone: phone,
          recipientAddress: fullAddress,
          codAmount: codAmount,
          note: order['note'] ?? 'Deliver as soon as possible',
        );
      } catch (e) {
        print("Steadfast Error: $e");
        // We might want to continue even if Steadfast fails, or stop here.
        // For now, let's stop and inform the user.
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Steadfast Error: $e. Order not accepted.')),
        );
        return;
      }
      // --- End Steadfast Integration ---

      await _databaseService.moveItemsToShip(userEmail: userEmail);

      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(userEmail, {
          'free_delivery_info':
              _safeNum(order['deliveryPoints']) -
              _safeNum(order['baseDeliveryCharge']),
          'freeDeliveryUsed': false,
        });
      }

      await _databaseService.sendPushNotification(
        email: userEmail,
        title: 'Order Accepted',
        body: 'Your order $orderLabel has been accepted and is now being prepared for shipping.',
      );

      Navigator.pop(context); // Close loading dialog

      setState(() {
        orders.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted and sent to Steadfast successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
