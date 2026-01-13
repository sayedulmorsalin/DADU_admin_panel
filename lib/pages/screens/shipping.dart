import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final data = await _databaseService.getAllShipped();

    // Safe sorting with null checks
    data.sort((a, b) {
      try {
        final dateA = a['timestamp']?.toDate() ?? a['order_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(a['order_date'])
            : DateTime(0);
        final dateB = b['timestamp']?.toDate() ?? b['order_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(b['order_date'])
            : DateTime(0);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    setState(() {
      orders = data;
      for (var order in data) {
        final orderId = order['order_id'] as String? ?? '';
        _pointControllers.putIfAbsent(orderId, () => TextEditingController());
      }
      isLoading = false;
    });
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
            final orderId = order['order_id'] as String? ?? '';
            final controller = _pointControllers[orderId] ?? TextEditingController();
            final items = getItems(order);
            final userEmail = order['customerEmail'] ?? order['user_email'];

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
                        leading: itemMap['imageUrl'] != null
                            ? Image.network(
                          itemMap['imageUrl']!,
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
                        (order['baseDeliveryCharge'] ?? 0) - (order['deliveryCharge'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    buildSafeText("Request for free delivery", order['freeDeliveryUsed'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),

                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Give point to user",
                        border: OutlineInputBorder(),
                      ),
                    ),
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
                          onPressed: () => _deliverOrder(order, index, userEmail, controller.text),
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

  Future<void> _cancelOrder(Map<String, dynamic> order, int index, String? userEmail) async {
    try {
      if (userEmail == null) throw Exception("User email not found");

      // Remove order from to_ship array
      await _databaseService.removeItemsFromShip(
        userEmail: userEmail,
      );

      // Delete payment proof if not free delivery
      if (order['freeDeliveryUsed'] == false && order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof']);
      }

      // Update UI
      setState(() {
        final orderId = order['order_id'] as String? ?? '';
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

  Future<void> _deliverOrder(Map<String, dynamic> order, int index, String? userEmail, String pointsText) async {
    try {
      if (userEmail == null) throw Exception("User email not found");

      // Move order to completed
      await _databaseService.moveItemsToCompleted(
        userEmail: userEmail,
      );

      // Delete payment proof if not free delivery
      if (order['freeDeliveryUsed'] == false && order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof']);
      }

      // Calculate and update points
      int points = int.tryParse(pointsText) ?? 0;
      int currentPoints = order['deliveryPoints'] ?? 0;
      int baseCharge = order['baseDeliveryCharge'] ?? 0;

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
        final orderId = order['order_id'] as String? ?? '';
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