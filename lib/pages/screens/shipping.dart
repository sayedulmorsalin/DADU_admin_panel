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
  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _pointControllers = {};

  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final value =
        order['timestamp'] ?? order['created_at'] ?? order['order_date'];
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
      style:
          style ?? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _normalizeSearchText(_searchQuery);
    if (query.isEmpty) return orders;

    final scoredOrders =
        orders
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
      if (text != null && text.isNotEmpty) {
        buffer.write('$text ');
      }
    }

    addValue(order['order_id']);
    addValue(order['customerName']);
    addValue(order['user_name']);
    addValue(order['customerEmail']);
    addValue(order['user_email']);
    addValue(order['phone']);
    addValue(order['user_phone']);
    addValue(order['district']);
    addValue(order['thana']);
    addValue(order['address']);
    addValue(order['paymentMethod']);
    addValue(order['deliveryPoints']);

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
    final searchableTokens =
        searchableText.split(' ').where((token) => token.isNotEmpty).toList();
    int score = 0;

    for (final queryToken in queryTokens) {
      int bestTokenScore = 0;

      for (final searchableToken in searchableTokens) {
        if (searchableToken.contains(queryToken)) {
          bestTokenScore = 90;
          break;
        }

        final distance = _levenshteinDistance(queryToken, searchableToken);
        final maxLength =
            queryToken.length > searchableToken.length
                ? queryToken.length
                : searchableToken.length;
        final tokenScore =
            maxLength == 0 ? 0 : ((1 - distance / maxLength) * 70).round();

        if (tokenScore > bestTokenScore) {
          bestTokenScore = tokenScore;
        }
      }

      score += bestTokenScore;
    }

    return score;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previousRow = List<int>.generate(b.length + 1, (index) => index);

    for (var i = 0; i < a.length; i++) {
      final currentRow = List<int>.filled(b.length + 1, i + 1);

      for (var j = 0; j < b.length; j++) {
        final insertionCost = currentRow[j] + 1;
        final deletionCost = previousRow[j + 1] + 1;
        final substitutionCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
        currentRow[j + 1] = [
          insertionCost,
          deletionCost,
          substitutionCost,
        ].reduce((value, element) => value < element ? value : element);
      }

      for (var j = 0; j < previousRow.length; j++) {
        previousRow[j] = currentRow[j];
      }
    }

    return previousRow[b.length];
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

  @override
  Widget build(BuildContext context) {
    final visibleOrders = _filteredOrders;

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
        body:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search orders, customers, items, district...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
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
                        child:
                            visibleOrders.isEmpty
                                ? Center(
                                  child: Text(
                                    orders.isEmpty
                                        ? 'No orders found.'
                                        : 'No matching orders found.',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: visibleOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = visibleOrders[index];
                                    final items = getItems(order);
                                    final userEmail =
                                        (order['customerEmail'] ??
                                                order['user_email'])
                                            ?.toString() ??
                                        '';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      elevation: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            buildSafeText(
                                              "Customer",
                                              order['customerName'] ??
                                                  order['user_name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            buildSafeText(
                                              "Email",
                                              order['customerEmail'] ??
                                                  order['user_email'],
                                            ),
                                            buildSafeText(
                                              "Phone",
                                              order['phone'] ??
                                                  order['user_phone'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            buildSafeText(
                                              "District",
                                              order['district'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            buildSafeText(
                                              "Thana",
                                              order['thana'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            buildSafeText(
                                              "Address",
                                              order['address'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),

                                            const SizedBox(height: 10),
                                            const Text(
                                              "Items:",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),

                                            // Safe items display
                                            if (items.isNotEmpty)
                                              ...items.map((item) {
                                                final itemMap =
                                                    item is Map<String, dynamic>
                                                        ? item
                                                        : {};
                                                return ListTile(
                                                  leading:
                                                      itemMap['imageUrl']
                                                                  ?.toString()
                                                                  .trim()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? Image.network(
                                                            itemMap['imageUrl']
                                                                .toString(),
                                                            width: 50,
                                                            height: 50,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) => const Icon(
                                                                  Icons.error,
                                                                ),
                                                          )
                                                          : const Icon(
                                                            Icons.image,
                                                          ),
                                                  title: Text(
                                                    itemMap['name']
                                                            ?.toString() ??
                                                        'Unknown Product',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    "Price: ${itemMap['price']} × ${itemMap['quantity']}Unit. Size: ${itemMap['size'] ?? 'N/A'}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),

                                            if (items.isEmpty)
                                              const Text(
                                                "No items found",
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),

                                            const SizedBox(height: 10),
                                            buildSafeText(
                                              "Subtotal",
                                              order['subtotal'],
                                            ),
                                            buildSafeText(
                                              "Total",
                                              order['total'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
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

                                            // Safe timestamp display
                                            buildSafeText(
                                              "Time",
                                              _getFormattedTime(order),
                                            ),

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
                                              _safeNum(
                                                    order['baseDeliveryCharge'],
                                                  ) -
                                                  _safeNum(
                                                    order['deliveryCharge'],
                                                  ),
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

                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // Cancel Button
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.redAccent,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 24,
                                                          vertical: 12,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed:
                                                      () => _cancelOrder(
                                                        order,
                                                        userEmail,
                                                      ),
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
                                                    backgroundColor:
                                                        Colors.blue,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 24,
                                                          vertical: 12,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed:
                                                      () => _deliverOrder(
                                                        order,
                                                        userEmail,
                                                      ),
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
                    ],
                  ),
                ),
      ),
    );
  }

  Future<void> _cancelOrder(
    Map<String, dynamic> order,
    String userEmail,
  ) async {
    try {
      if (userEmail.isEmpty) throw Exception("User email not found");

      // Remove order from to_ship array
      await _databaseService.removeItemsFromShip(userEmail: userEmail);

      // Delete payment proof if not free delivery
      if (order['freeDeliveryUsed'] == false && order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof'].toString());
      }

      // Update UI
      setState(() {
        final orderId = order['order_id']?.toString() ?? '';
        _pointControllers.remove(orderId);
        orders.removeWhere((item) => item['order_id']?.toString() == orderId);
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

  Future<void> _deliverOrder(
    Map<String, dynamic> order,
    String userEmail,
  ) async {
    try {
      if (userEmail.isEmpty) throw Exception("User email not found");

      // Move order to completed
      await _databaseService.moveItemsToCompleted(userEmail: userEmail);

      // Delete payment proof if not free delivery
      if (order['freeDeliveryUsed'] == false && order['paymentProof'] != null) {
        deleteImageFromCloudinaryUrl(order['paymentProof'].toString());
      }

      // Calculate and update points
      int points = 10;
      num currentPoints = _safeNum(order['deliveryPoints']);
      num baseCharge = _safeNum(order['baseDeliveryCharge']);

      if (order['freeDeliveryUsed'] == true) {
        await _databaseService.updateUserByEmail(userEmail, {
          'free_delivery_info': (currentPoints - baseCharge) + points,
        });
      } else {
        await _databaseService.updateUserByEmail(userEmail, {
          'free_delivery_info': currentPoints + points,
        });
      }

      // Update UI
      setState(() {
        final orderId = order['order_id']?.toString() ?? '';
        _pointControllers.remove(orderId);
        orders.removeWhere((item) => item['order_id']?.toString() == orderId);
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
