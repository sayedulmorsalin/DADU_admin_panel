import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';
import '../services/image_upload_service.dart';
import '../widgets/product_card.dart';
import 'package:fuzzy/fuzzy.dart';


class ManageProductPage extends StatefulWidget {
  @override
  _ManageProductPageState createState() => _ManageProductPageState();
}

class _ManageProductPageState extends State<ManageProductPage> {
  final DatabaseService _dbService = DatabaseService();
  final ImageUploadService _imageService = ImageUploadService();
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  final List<String> brands = [
    'Adidas',
    'Nike',
    'Puma',
    'Dadu',
    'Mizuno',
    'Others',
  ];

  final List<String> categories = [
    'Boots Master Grade',
    'Boots Master Grade Copy',
    'Boots Copy 4 Grade',
    'Boots China Copy',
    'Boots Turf',
    'Gloves',
    'Jersey',
    'Pant',
    'Bag',
    'Safe Guard',
    'Socks',
    'Combo Pack',
    'Others',
  ];

  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addPriceController = TextEditingController();
  final TextEditingController _addDeliveryFeeController = TextEditingController();
  final TextEditingController _addFreeCoinController = TextEditingController();
  final TextEditingController _addSizeController = TextEditingController();
  final TextEditingController _addDetailsController = TextEditingController();
  final TextEditingController _addVideoController = TextEditingController();
  XFile? _pickedImage;
  XFile? _pickedImage2;
  XFile? _pickedImage3;
  String? _addErrorMessage;
  String _selectedBrand = 'Adidas';
  String _selectedCategory = 'Others';
  String _selectedStock = 'Available';
  bool _isUploading = false;

  late TextEditingController _editNameController;
  late TextEditingController _editPriceController;
  late TextEditingController _editDeliveryFeeController;
  late TextEditingController _editFreeCoinController;
  late TextEditingController _editSizeController;
  late TextEditingController _editDetailsController;
  late TextEditingController _editVideoController;
  late String _editSelectedBrand;
  late String _editSelectedCategory;
  late String _editSelectedStock;
  String? _editErrorMessage;
  Map<String, dynamic>? _editingProduct;
  XFile? _editPickedImage;
  XFile? _editPickedImage2;
  XFile? _editPickedImage3;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _initializeEditControllers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500 &&
        !_isLoadingMore &&
        _hasMore &&
        _searchController.text.isEmpty) {
      _loadMoreProducts();
    }
  }

  void _initializeEditControllers() {
    _editNameController = TextEditingController();
    _editPriceController = TextEditingController();
    _editDeliveryFeeController = TextEditingController();
    _editFreeCoinController = TextEditingController();
    _editSizeController = TextEditingController();
    _editDetailsController = TextEditingController();
    _editVideoController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _editSelectedBrand = 'Adidas';
    _editSelectedCategory = 'Others';
    _editSelectedStock = 'Available';
  }

  void _onSearchChanged() {
    _searchProducts(_searchController.text);
  }

  void _searchProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredProducts = products;
      });
      return;
    }

    final fuzzy = Fuzzy<Map<String, dynamic>>(
      products,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'name',
            getter: (p) => p['name'] ?? '',
            weight: 1.0,
          ),
          WeightedKey(
            name: 'brand',
            getter: (p) => p['brand'] ?? '',
            weight: 0.7,
          ),
          WeightedKey(
            name: 'details',
            getter: (p) => p['details'] ?? '',
            weight: 0.5,
          ),
        ],
        threshold: 0.3,
      ),
    );

    final result = fuzzy.search(query);
    setState(() {
      filteredProducts = result.map((r) => r.item).toList();
    });
  }


  Future<void> _loadProducts() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final loadedProducts = await _dbService.getProducts(page: _currentPage);
      setState(() {
        products = loadedProducts;
        filteredProducts = loadedProducts;
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
          _currentPage = nextPage;
          if (loadedProducts.length < 20) {
            _hasMore = false;
          }
          if (_searchController.text.isEmpty) {
            filteredProducts = List.from(products);
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


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showEditDialog(Map<String, dynamic> product) {
    _editingProduct = product;
    _editNameController.text = _editingProduct!['name'];
    _editPriceController.text = _editingProduct!['price'];
    _editDeliveryFeeController.text = _editingProduct!['deliveryFee'] ?? '0';
    _editFreeCoinController.text = _editingProduct!['freeCoin']?.toString() ?? '0';
    _editSizeController.text = _editingProduct!['size'] ?? '';
    _editDetailsController.text = _editingProduct!['details'];
    _editVideoController.text = _editingProduct!['videoLink'] ?? '';
    _editSelectedBrand = brands.contains(_editingProduct!['brand']) ? _editingProduct!['brand'] : 'Others';
    _editSelectedCategory = categories.contains(_editingProduct!['category']) ? _editingProduct!['category'] : 'Others';
    _editSelectedStock = ['Available', 'Not Available'].contains(_editingProduct!['stock']) ? _editingProduct!['stock'] : 'Available';
    _editErrorMessage = null;
    _editPickedImage = null;
    _editPickedImage2 = null;
    _editPickedImage3 = null;

    showDialog(context: context, builder: (context) => _buildEditDialog());
  }

  Widget _buildEditDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildEditImagePickerSlot(
                        currentImageUrl: _editingProduct!['image20'] ?? _editingProduct!['image5'],
                        newImage: _editPickedImage,
                        label: "Primary",
                        onTap: () async {
                          final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() => _editPickedImage = image);
                            setState(() {}); // Still update parent state for the save logic
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildEditImagePickerSlot(
                        currentImageUrl: _editingProduct!['image2'],
                        newImage: _editPickedImage2,
                        label: "Image 2",
                        onTap: () async {
                          final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() => _editPickedImage2 = image);
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildEditImagePickerSlot(
                        currentImageUrl: _editingProduct!['image3'],
                        newImage: _editPickedImage3,
                        label: "Image 3",
                        onTap: () async {
                          final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() => _editPickedImage3 = image);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                  controller: _editDeliveryFeeController,
                  decoration: const InputDecoration(
                    labelText: "Delivery Fee",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _editFreeCoinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Free Coin",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _editSizeController,
                  decoration: const InputDecoration(
                    labelText: "Size",
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
                    return DropdownMenuItem(value: brand, child: Text(brand));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => _editSelectedBrand = value!);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: "Brand",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _editSelectedCategory,
                  items: categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => _editSelectedCategory = value!);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _editSelectedStock,
                  items: ['Available', 'Not Available'].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => _editSelectedStock = value!);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: "Stock",
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
              onPressed: _isEditing ? null : () => _saveEditedProduct(setDialogState),
              child: _isEditing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Save"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _saveEditedProduct(Function(void Function()) setDialogState) async {
    if (_editNameController.text.isEmpty || _editPriceController.text.isEmpty) {
      setDialogState(() {
        _editErrorMessage = "Name and price are required";
      });
      return;
    }

    setDialogState(() {
      _isEditing = true;
      _editErrorMessage = null;
    });
    setState(() => _isEditing = true);

    try {
      final oldName = _editingProduct!['name'];
      final productId = _editingProduct!['id'];
      
      debugPrint("Saving product with ID: $productId");
      if (productId == null || productId.toString().isEmpty) {
        throw Exception("Product ID is missing");
      }

      String img5 = _editingProduct!['image5'] ?? '';
      String img20 = _editingProduct!['image20'] ?? '';
      String img2 = _editingProduct!['image2'] ?? '';
      String img3 = _editingProduct!['image3'] ?? '';

      if (_editPickedImage != null) {
        debugPrint("Uploading new primary image...");
        try {
          if (img5.isNotEmpty) await _imageService.deleteImage(img5);
          if (img20.isNotEmpty) await _imageService.deleteImage(img20);
        } catch (e) {
          debugPrint("Failed to delete old primary images: $e");
        }
        final urls = await _imageService.uploadCompressedImages(File(_editPickedImage!.path));
        img5 = urls['url5']!;
        img20 = urls['url20']!;
      }

      if (_editPickedImage2 != null) {
        debugPrint("Uploading new image 2...");
        try {
          if (img2.isNotEmpty) await _imageService.deleteImage(img2);
        } catch (e) {
          debugPrint("Failed to delete old image2: $e");
        }
        img2 = await _imageService.uploadAdditionalImage(File(_editPickedImage2!.path));
      }

      if (_editPickedImage3 != null) {
        debugPrint("Uploading new image 3...");
        try {
          if (img3.isNotEmpty) await _imageService.deleteImage(img3);
        } catch (e) {
          debugPrint("Failed to delete old image3: $e");
        }
        img3 = await _imageService.uploadAdditionalImage(File(_editPickedImage3!.path));
      }

      final updatePayload = {
        'name': _editNameController.text,
        'price': _editPriceController.text,
        'deliveryFee': _editDeliveryFeeController.text,
        'freeCoin': int.tryParse(_editFreeCoinController.text) ?? 0,
        'size': _editSizeController.text,
        'stock': _editSelectedStock,
        'details': _editDetailsController.text,
        'brand': _editSelectedBrand,
        'category': _editSelectedCategory,
        'videoLink': _editVideoController.text,
        'image5': img5,
        'image20': img20,
        'image2': img2,
        'image3': img3,
      };
      
      debugPrint("Calling DatabaseService.updateProduct...");
      await _dbService.updateProduct(productId, updatePayload);
      debugPrint("DatabaseService.updateProduct successful.");

      if (oldName != updatePayload['name']) {
        await _dbService.updateProductName(oldName?.toString() ?? '', updatePayload['name']?.toString() ?? '');
      }

      final updatedProduct = {
        ..._editingProduct!,
        ...updatePayload,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (mounted) {
        setState(() {
          final index = products.indexWhere((p) => p['id'] == productId);
          if (index != -1) {
            products[index] = updatedProduct;
          }
          _searchProducts(_searchController.text);
        });
        Navigator.pop(context);
        _showSnackBar("Product updated successfully!");
      }
    } catch (e) {
      debugPrint("Error in _saveEditedProduct: $e");
      setDialogState(() {
        _isEditing = false;
        _editErrorMessage = "Update failed: ${e.toString()}";
      });
      setState(() => _isEditing = false);
    } finally {
      if (mounted) {
        setDialogState(() => _isEditing = false);
        setState(() => _isEditing = false);
      }
    }
  }


  void _shareProductLink(Map<String, dynamic> product) {
    final productId = product['id'];
    if (productId == null) return;
    final String deepLink = 'https://dadubd.com/product?id=$productId';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share Product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.share, color: Colors.white),
                ),
                title: const Text('Share Link'),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(
                    'Check out this product: ${product['name']}\n$deepLink',
                    subject: 'Product: ${product['name']}',
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.copy, color: Colors.white),
                ),
                title: const Text('Copy Link'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: deepLink));
                  Navigator.pop(context);
                  _showSnackBar("Link copied to clipboard!");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteProduct(Map<String, dynamic> product) {
    final productName = product['name'];
    final productId = product['id'];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Confirm Deletion"),
            content: const Text(
              "Are you sure you want to delete this product?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final imageService = ImageUploadService();
                    String img5 = product['image5'] ?? '';
                    String img20 = product['image20'] ?? '';
                    String img2 = product['image2'] ?? '';
                    String img3 = product['image3'] ?? '';

                    if (img5.isNotEmpty) await imageService.deleteImage(img5);
                    if (img20.isNotEmpty) await imageService.deleteImage(img20);
                    if (img2.isNotEmpty) await imageService.deleteImage(img2);
                    if (img3.isNotEmpty) await imageService.deleteImage(img3);

                    await _dbService.deleteProduct(productId);

                    await _dbService.removeProductName(productName);

                    setState(() {
                      products.removeWhere((p) => p['id'] == productId);
                      _searchProducts(_searchController.text);
                    });

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
    _addDeliveryFeeController.clear();
    _addFreeCoinController.clear();
    _addSizeController.clear();
    _addDetailsController.clear();
    _addVideoController.clear();
    _pickedImage = null;
    _pickedImage2 = null;
    _pickedImage3 = null;
    _addErrorMessage = null;
    _selectedBrand = 'Adidas';
    _selectedCategory = 'Others';
    _selectedStock = 'Available';
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildImagePickerSlot(
                      image: _pickedImage,
                      label: "Primary *",
                      onTap: () async {
                        final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (image != null) setState(() => _pickedImage = image);
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildImagePickerSlot(
                      image: _pickedImage2,
                      label: "Image 2",
                      onTap: () async {
                        final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (image != null) setState(() => _pickedImage2 = image);
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildImagePickerSlot(
                      image: _pickedImage3,
                      label: "Image 3",
                      onTap: () async {
                        final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (image != null) setState(() => _pickedImage3 = image);
                      },
                    ),
                  ],
                ),
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
                controller: _addDeliveryFeeController,
                decoration: const InputDecoration(
                  labelText: "Delivery Fee",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addFreeCoinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Free Coin",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addSizeController,
                decoration: const InputDecoration(
                  labelText: "Size",
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
                items:
                    brands.map((brand) {
                      return DropdownMenuItem(value: brand, child: Text(brand));
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBrand = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Brand",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items:
                    categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStock,
                items: ['Available', 'Not Available'].map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStock = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Stock",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _addProduct,
                icon:
                    _isUploading
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

      String? url2;
      if (_pickedImage2 != null) {
        url2 = await _imageService.uploadAdditionalImage(File(_pickedImage2!.path));
      }

      String? url3;
      if (_pickedImage3 != null) {
        url3 = await _imageService.uploadAdditionalImage(File(_pickedImage3!.path));
      }

      final newProduct = {
        "name": _addNameController.text,
        "price": _addPriceController.text,
        "deliveryFee": _addDeliveryFeeController.text,
        "freeCoin": int.tryParse(_addFreeCoinController.text) ?? 0,
        "size": _addSizeController.text,
        "stock": _selectedStock,
        "details": _addDetailsController.text,
        "brand": _selectedBrand,
        "category": _selectedCategory,
        "videoLink": _addVideoController.text,
        "image5": urls['url5'],
        "image20": urls['url20'],
        "image2": url2 ?? '',
        "image3": url3 ?? '',
      };

      final docRef = await _dbService.addProduct(newProduct);

      await _dbService.addProductName(newProduct['name'] as String? ?? "no name");

      setState(() {
        final product = {...newProduct, 'id': docRef.id};
        products.insert(0, product);
        _searchProducts(_searchController.text);
      });

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

  Widget _buildImagePickerSlot({
    XFile? image,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                image != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(image.path), fit: BoxFit.cover),
                    )
                    : const Icon(Icons.add_a_photo, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEditImagePickerSlot({
    String? currentImageUrl,
    XFile? newImage,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                newImage != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(newImage.path), fit: BoxFit.cover),
                    )
                    : (currentImageUrl != null && currentImageUrl.isNotEmpty)
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(currentImageUrl, fit: BoxFit.cover),
                    )
                    : const Icon(Icons.add_a_photo, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Product"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductSheet,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search products...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child:
                filteredProducts.isEmpty
                    ? const Center(child: Text("No products found"))
                    : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        cacheExtent: 500,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filteredProducts.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < filteredProducts.length) {
                            return ProductCard(
                              product: filteredProducts[index],
                              onEdit: () => _showEditDialog(filteredProducts[index]),
                              onDelete: () => _deleteProduct(filteredProducts[index]),
                              onShare: () => _shareProductLink(filteredProducts[index]),
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
          ),
        ],
      ),
    ),
  );
}

  @override
  void dispose() {
    _addNameController.dispose();
    _addPriceController.dispose();
    _addDeliveryFeeController.dispose();
    _addFreeCoinController.dispose();
    _addSizeController.dispose();
    _addDetailsController.dispose();
    _addVideoController.dispose();
    _editNameController.dispose();
    _editPriceController.dispose();
    _editDeliveryFeeController.dispose();
    _editFreeCoinController.dispose();
    _editSizeController.dispose();
    _editDetailsController.dispose();
    _editVideoController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

}
