import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dadu_admin_panel/services/database_service.dart';
import 'package:dadu_admin_panel/services/steadfast_service.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final DatabaseService _databaseService = DatabaseService();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expandedIndices = {};

  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String _searchQuery = '';
  bool _isCheckingStatuses = false;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchOrders() async {
    try {
      final data = await _databaseService.getAllReceived();

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

      // Automatically check Steadfast status for each received order
      _checkSteadfastStatusForOrders(data);
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

  Future<void> _checkSteadfastStatusForOrders(
      List<Map<String, dynamic>> orderList) async {
    if (_isCheckingStatuses) return;
    _isCheckingStatuses = true;

    final SteadfastService steadfastService = SteadfastService();
    final List<Map<String, dynamic>> targets = List.from(orderList);

    for (final order in targets) {
      if (!mounted) break;

      final String? consignmentId =
          (order['consignment_id'] ?? order['consignmentId'])?.toString();
      final String? trackingCode =
          (order['tracking_code'] ?? order['trackingCode'])?.toString();
      final String? invoice = (order['steadfast_invoice'] ??
              order['invoice'] ??
              order['order_id'])
          ?.toString();

      // If there is no data for search, don't do anything (manual check & update)
      if ((consignmentId == null || consignmentId.trim().isEmpty) &&
          (trackingCode == null || trackingCode.trim().isEmpty) &&
          (invoice == null || invoice.trim().isEmpty)) {
        continue;
      }

      final String? deliveryStatus = await steadfastService.checkDeliveryStatus(
        consignmentId: consignmentId,
        trackingCode: trackingCode,
        invoice: invoice,
      );

      // If did not get any result, don't do anything
      if (deliveryStatus == null) {
        continue;
      }

      final statusLower = deliveryStatus.trim().toLowerCase();
      final userEmail =
          (order['customerEmail'] ?? order['user_email'])?.toString() ?? '';

      if (userEmail.isEmpty) continue;

      if (statusLower == 'delivered' || statusLower == 'partial_delivered') {
        // Status changed to delivered -> move to delivered
        await _autoMoveToDelivered(order, userEmail);
      } else if (statusLower == 'cancelled') {
        // Status changed to cancel -> move to cancel page
        await _autoMoveToCancelled(order, userEmail);
      } else {
        // Status is other (in_review, pending, hold, etc.) -> don't do anything
        continue;
      }
    }

    _isCheckingStatuses = false;
  }

  Future<void> _autoMoveToDelivered(
    Map<String, dynamic> order,
    String userEmail,
  ) async {
    try {
      final orderLabel = _getNotificationOrderLabel(order);

      await _databaseService.moveReceiveToCompleted(
        userEmail: userEmail,
        targetOrder: order,
      );

      await _databaseService.recordSale(order);

      num totalFreeCoins = _safeNum(order['totalFreeCoins']);
      if (totalFreeCoins > 0) {
        await _databaseService.updateUserByEmail(userEmail, {
          'free_delivery_info': FieldValue.increment(totalFreeCoins),
        });
      }

      await _databaseService.sendPushNotification(
        email: userEmail,
        title: 'Order Delivered',
        body:
            'Congratulations! Your order $orderLabel has been delivered successfully. Thank you for shopping with us!',
      );

      if (mounted) {
        setState(() {
          orders.removeWhere((item) {
            final matchId = order['order_id'] != null &&
                item['order_id']?.toString() == order['order_id']?.toString();
            final matchTs = order['timestamp'] != null &&
                item['timestamp'] == order['timestamp'];
            return matchId || matchTs;
          });
        });

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              "Order $orderLabel status is delivered on Steadfast -> Moved to Delivered",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Auto move to delivered error: $e");
    }
  }

  Future<void> _autoMoveToCancelled(
    Map<String, dynamic> order,
    String userEmail,
  ) async {
    try {
      final orderLabel = _getNotificationOrderLabel(order);

      await _databaseService.moveToCancelled(
        userEmail: userEmail,
        sourceField: 'to_receive',
        order: order,
        cancelReason: 'Cancelled on Steadfast Courier',
        cancelledFrom: 'steadfast',
      );

      await _databaseService.sendPushNotification(
        email: userEmail,
        title: 'Order Canceled',
        body:
            'Your order $orderLabel has been canceled by Steadfast Courier. Please contact support for more details.',
      );

      if (mounted) {
        setState(() {
          orders.removeWhere((item) {
            final matchId = order['order_id'] != null &&
                item['order_id']?.toString() == order['order_id']?.toString();
            final matchTs = order['timestamp'] != null &&
                item['timestamp'] == order['timestamp'];
            return matchId || matchTs;
          });
        });

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              "Order $orderLabel status is cancelled on Steadfast -> Moved to Cancelled",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Auto move to cancelled error: $e");
    }
  }

  Future<void> _checkSingleOrderSteadfastStatus(Map<String, dynamic> order) async {
    final String? consignmentId =
        (order['consignment_id'] ?? order['consignmentId'])?.toString();
    final String? trackingCode =
        (order['tracking_code'] ?? order['trackingCode'])?.toString();
    final String? invoice = (order['steadfast_invoice'] ??
            order['invoice'] ??
            order['order_id'])
        ?.toString();

    if ((consignmentId == null || consignmentId.trim().isEmpty) &&
        (trackingCode == null || trackingCode.trim().isEmpty) &&
        (invoice == null || invoice.trim().isEmpty)) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
            content: Text("No Steadfast tracking data found for this order.")),
      );
      return;
    }

    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text("Checking Steadfast status...")),
    );

    final SteadfastService steadfastService = SteadfastService();
    final String? status = await steadfastService.checkDeliveryStatus(
      consignmentId: consignmentId,
      trackingCode: trackingCode,
      invoice: invoice,
    );

    if (status == null) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text("Could not retrieve status from Steadfast.")),
      );
      return;
    }

    final statusLower = status.trim().toLowerCase();
    final userEmail =
        (order['customerEmail'] ?? order['user_email'])?.toString() ?? '';

    if (statusLower == 'delivered' || statusLower == 'partial_delivered') {
      if (userEmail.isNotEmpty) {
        await _autoMoveToDelivered(order, userEmail);
      }
    } else if (statusLower == 'cancelled') {
      if (userEmail.isNotEmpty) {
        await _autoMoveToCancelled(order, userEmail);
      }
    } else {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text("Steadfast Status: $status (No auto action needed)")),
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
    addValue(order['transactionId']);
    addValue(order['moderator']);
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
    addValue(order['tracking_code']);
    addValue(order['trackingCode']);
    addValue(order['consignment_id']);
    addValue(order['consignmentId']);

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
      if (searchableText.contains(queryToken)) {
        score += 90;
      }
    }

    return score;
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
            "Receive Orders",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
          ),
          backgroundColor: const Color.fromARGB(255, 204, 223, 232),
          actions: [
            IconButton(
              tooltip: 'Refresh & Check Steadfast Statuses',
              icon: const Icon(Icons.refresh),
              onPressed: fetchOrders,
            ),
          ],
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
                              'Search orders, tracking code, customers, items...',
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

                                    final bool isExpanded = _expandedIndices.contains(index);

                                    final String? trackingCode = (order['tracking_code'] ?? order['trackingCode'])?.toString();
                                    final String? consignmentId = (order['consignment_id'] ?? order['consignmentId'])?.toString();

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      elevation: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: () => _toggleExpansion(index),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      buildSafeText(
                                                        "Order No",
                                                        index + 1,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 20,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                      _buildModeratorBadge(order['moderator']),
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
                                                        "Phone",
                                                        order['phone'] ??
                                                            order['user_phone'],
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 20,
                                                        ),
                                                      ),
                                                      if (trackingCode != null && trackingCode.isNotEmpty)
                                                        buildSafeText(
                                                          "Tracking Code",
                                                          trackingCode,
                                                          style: const TextStyle(
                                                            color: Colors.indigo,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      if (consignmentId != null && consignmentId.isNotEmpty)
                                                        buildSafeText(
                                                          "Consignment ID",
                                                          consignmentId,
                                                          style: const TextStyle(
                                                            color: Colors.deepPurple,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      buildSafeText(
                                                        "Item Count",
                                                        items.length,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors.blue,
                                                        ),
                                                      ),
                                                      if (order['transactionId'] != null)
                                                        buildSafeText(
                                                          "Transaction ID",
                                                          order['transactionId'],
                                                          style: const TextStyle(
                                                            color: Colors.teal,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
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
                                              buildSafeText(
                                                "Email",
                                                order['customerEmail'] ??
                                                    order['user_email'],
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
                                              Text(
                                                "Items: (${items.length})",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (items.isNotEmpty)
                                                ...items.map((item) {
                                                  final itemMap =
                                                      item is Map<String, dynamic>
                                                          ? item
                                                          : {};
                                                  return ListTile(
                                                    leading:
                                                        itemMap['imageUrl'] !=
                                                                null
                                                            ? Image.network(
                                                              itemMap['imageUrl'],
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
                                                order['deliveryPointsUsed'],
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
                                              Wrap(
                                                alignment: WrapAlignment.center,
                                                spacing: 12,
                                                runSpacing: 10,
                                                children: [
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                    ),
                                                    onPressed:
                                                        () => _cancelOrder(
                                                          order,
                                                          userEmail,
                                                        ),
                                                    child: const Text(
                                                      'Canceled',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.orangeAccent,
                                                    ),
                                                    onPressed:
                                                        () => _checkSingleOrderSteadfastStatus(order),
                                                    child: const Text(
                                                      'Check Status',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                    onPressed:
                                                        () => _completeOrder(
                                                          order,
                                                          userEmail,
                                                        ),
                                                    child: const Text(
                                                      'Delivered',
                                                      style: TextStyle(
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
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  String _getNotificationOrderLabel(Map<String, dynamic> order) {
    final dynamic explicitOrderId = order['order_id'];
    if (explicitOrderId != null &&
        explicitOrderId.toString().trim().isNotEmpty) {
      return explicitOrderId.toString().trim();
    }

    final dynamic phone = order['phone'] ?? order['user_phone'];
    if (phone != null && phone.toString().trim().isNotEmpty) {
      return phone.toString().trim();
    }

    return 'your order';
  }

  Future<void> _cancelOrder(
    Map<String, dynamic> order,
    String userEmail,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (userEmail.isEmpty) throw Exception("User email not found");
      final orderLabel = _getNotificationOrderLabel(order);

      // Move to cancelled array (preserves all data + images — no permanent delete)
      await _databaseService.moveToCancelled(
        userEmail: userEmail,
        sourceField: 'to_receive',
        order: order,
        cancelledFrom: 'to_receive',
      );

      await _databaseService.sendPushNotification(
        email: userEmail,
        title: 'Order Canceled',
        body:
            'Your order $orderLabel has been canceled. Please contact support for more details.',
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      setState(() {
        orders.removeWhere((item) => item['order_id'] == order['order_id']);
      });
      _scaffoldMessengerKey.currentState!.showSnackBar(
        const SnackBar(content: Text("Order moved to Cancelled")),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _completeOrder(
    Map<String, dynamic> order,
    String userEmail,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (userEmail.isEmpty) throw Exception("User email not found");
      final orderLabel = _getNotificationOrderLabel(order);

      // 1. Move the order in the user's document
      await _databaseService.moveReceiveToCompleted(
        userEmail: userEmail,
        targetOrder: order,
      );

      // 2. Record the sale for analytics (includes commission lookup)
      await _databaseService.recordSale(order);

      // Points calculation
      num totalFreeCoins = _safeNum(order['totalFreeCoins']);

      await _databaseService.updateUserByEmail(userEmail, {
        'free_delivery_info': FieldValue.increment(totalFreeCoins),
      });

      await _databaseService.sendPushNotification(
        email: userEmail,
        title: 'Order Delivered',
        body:
            'Congratulations! Your order $orderLabel has been delivered successfully. Thank you for shopping with us!',
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      setState(() {
        orders.removeWhere((item) => item['order_id'] == order['order_id']);
      });

      _scaffoldMessengerKey.currentState!.showSnackBar(
        const SnackBar(content: Text("Order marked as Delivered")),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
