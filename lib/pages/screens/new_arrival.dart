import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class NewArrival extends StatefulWidget {
  const NewArrival({super.key});

  @override
  State<NewArrival> createState() => _NewArrivalState();
}

class _NewArrivalState extends State<NewArrival> {

  DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> products = [];




  @override
  void initState() {
    super.initState();
    _loadProducts();

  }



  Future<void> _loadProducts() async {
    try {
      final loadedProducts = await _dbService.getProducts();
      setState(() => products = loadedProducts);
    } catch (e) {
      _showSnackBar("Failed to load products: ${e.toString()}");
    }
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  void showTextDateTimeDialog(Map<String, dynamic> product) {
    final bool isNewArrival =
    product["newArrival"] is bool ? product["newArrival"] : false;

    final String productId = product["id"];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            isNewArrival ? "Remove from New Arrival?" : "Add to New Arrival?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final newValue = !isNewArrival;

                await _dbService.updateProduct(productId, {
                  "newArrival": newValue,
                });

                setState(() {
                  product["newArrival"] = newValue;
                });

                _showSnackBar(
                    newValue ? "Added" : "Removed");
              } catch (e) {
                _showSnackBar("Update failed: $e");
              }
            },
            child: Text(isNewArrival ? "Remove" : "Add"),
          ),
        ],
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "New Arrival",
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
                          child: Text(
                            product["newArrival"] == true
                                ? "Remove from new arrival"
                                : "Add to new arrival",
                          ),
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
