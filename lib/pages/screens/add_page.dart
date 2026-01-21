import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../services/image_upload_service.dart';
import '../widgets/product_card.dart';

class AddPage extends StatefulWidget {
  @override
  _AddPageState createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final DatabaseService _dbService = DatabaseService();
  final ImageUploadService _imageService = ImageUploadService();
  List<Map<String, dynamic>> products = [];
  final List<String> brands = ['Adidas', 'Nike', 'Puma', 'Gloves', 'Other_boots', 'Jersey', 'Pant', 'Others'];


  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addPriceController = TextEditingController();
  final TextEditingController _addDetailsController = TextEditingController();
  final TextEditingController _addVideoController = TextEditingController();
  XFile? _pickedImage;
  String? _addErrorMessage;
  String _selectedBrand = 'Adidas';
  bool _isUploading = false;


  late TextEditingController _editNameController;
  late TextEditingController _editPriceController;
  late TextEditingController _editDetailsController;
  late TextEditingController _editVideoController;
  late String _editSelectedBrand;
  String? _editErrorMessage;
  Map<String, dynamic>? _editingProduct;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _initializeEditControllers();
  }

  void _initializeEditControllers() {
    _editNameController = TextEditingController();
    _editPriceController = TextEditingController();
    _editDetailsController = TextEditingController();
    _editVideoController = TextEditingController();
    _editSelectedBrand = 'Adidas';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showEditDialog(int index) {
    _editingProduct = products[index];
    _editNameController.text = _editingProduct!['name'];
    _editPriceController.text = _editingProduct!['price'];
    _editDetailsController.text = _editingProduct!['details'];
    _editVideoController.text = _editingProduct!['videoLink'] ?? '';
    _editSelectedBrand = _editingProduct!['brand'] ?? 'Others';
    _editErrorMessage = null;

    showDialog(
      context: context,
      builder: (context) => _buildEditDialog(index),
    );
  }

  Widget _buildEditDialog(int index) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Edit Product"),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _editErrorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            TextField(
              controller: _editNameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editPriceController,
              decoration: const InputDecoration(
                labelText: "Price",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editDetailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Details",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editVideoController,
              decoration: const InputDecoration(
                labelText: "Video link",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _editSelectedBrand,
              items: brands.map((brand) {
                return DropdownMenuItem(
                  value: brand,
                  child: Text(brand),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _editSelectedBrand = value!;
                });
              },
              decoration: const InputDecoration(
                labelText: "Brand/Category",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => _saveEditedProduct(index),
          child: const Text("Save"),
        ),
      ],
    );
  }

  void _saveEditedProduct(int index) async {
    if (_editNameController.text.isEmpty || _editPriceController.text.isEmpty) {
      setState(() {
        _editErrorMessage = "Name and price are required";
      });
      return;
    }

    try {
      final oldName = products[index]['name'];
      final updatedProduct = {
        ...products[index],
        "name": _editNameController.text,
        "price": _editPriceController.text,
        "details": _editDetailsController.text,
        "brand": _editSelectedBrand,
        "videoLink": _editVideoController.text,
      };


      await _dbService.updateProduct(
        updatedProduct['id'],
        {
          'name': updatedProduct['name'],
          'price': updatedProduct['price'],
          'details': updatedProduct['details'],
          'brand': updatedProduct['brand'],
          'videoLink': updatedProduct['videoLink'],
        },
      );


      if (oldName != updatedProduct['name']) {
        await _dbService.updateProductName(oldName, updatedProduct['name']);
      }


      setState(() => products[index] = updatedProduct);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _editErrorMessage = "Update failed: ${e.toString()}";
      });
    }
  }

  void _deleteProduct(int index) {
    final productName = products[index]['name'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final imageService = ImageUploadService();
                String img5 = products[index]['image5'];
                String img20 = products[index]['image20'];

                await imageService.deleteImage(img5);
                await imageService.deleteImage(img20);


                await _dbService.deleteProduct(products[index]['id']);


                await _dbService.removeProductName(productName);


                setState(() => products.removeAt(index));

                Navigator.pop(context);
              } catch (e) {
                _showSnackBar("Deletion failed: ${e.toString()}");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showAddProductSheet() {

    _addNameController.clear();
    _addPriceController.clear();
    _addDetailsController.clear();
    _addVideoController.clear();
    _pickedImage = null;
    _addErrorMessage = null;
    _selectedBrand = 'Adidas';
    _isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildAddProductSheet(),
    );
  }

  Widget _buildAddProductSheet() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (_addErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _addErrorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              _pickedImage != null
                  ? Image.file(File(_pickedImage!.path), height: 200, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 100, color: Colors.grey),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _pickedImage = image;
                    });
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text("Pick Image from Gallery"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addNameController,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addPriceController,
                decoration: const InputDecoration(
                  labelText: "Price",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addDetailsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Details",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addVideoController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Video link",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBrand,
                items: brands.map((brand) {
                  return DropdownMenuItem(
                    value: brand,
                    child: Text(brand),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBrand = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Brand/Category",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _addProduct,
                icon: _isUploading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.add),
                label: Text(_isUploading ? "Uploading..." : "Add Product"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addProduct() async {
    if (_pickedImage == null) {
      setState(() {
        _addErrorMessage = "Please select an image";
      });
      return;
    }
    if (_addNameController.text.isEmpty || _addPriceController.text.isEmpty) {
      setState(() {
        _addErrorMessage = "Name and price are required";
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _addErrorMessage = null;
    });

    try {
      final imageFile = File(_pickedImage!.path);
      final urls = await _imageService.uploadCompressedImages(imageFile);

      final newProduct = {
        "name": _addNameController.text,
        "price": _addPriceController.text,
        "details": _addDetailsController.text,
        "brand": _selectedBrand,
        "videoLink": _addVideoController.text,
        "image5": urls['url5'],
        "image20": urls['url20'],
      };


      final docRef = await _dbService.addProduct(newProduct);


      await _dbService.addProductName(newProduct['name']??"no name");


      setState(() => products.insert(0, {
        ...newProduct,
        'id': docRef.id,
        'clicked': 0,
      }));
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _addErrorMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductSheet,
        child: const Icon(Icons.add),
      ),
      body: products.isEmpty
          ? const Center(child: Text("No products found"))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) => ProductCard(
            product: products[index],
            onEdit: () => _showEditDialog(index),
            onDelete: () => _deleteProduct(index),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addNameController.dispose();
    _addPriceController.dispose();
    _addDetailsController.dispose();
    _addVideoController.dispose();
    _editNameController.dispose();
    _editPriceController.dispose();
    _editDetailsController.dispose();
    _editVideoController.dispose();
    super.dispose();
  }
}