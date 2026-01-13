// import 'package:flutter/material.dart';
//
// class EditDialog extends StatefulWidget {
//   final Map<String, dynamic> product;
//   final List<String> brands;
//   final Function(Map<String, dynamic>) onSave;
//
//   const EditDialog({
//     required this.product,
//     required this.brands,
//     required this.onSave,
//   });
//
//   @override
//   _EditDialogState createState() => _EditDialogState();
// }
//
// class _EditDialogState extends State<EditDialog> {
//   late TextEditingController _nameController;
//   late TextEditingController _priceController;
//   late TextEditingController _detailsController;
//   late TextEditingController _videoController;
//   late String _selectedBrand;
//   String? _errorMessage;
//
//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController(text: widget.product['name']);
//     _priceController = TextEditingController(text: widget.product['price']);
//     _detailsController = TextEditingController(text: widget.product['details']);
//     _selectedBrand = widget.product['brand'] ?? 'Others';
//     _videoController = TextEditingController(text: widget.product['videoLink'] ?? '');
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           const Text("Edit Product"),
//           IconButton(
//             icon: const Icon(Icons.close),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//         ],
//       ),
//       content: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (_errorMessage != null)
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 16),
//                 child: Text(
//                   _errorMessage!,
//                   style: const TextStyle(color: Colors.red),
//                 ),
//               ),
//             TextField(
//               controller: _nameController,
//               decoration: const InputDecoration(
//                 labelText: "Name",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: _priceController,
//               decoration: const InputDecoration(
//                 labelText: "Price",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: _detailsController,
//               maxLines: 3,
//               decoration: const InputDecoration(
//                 labelText: "Details",
//                 border: OutlineInputBorder(),
//                 alignLabelWithHint: true,
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: _videoController,
//               decoration: const InputDecoration(
//                 labelText: "Video link",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedBrand,
//               items: widget.brands.map((brand) {
//                 return DropdownMenuItem(
//                   value: brand,
//                   child: Text(brand),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedBrand = value!;
//                 });
//               },
//               decoration: const InputDecoration(
//                 labelText: "Brand",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text("Cancel"),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
//               setState(() {
//                 _errorMessage = "Name and price are required";
//               });
//               return;
//             }
//
//             widget.onSave({
//               ...widget.product,
//               "name": _nameController.text,
//               "price": _priceController.text,
//               "details": _detailsController.text,
//               "brand": _selectedBrand,
//               "videoLink": _videoController.text,
//             });
//           },
//           child: const Text("Save"),
//         ),
//       ],
//     );
//   }
// }