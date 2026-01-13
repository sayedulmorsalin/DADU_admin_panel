// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import '../services/image_upload_service.dart';
//
// class AddProductSheet extends StatefulWidget {
//   final List<String> brands;
//   final ImageUploadService imageService;
//   final Function(Map<String, dynamic>) onAdd;
//
//   const AddProductSheet({
//     required this.brands,
//     required this.imageService,
//     required this.onAdd,
//   });
//
//   @override
//   _AddProductSheetState createState() => _AddProductSheetState();
// }
//
// class _AddProductSheetState extends State<AddProductSheet> {
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//   final TextEditingController _detailsController = TextEditingController();
//   final TextEditingController _videoController = TextEditingController();
//   XFile? _pickedImage;
//   String? _errorMessage;
//   String _selectedBrand = 'Adidas';
//   bool _isUploading = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => FocusScope.of(context).unfocus(),
//       child: Padding(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//         ),
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//               if (_errorMessage != null)
//                 Padding(
//                   padding: const EdgeInsets.only(bottom: 16),
//                   child: Text(
//                     _errorMessage!,
//                     style: const TextStyle(color: Colors.red),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               _pickedImage != null
//                   ? Image.file(File(_pickedImage!.path), height: 200, fit: BoxFit.cover)
//                   : const Icon(Icons.image, size: 100, color: Colors.grey),
//               const SizedBox(height: 16),
//               ElevatedButton.icon(
//                 onPressed: () async {
//                   final image = await ImagePicker().pickImage(source: ImageSource.gallery);
//                   if (image != null) {
//                     setState(() {
//                       _pickedImage = image;
//                     });
//                   }
//                 },
//                 icon: const Icon(Icons.folder_open),
//                 label: const Text("Pick Image from Gallery"),
//               ),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: _nameController,
//                 decoration: const InputDecoration(
//                   labelText: "Name",
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: _priceController,
//                 decoration: const InputDecoration(
//                   labelText: "Price",
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: _detailsController,
//                 maxLines: 4,
//                 decoration: const InputDecoration(
//                   labelText: "Details",
//                   border: OutlineInputBorder(),
//                   alignLabelWithHint: true,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: _videoController,
//                 maxLines: 2,
//                 decoration: const InputDecoration(
//                   labelText: "Video link",
//                   border: OutlineInputBorder(),
//                   alignLabelWithHint: true,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: _selectedBrand,
//                 items: widget.brands.map((brand) {
//                   return DropdownMenuItem(
//                     value: brand,
//                     child: Text(brand),
//                   );
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _selectedBrand = value!;
//                   });
//                 },
//                 decoration: const InputDecoration(
//                   labelText: "Brand",
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton.icon(
//                 onPressed: _isUploading ? null : _addProduct,
//                 icon: _isUploading
//                     ? const SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(
//                     color: Colors.white,
//                     strokeWidth: 2,
//                   ),
//                 )
//                     : const Icon(Icons.add),
//                 label: Text(_isUploading ? "Uploading..." : "Add Product"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _addProduct() async {
//     if (_pickedImage == null) {
//       setState(() {
//         _errorMessage = "Please select an image";
//       });
//       return;
//     }
//     if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
//       setState(() {
//         _errorMessage = "Name and price are required";
//       });
//       return;
//     }
//
//     setState(() {
//       _isUploading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final imageFile = File(_pickedImage!.path);
//       final urls = await widget.imageService.uploadCompressedImages(imageFile);
//
//       widget.onAdd({
//         "name": _nameController.text,
//         "price": _priceController.text,
//         "details": _detailsController.text,
//         "brand": _selectedBrand,
//         "videoLink": _videoController.text,
//         "image5": urls['url5'],
//         "image20": urls['url20'],
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = "Error: ${e.toString()}";
//       });
//     } finally {
//       setState(() {
//         _isUploading = false;
//       });
//     }
//   }
// }