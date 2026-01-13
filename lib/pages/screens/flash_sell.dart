import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dadu_admin_panel/pages/services/database_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class FlashSell extends StatefulWidget {
  const FlashSell({super.key});

  @override
  State<FlashSell> createState() => _FlashSellState();
}

class _FlashSellState extends State<FlashSell> {
  late Timer _timer;

  DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> products = [];

  // -----------------------------
  // FORMAT REMAINING TIME
  // -----------------------------
  String formatRemainingTime(dynamic value) {
    if (value == null) return "No flash";

    DateTime endTime;

    // If the value is a Firestore Timestamp
    if (value is Timestamp) {
      endTime = value.toDate();
    }
    // If the value is a String (old saved data)
    else if (value is String) {
      endTime = DateTime.parse(value);
    } else {
      return "Invalid date";
    }

    final now = DateTime.now();
    Duration diff = endTime.difference(now);

    if (diff.isNegative) return "Expired";

    String two(int n) => n.toString().padLeft(2, "0");

    return "${two(diff.inHours)}:${two(diff.inMinutes % 60)}:${two(diff.inSeconds % 60)}";
  }


  // -----------------------------
  // INIT STATE
  // -----------------------------
  @override
  void initState() {
    super.initState();
    _loadProducts();

    // Timer for live countdown
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  // -----------------------------
  // DISPOSE
  // -----------------------------
  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    super.dispose();
  }

  // -----------------------------
  // LOAD PRODUCTS
  // -----------------------------
  Future<void> _loadProducts() async {
    try {
      final loadedProducts = await _dbService.getProducts();
      setState(() => products = loadedProducts);
    } catch (e) {
      _showSnackBar("Failed to load products: ${e.toString()}");
    }
  }

  // -----------------------------
  // SNACKBAR
  // -----------------------------
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // -----------------------------
  // FLASH SELL DIALOG
  // -----------------------------
  void showTextDateTimeDialog(Map<String, dynamic> product) {
    final TextEditingController textController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Write discount price"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      labelText: "new price",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() => selectedDate = pickedDate);
                      }
                    },
                    child: Text(selectedDate == null
                        ? "Pick Date"
                        : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),
                  ),

                  SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setState(() => selectedTime = pickedTime);
                      }
                    },
                    child: Text(selectedTime == null
                        ? "Pick Time"
                        : selectedTime!.format(context)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    DateTime? finalDateTime;
                    if (selectedDate != null && selectedTime != null) {
                      finalDateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                    }

                    final String productId = product["id"];
                    print(productId);
                    final String newPrice = textController.text.trim();
                    final String oldPrice = product["price"];

                    try {
                      await _dbService.updateProduct(productId, {
                        "flashSell": true,
                        "price": newPrice,
                        "oldPrice": oldPrice,
                        "flash-expire": finalDateTime,
                      });

                      _showSnackBar("Flash sell updated successfully!");
                      _loadProducts();
                    } catch (e) {
                      _showSnackBar("Update failed: $e");
                    }
                  },
                  child: Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Flash Sell",
          style: TextStyle(
            color: Colors.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];

            String countdown = formatRemainingTime(product["flash-expire"]);

            return Card(
              elevation: 4,
              margin: EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            product["image5"] ?? "",
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.broken_image, size: 80),
                          ),
                        ),
                        SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product["name"] ?? "No name",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 5),

                              Text("Price: ${product["price"]}",
                                  style: TextStyle(fontSize: 16)),

                              SizedBox(height: 6),

                              // 🔥 LIVE COUNTDOWN
                              Text(
                                "Remaining: $countdown",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: countdown == "Expired"
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => showTextDateTimeDialog(product),
                          child: Text("Flash Sell"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
