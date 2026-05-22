import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/database_service.dart';
import '../services/image_delete_service.dart';

class Shipping extends StatefulWidget {
  const Shipping({super.key});

  @override
  State<Shipping> createState() => _ShippingState();
}

class _ShippingState extends State<Shipping> {
  final DatabaseService _databaseService = DatabaseService();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();
  final Map<String, TextEditingController> _pointControllers = {};

  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  @override
  void dispose() {
    // Dispose all text controllers
    _pointControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> fetchOrders() async {
    try {
      final data = await _databaseService.getAllShipped();

      data.sort((a, b) {
        final dateA = _readOrderDate(a);
        final dateB = _readOrderDate(b);
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        orders = data;
        for (var order in data) {
          final orderId = order['order_id']?.toString() ?? '';
          _pointControllers.putIfAbsent(orderId, () => TextEditingController());
        }
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text("Failed to load orders: $e")),
      );
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

  // Safe method to get items list
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

  // Safe text display method
  Widget buildSafeText(String label, dynamic value, {TextStyle? style}) {
    return Text(
      "$label: ${value?.toString() ?? 'N/A'}",
      style: style ?? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  String _getFormattedTime(Map<String, dynamic> order) {
    try {
      if (order['timestamp'] != null) {
        return DateFormat('dd-MM-yyyy hh:mm a').format(order['timestamp'].toDate());
      } else if (order['order_date'] != null) {
        return DateFormat('dd-MM-yyyy hh:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(order['order_date']));
      }
      return 'N/A';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 204, 223, 232),
        appBar: AppBar(
          title: const Text(
            "Shipping Orders",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
          ),
          backgroundColor: const Color.fromARGB(255, 204, 223, 232),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
            ? const Center(child: Text("No orders found."))
            : ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderId = order['order_id']?.toString() ?? '';
            final items = getItems(order);
            final userEmail = (order['customerEmail'] ?? order['user_email'])?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.all(10),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSafeText("Customer", order['customerName'] ?? order['user_name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    buildSafeText("Email", order['customerEmail'] ?? order['user_email']),
                    buildSafeText("Phone", order['phone'] ?? order['user_phone'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    buildSafeText("District", order['district'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    buildSafeText("Thana", order['thana'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    buildSafeText("Address", order['address'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),

                    const SizedBox(height: 10),
                    const Text(
                      "Items:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    // Safe items display
                    if (items.isNotEmpty) ...items.map((item) {
                      final itemMap = item is Map<String, dynamic> ? item : {};
                      return ListTile(
                        leading: itemMap['imageUrl']?.toString().trim().isNotEmpty == true
                            ? Image.network(
                          itemMap['imageUrl'].toString(),
                          width: 50,
                          height: 50,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error),
                        )
                            : const Icon(Icons.image),
                        title: Text(
                          itemMap['name']?.toString() ?? 'Unknown Product',
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
                      const Text("No items found", style: TextStyle(color: Colors.grey)),

                    const SizedBox(height: 10),
                    buildSafeText("Subtotal", order['subtotal']),
                    buildSafeText("Total", order['total'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    buildSafeText("Delivery fee", order['deliveryCharge'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),

                    // Safe timestamp display
                    buildSafeText("Time", _getFormattedTime(order)),

                    buildSafeText("Payment Method", order['paymentMethod']),
                    buildSafeText("Point in account", order['deliveryPoints']),
                    buildSafeText("Point in use",
                        _safeNum(order['baseDeliveryCharge']) - _safeNum(order['deliveryCharge']),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    buildSafeText("Request for free delivery", order['freeDeliveryUsed'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel Button
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
                          onPressed: () => _cancelOrder(order, index, userEmail),
                          child: const Text(
                            'Canceled',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        // Delivered Button
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
                          onPressed: () => _deliverOrder(order, index, userEmail),
                          child: const Text(
                            'Delivered',
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
      ),
    );
  }

  Future<void> _cancelOrder(Map<String, dynamic> order, int index, String userEmail) async {
    try {
      if (userEmail.isEmpty) throw Exception("User email not found");

      // Remove order from to_ship array
      await _databaseService.removeItemsFromShip(
        userEmail: userEmail,
      );

      // Delete payment proof if not free delivery
      if (order['freeDeliveryUsed'] == false && order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof'].toString());
      }

      // Update UI
      setState(() {
        final orderId = order['order_id']?.toString() ?? '';
        _pointControllers.remove(orderId);
        orders.removeAt(index);
      });

      _scaffoldMessengerKey.currentState!.showSnackBar(
        const SnackBar(content: Text("Order canceled successfully")),
      );
    } catch (e) {
      _scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _deliverOrder(Map<String, dynamic> order, int index, String userEmail) async {
    try {
      if (userEmail.isEmpty) throw Exception("User email not found");

      // Move order to completed
      await _databaseService.moveItemsToCompleted(
        userEmail: userEmail,
      );

      // Delete payment proof if not free delivery
      if (order['freeDeliveryUsed'] == false && order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof'].toString());
      }

      // Calculate and update points
      int points = 10;
      num currentPoints = _safeNum(order['deliveryPoints']);
      num baseCharge = _safeNum(order['baseDeliveryCharge']);

      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(
          userEmail,
          {
            'free_delivery_info': (currentPoints - baseCharge) + points,
          },
        );
      } else {
        await _databaseService.updateUserByEmail(
          userEmail,
          {
            'free_delivery_info': currentPoints + points,
          },
        );
      }

      // Update UI
      setState(() {
        final orderId = order['order_id']?.toString() ?? '';
        _pointControllers.remove(orderId);
        orders.removeAt(index);
      });

      _scaffoldMessengerKey.currentState!.showSnackBar(
        const SnackBar(content: Text("Order delivered successfully")),
      );
    } catch (e) {
      _scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
