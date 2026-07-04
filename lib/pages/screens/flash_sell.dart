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
  DateTime? _flashSellTimer;
  bool _loadingTimer = false;

  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String formatRemainingTime(DateTime? endTime) {
    if (endTime == null) return "No timer set";

    final now = DateTime.now();
    Duration diff = endTime.difference(now);

    if (diff.isNegative) return "Expired";

    String two(int n) => n.toString().padLeft(2, "0");

    return "${two(diff.inHours)}:${two(diff.inMinutes % 60)}:${two(diff.inSeconds % 60)}";
  }

  @override
  void initState() {
    super.initState();
    _loadFlashSellTimer();
    _loadProducts();
    _scrollController.addListener(_onScroll);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreProducts();
    }
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final loadedProducts = await _dbService.getProducts(page: _currentPage);
      loadedProducts.sort((a, b) {
        final isAFlash = a['flashSell'] == true;
        final isBFlash = b['flashSell'] == true;

        if (isAFlash && !isBFlash) return -1;
        if (!isAFlash && isBFlash) return 1;

        return 0;
      });
      if (!mounted) return;
      setState(() {
        products = loadedProducts;
        if (loadedProducts.length < 20) {
          _hasMore = false;
        }
      });
    } catch (e) {
      _showSnackBar("Failed to load products: ${e.toString()}");
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final loadedProducts = await _dbService.getProducts(page: nextPage);

      setState(() {
        if (loadedProducts.isEmpty) {
          _hasMore = false;
        } else {
          products.addAll(loadedProducts);
          // Optional: re-sort if needed, but might be jarring during scroll
          /*
          products.sort((a, b) {
            final isAFlash = a['flashSell'] == true;
            final isBFlash = b['flashSell'] == true;
            if (isAFlash && !isBFlash) return -1;
            if (!isAFlash && isBFlash) return 1;
            return 0;
          });
          */
          _currentPage = nextPage;
          if (loadedProducts.length < 20) {
            _hasMore = false;
          }
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      _showSnackBar("Failed to load more products: ${e.toString()}");
    }
  }

  Future<void> _loadFlashSellTimer() async {
    setState(() => _loadingTimer = true);

    try {
      final timer = await _dbService.getFlashSellTimer();
      if (!mounted) return;
      setState(() => _flashSellTimer = timer);
    } catch (e) {
      _showSnackBar("Failed to load timer: $e");
    } finally {
      if (mounted) {
        setState(() => _loadingTimer = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveFlashSellTimer(DateTime timer) async {
    try {
      await _dbService.setFlashSellTimer(timer);
      _showSnackBar("Flash sell timer saved successfully!");
      await _loadFlashSellTimer();
    } catch (e) {
      _showSnackBar("Timer save failed: $e");
    }
  }

  Future<void> _deleteFlashSellTimer() async {
    try {
      await _dbService.deleteFlashSellTimer();
      _showSnackBar("Flash sell timer deleted successfully!");
      await _loadFlashSellTimer();
    } catch (e) {
      _showSnackBar("Timer delete failed: $e");
    }
  }

  void _showTimerDialog() {
    DateTime? selectedDate = _flashSellTimer?.toLocal();
    TimeOfDay? selectedTime =
        _flashSellTimer == null
            ? null
            : TimeOfDay.fromDateTime(_flashSellTimer!.toLocal());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                _flashSellTimer == null
                    ? "Set flash sell timer"
                    : "Modify flash sell timer",
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() => selectedDate = pickedDate);
                      }
                    },
                    child: Text(
                      selectedDate == null
                          ? "Pick Date"
                          : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setState(() => selectedTime = pickedTime);
                      }
                    },
                    child: Text(
                      selectedTime == null
                          ? "Pick Time"
                          : selectedTime!.format(context),
                    ),
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
                    if (selectedDate == null || selectedTime == null) {
                      _showSnackBar("Please pick both date and time");
                      return;
                    }

                    final finalDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );

                    Navigator.pop(context);
                    await _saveFlashSellTimer(finalDateTime);
                  },
                  child: Text(_flashSellTimer == null ? "Save" : "Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setFlashStatus(
    Map<String, dynamic> product,
    bool isFlash,
  ) async {
    final String productId = product["id"];

    try {
      if (isFlash) {
        await _dbService.removeFromFlashSell(productId, {
          "flashSell": false,
          "price": product["oldPrice"] ?? product["price"],
          "oldPrice": FieldValue.delete(),
          "flash-expire": FieldValue.delete(),
        });
      } else {
        await _dbService.addToFlashSell(productId, {
          "flashSell": true,
          "price": product["newFlashPrice"] ?? product["price"],
          "oldPrice": product["price"],
          "flash-expire": FieldValue.delete(),
        });
      }

      _showSnackBar(
        isFlash
            ? "Removed from flash sell successfully!"
            : "Added to flash sell successfully!",
      );
      await _loadProducts();
    } catch (e) {
      _showSnackBar("Update failed: $e");
    }
  }

  void _confirmFlashAction(Map<String, dynamic> product) {
    final bool isFlash = product["flashSell"] == true;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isFlash
                ? "Remove this product from flash sell?"
                : "Make this product flash sell?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _setFlashStatus(product, isFlash);
              },
              child: Text(isFlash ? "Remove" : "Flash"),
            ),
          ],
        );
      },
    );
  }

  void showFlashPriceDialog(Map<String, dynamic> product) {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Write discount price"),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(
              labelText: "new price",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {
                if (_flashSellTimer == null) {
                  Navigator.pop(context);
                  _showSnackBar("Please set the flash sell timer first.");
                  return;
                }

                Navigator.pop(context);

                final String productId = product["id"];
                final String newPrice = textController.text.trim();
                final String oldPrice = product["price"];

                try {
                  await _dbService.addToFlashSell(productId, {
                    "flashSell": true,
                    "price": newPrice,
                    "oldPrice": oldPrice,
                    "flash-expire": FieldValue.delete(),
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
  }

  String _formatTimerLabel(DateTime? timer) {
    if (timer == null) return "No timer set";

    final localTimer = timer.toLocal();
    final hour = localTimer.hour.toString().padLeft(2, '0');
    final minute = localTimer.minute.toString().padLeft(2, '0');
    final day = localTimer.day.toString().padLeft(2, '0');
    final month = localTimer.month.toString().padLeft(2, '0');

    return "$day/$month/${localTimer.year} $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final remainingTime = formatRemainingTime(_flashSellTimer);

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
        child: Column(
          children: [
            Card(
              elevation: 3,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _flashSellTimer == null
                                ? "No flash sell timer set"
                                : "Flash sell timer",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            _flashSellTimer == null
                                ? "Set a shared timer for all flash sell products"
                                : "Ends at: ${_formatTimerLabel(_flashSellTimer)}\nRemaining: $remainingTime",
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _loadingTimer ? null : _showTimerDialog,
                          child: Text(
                            _flashSellTimer == null ? "Set Timer" : "Modify",
                          ),
                        ),
                        SizedBox(height: 8),
                        OutlinedButton(
                          onPressed:
                              _loadingTimer || _flashSellTimer == null
                                  ? null
                                  : _deleteFlashSellTimer,
                          child: Text("Delete"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: products.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < products.length) {
                    final product = products[index];

                    final String countdown =
                        product["flashSell"] == true
                            ? remainingTime
                            : "Not in flash sell";

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
                                    errorBuilder:
                                        (_, __, ___) =>
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
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 5),

                                      Text(
                                        "Price: ${product["price"]}",
                                        style: TextStyle(fontSize: 16),
                                      ),

                                      SizedBox(height: 6),

                                      Text(
                                        "Remaining: $countdown",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              countdown == "Expired"
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
                                  onPressed:
                                      product["flashSell"] == true
                                          ? () => _confirmFlashAction(product)
                                          : _flashSellTimer == null
                                          ? () => _showSnackBar(
                                            "Set the flash sell timer first.",
                                          )
                                          : () => showFlashPriceDialog(product),
                                  child: Text(
                                    product["flashSell"] == true
                                        ? "Remove from Flash Sell"
                                        : "Flash Sell",
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
