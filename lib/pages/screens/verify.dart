import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import '../services/database_service.dart';
import '../services/image_delete_service.dart';

class Verify extends StatefulWidget {
  const Verify({super.key});

  @override
  State<Verify> createState() => _VerifyState();
}

class _VerifyState extends State<Verify> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      final data = await _databaseService.getAllOrdersVerify();

      data.sort((a, b) {
        try {
          final dateA =
              a['timestamp']?.toDate() ??
              (a['order_date'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(a['order_date'])
                  : DateTime(0));
          final dateB =
              b['timestamp']?.toDate() ??
              (b['order_date'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(b['order_date'])
                  : DateTime(0));
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        orders = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching orders: $e");
      setState(() {
        isLoading = false;
      });
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

  Widget buildCopyableRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: buildSafeText(label, value)),
        if (value.isNotEmpty && value != 'N/A')
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            onPressed: () => _copyToClipboard(label, value),
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
      'Point in use: ${_formatValue((order['baseDeliveryCharge'] ?? 0) - (order['deliveryCharge'] ?? 0))}',
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
                      order['customerEmail'] ?? order['user_email'] ?? '';
                  final customerName =
                      order['customerName'] ?? order['user_name'] ?? 'N/A';
                  final phone = order['phone'] ?? order['user_phone'] ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.all(10),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          buildCopyableRow("Customer Name", customerName),
                          buildCopyableRow("Phone", phone),
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
                                leading:
                                    itemMap['imageUrl'] != null
                                        ? Image.network(
                                          itemMap['imageUrl']!,
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
                            (order['baseDeliveryCharge'] ?? 0) -
                                (order['deliveryCharge'] ?? 0),
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
                              errorBuilder:
                                  (context, error, stackTrace) =>
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
      final userEmail = order['customerEmail'] ?? order['user_email'];
      final userDocumentId = order['user_document_id'];
      final orderId = order['order_id'];

      if (userDocumentId != null && orderId != null) {
        await _databaseService.removeItemsFromVerify(userEmail: userEmail!);
      }

      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(userEmail!, {
          'freeDeliveryUsed': false,
        });
      } else if (order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof']);
      }

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
    try {
      final userEmail = order['customerEmail'] ?? order['user_email'];

      await _databaseService.moveItemsToShip(userEmail: userEmail!);

      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(userEmail, {
          'free_delivery_info':
              (order['deliveryPoints'] ?? 0) -
              (order['baseDeliveryCharge'] ?? 0),
          'freeDeliveryUsed': false,
        });
      }

      setState(() {
        orders.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
