import 'dart:io';
import 'package:dadu_admin_panel/pages/widgets/banner_card.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../services/image_upload_service.dart';
import '../widgets/product_card.dart';

class BannerPage extends StatefulWidget {
  const BannerPage({super.key});

  @override
  State<BannerPage> createState() => _BannerPageState();
}

class _BannerPageState extends State<BannerPage> {
  final DatabaseService _dbService = DatabaseService();
  final ImageUploadService _imageService = ImageUploadService();
  List<Map<String, dynamic>> products = [];
  final List<String> brands = ['Adidas', 'Nike', 'Puma', 'Gloves', 'Other_boots', 'Others'];

  // Add Product Controllers
  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addPriceController = TextEditingController();
  final TextEditingController _addDetailsController = TextEditingController();
  final TextEditingController _addVideoController = TextEditingController();
  XFile? _pickedImage;
  String? _addErrorMessage;
  bool _isUploading = false;

  // Edit Product Controllers
  late TextEditingController _editNameController;
  late TextEditingController _editPriceController;
  late TextEditingController _editDetailsController;
  late TextEditingController _editVideoController;

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
  }

  Future<void> _loadProducts() async {
    try {
      final loadedProducts = await _dbService.getBanners();
      setState(() => products = loadedProducts);
    } catch (e) {
      _showSnackBar("Failed to load products: ${e.toString()}");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }


  void _deleteProduct(int index) {

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
                String img20 = products[index]['imageUrl'];

                await imageService.deleteImage(img20);

                // Delete from products collection
                await _dbService.deleteBanner(products[index]['id']);

                // Update local state
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
    // Reset form
    _pickedImage = null;
    _addErrorMessage = null;
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
                label: Text(_isUploading ? "Uploading..." : "Upload Banner"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addProduct() async {
    print("add product clicked");
    if (_pickedImage == null) {
      setState(() {
        _addErrorMessage = "Please select an image";
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _addErrorMessage = null;
    });

    try {
      final imageFile = File(_pickedImage!.path);
      final urls = await _imageService.uploadCompressedBannerImages(imageFile);
      print(urls);

      // Add to products collection
      await _dbService.addBanner(urls);
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
          itemBuilder: (context, index) => BannerCard(
            product: products[index],
            onDelete: () => _deleteProduct(index),
          ),
        ),
      ),
    );
  }
}