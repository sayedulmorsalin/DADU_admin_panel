import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class Delivered extends StatefulWidget {
  const Delivered({super.key});

  @override
  State<Delivered> createState() => _DeliveredState();
}

class _DeliveredState extends State<Delivered> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> delivered = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final data = await _databaseService.getAllDelivered();

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
      delivered = data;
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      appBar: AppBar(
        title: const Text(
          "Delivered",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 204, 223, 232),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : delivered.isEmpty
          ? const Center(child: Text("No orders found."))
          : ListView.builder(
        itemCount: delivered.length,
        itemBuilder: (context, index) {
          final order = delivered[index];
          final items = getItems(order);

          return Card(
            margin: const EdgeInsets.all(10),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSafeText("Customer Name", order['customerName'] ?? order['user_name'],
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
                      decoration: TextDecoration.none,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}