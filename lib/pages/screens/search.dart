import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final TextEditingController _emailController = TextEditingController();
  DocumentSnapshot? _userDoc;
  bool _isLoading = false;
  bool _isEditing = false;

  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _emailFieldController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _districtController;
  late TextEditingController _thanaController;
  late TextEditingController _profilePicController;
  late TextEditingController _uidController;

  late TextEditingController _completedCountController;
  late TextEditingController _toReceiveCountController;
  late TextEditingController _toShipCountController;
  late TextEditingController _toVerifyCountController;
  late TextEditingController _freeDeliveryInfoController;

  bool _freeDeliveryUsed = false;
  bool _freeDeliveryStatus = false;

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailFieldController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _districtController = TextEditingController();
    _thanaController = TextEditingController();
    _profilePicController = TextEditingController();
    _uidController = TextEditingController();

    _completedCountController = TextEditingController();
    _toReceiveCountController = TextEditingController();
    _toShipCountController = TextEditingController();
    _toVerifyCountController = TextEditingController();
    _freeDeliveryInfoController = TextEditingController();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _emailController.dispose();
    _nameController.dispose();
    _emailFieldController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _thanaController.dispose();
    _profilePicController.dispose();
    _uidController.dispose();
    _completedCountController.dispose();
    _toReceiveCountController.dispose();
    _toShipCountController.dispose();
    _toVerifyCountController.dispose();
    _freeDeliveryInfoController.dispose();
    super.dispose();
  }

  Future<void> _searchUserByEmail(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      _showSnackBar('Please enter an email');
      return;
    }

    if (!_isValidEmail(trimmedEmail)) {
      _showSnackBar('Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _userDoc = null;
      _isEditing = false;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: trimmedEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _userDoc = doc;
          _populateFormFields(doc);
          print(_userDoc!.data());

        });
      } else {
        _showSnackBar('No user found with this email');
      }
    } catch (e) {
      _showSnackBar('Error searching user: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _populateFormFields(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;

    _nameController.text = data['name']?.toString() ?? '';
    _emailFieldController.text = data['email']?.toString() ?? '';
    _phoneController.text = data['phone']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';
    _districtController.text = data['district']?.toString() ?? '';
    _thanaController.text = data['thana']?.toString() ?? '';
    _profilePicController.text = data['profile_pic']?.toString() ?? '';
    _uidController.text = data['uid']?.toString() ?? '';

    _completedCountController.text = (data['completed_count'] ?? 0).toString();
    _toReceiveCountController.text = (data['to_receive_count'] ?? 0).toString();
    _toShipCountController.text = (data['to_ship_count'] ?? 0).toString();
    _toVerifyCountController.text = (data['to_verify_count'] ?? 0).toString();
    _freeDeliveryInfoController.text = (data['free_delivery_info'] ?? 0).toString();

    _freeDeliveryUsed = data['freeDeliveryUsed'] == true;
    _freeDeliveryStatus = data['free_delivery_status'] == true;
  }

  Future<void> _updateUserProfile() async {
    if (_userDoc == null) return;

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the validation errors');
      return;
    }

    int? parseInt(String? s) {
      if (s == null || s.isEmpty) return 0;
      try {
        return int.parse(s);
      } catch (e) {
        return 0;
      }
    }

    final updatedData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailFieldController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'district': _districtController.text.trim(),
      'thana': _thanaController.text.trim(),
      'profile_pic': _profilePicController.text.trim(),
      'uid': _uidController.text.trim(),
      'completed_count': parseInt(_completedCountController.text),
      'to_receive_count': parseInt(_toReceiveCountController.text),
      'to_ship_count': parseInt(_toShipCountController.text),
      'to_verify_count': parseInt(_toVerifyCountController.text),
      'free_delivery_info': parseInt(_freeDeliveryInfoController.text),
      'freeDeliveryUsed': _freeDeliveryUsed,
      'free_delivery_status': _freeDeliveryStatus,
      'last_updated': FieldValue.serverTimestamp(),
    };

    try {
      await _userDoc!.reference.update(updatedData);
      // Refresh the document
      final updatedDoc = await _userDoc!.reference.get();
      setState(() {
        _userDoc = updatedDoc;
        _isEditing = false;
      });
      _showSnackBar('Profile updated successfully!', isError: false);
    } catch (e) {
      _showSnackBar('Update failed: ${e.toString()}');
    }
  }

  // New method to delete complex data fields
  Future<void> _deleteComplexData(List<String> fieldsToDelete) async {
    if (_userDoc == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete the following fields?\n\n${fieldsToDelete.join(', ')}\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updates = <String, dynamic>{};
      for (final field in fieldsToDelete) {
        updates[field] = FieldValue.delete();
      }
      updates['last_updated'] = FieldValue.serverTimestamp();

      await _userDoc!.reference.update(updates);

      // Refresh the document
      final updatedDoc = await _userDoc!.reference.get();
      setState(() {
        _userDoc = updatedDoc;
      });
      _showSnackBar('Complex data deleted successfully!', isError: false);
    } catch (e) {
      _showSnackBar('Deletion failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cancelEditing() {
    if (_userDoc != null) {
      _populateFormFields(_userDoc!);
    }
    setState(() {
      _isEditing = false;
    });
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final dt = ts.toDate();
    return '${dt.day} ${_monthName(dt.month)} ${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Edit User'),
        backgroundColor: Colors.blue,
        actions: [
          if (_userDoc != null && _isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _cancelEditing,
              tooltip: 'Cancel Editing',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            _buildSearchSection(),
            const SizedBox(height: 20),

            // Content Section
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Searching for user...'),
                    ],
                  ),
                ),
              )
            else if (_userDoc != null)
              Expanded(
                child: _buildUserProfile(),
              )
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search User by Email',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Enter User Email',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: _searchUserByEmail,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _searchUserByEmail(_emailController.text),
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _isEditing ? _buildEditSection() : _buildDisplaySection(),

          // Add Delete Complex Data Section
          if (_userDoc != null && !_isEditing) _buildDeleteComplexDataSection(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Enter an email to search for users',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'All user profile data will be displayed here for editing',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _buildInfoItem('User ID', _userDoc!.id),
                _buildInfoItem('Email', _userDoc!.get('email') ?? 'N/A'),
                _buildInfoItem('UID', _userDoc!.get('uid') ?? 'N/A'),
                _buildInfoItem('Created At', _formatTimestamp(_userDoc!.get('createdAt') as Timestamp?)),
                _buildInfoItem('Last Login', _formatTimestamp(_userDoc!.get('lastLogin') as Timestamp?)),
                _buildInfoItem('Last Updated', _formatTimestamp(_userDoc!.get('last_updated') as Timestamp?)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildEditSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _updateUserProfile,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _cancelEditing,
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Editable Fields
          _buildSectionHeader('Basic Information'),
          _buildEditableField('Name', _nameController, isRequired: true),
          _buildEditableField('Email', _emailFieldController, isRequired: true, isEmail: true),
          _buildEditableField('Phone', _phoneController),
          _buildEditableField('Address', _addressController, maxLines: 3),
          _buildEditableField('District', _districtController),
          _buildEditableField('Thana', _thanaController),
          _buildEditableField('Profile Pic URL', _profilePicController),
          _buildEditableField('UID', _uidController, isRequired: true),

          const SizedBox(height: 20),
          _buildSectionHeader('Counters'),
          _buildEditableField('Completed Count', _completedCountController, keyboardType: TextInputType.number),
          _buildEditableField('To Receive Count', _toReceiveCountController, keyboardType: TextInputType.number),
          _buildEditableField('To Ship Count', _toShipCountController, keyboardType: TextInputType.number),
          _buildEditableField('To Verify Count', _toVerifyCountController, keyboardType: TextInputType.number),
          _buildEditableField('Free Delivery Info', _freeDeliveryInfoController, keyboardType: TextInputType.number),

          const SizedBox(height: 20),
          _buildSectionHeader('Flags'),
          _buildSwitchField('Free Delivery Used', _freeDeliveryUsed, (v) => setState(() => _freeDeliveryUsed = v)),
          _buildSwitchField('Free Delivery Status', _freeDeliveryStatus, (v) => setState(() => _freeDeliveryStatus = v)),
        ],
      ),
    );
  }

  dynamic _safeGet(DocumentSnapshot doc, String field, {dynamic defaultValue = 'N/A'}) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) return defaultValue;
    if (!data.containsKey(field)) return defaultValue;

    return data[field];
  }


  Widget _buildDisplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit Profile'),
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('Basic Information'),
        _buildDisplayField('Name', _safeGet(_userDoc!, 'name')),
        _buildDisplayField('Email', _safeGet(_userDoc!, 'email')),
        _buildDisplayField('Phone', _safeGet(_userDoc!, 'phone')),
        _buildDisplayField('Address', _safeGet(_userDoc!, 'address')),
        _buildDisplayField('District', _safeGet(_userDoc!, 'district')),
        _buildDisplayField('Thana', _safeGet(_userDoc!, 'thana')),
        _buildDisplayField('Profile Pic', _safeGet(_userDoc!, 'profile_pic')),
        _buildDisplayField('UID', _safeGet(_userDoc!, 'uid')),

        const SizedBox(height: 20),
        _buildSectionHeader('Counters'),
        _buildDisplayField('Completed Count', _safeGet(_userDoc!, 'completed_count', defaultValue: 0)),
        _buildDisplayField('To Receive Count', _safeGet(_userDoc!, 'to_receive_count', defaultValue: 0)),
        _buildDisplayField('To Ship Count', _safeGet(_userDoc!, 'to_ship_count', defaultValue: 0)),
        _buildDisplayField('To Verify Count', _safeGet(_userDoc!, 'to_verify_count', defaultValue: 0)),
        _buildDisplayField('Free Delivery Info', _safeGet(_userDoc!, 'free_delivery_info', defaultValue: 0)),

        const SizedBox(height: 20),
        _buildSectionHeader('Flags'),
        _buildDisplayField('Free Delivery Used', _safeGet(_userDoc!, 'freeDeliveryUsed', defaultValue: false)),
        _buildDisplayField('Free Delivery Status', _safeGet(_userDoc!, 'free_delivery_status', defaultValue: false)),

        const SizedBox(height: 20),
        _buildSectionHeader('Complex Data (Read-Only)'),
        _buildComplexDataDisplaySafe('Cart Items', 'cart_items'),
        _buildComplexDataDisplaySafe('To Ship', 'to_ship'),
        _buildComplexDataDisplaySafe('Completed', 'completed'),
        _buildComplexDataDisplaySafe('To Receive', 'to_receive'),
        _buildComplexDataDisplaySafe('To Verify', 'to_verify'),
        _buildComplexDataDisplaySafe('Cart Item (Map)', 'cart_item'),
      ],
    );
  }


// Add this new safe method to check if field exists before accessing
  Widget _buildComplexDataDisplaySafe(String label, String fieldName) {
    final data = _userDoc!.data() as Map<String, dynamic>;

    if (!data.containsKey(fieldName)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Text(
                'Field does not exist in document',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return _buildComplexDataDisplay(label, data[fieldName]);
  }

  // New method to build the delete complex data section
  Widget _buildDeleteComplexDataSection() {
    final data = _userDoc!.data() as Map<String, dynamic>;
    final complexFields = [
      'cart_items',
      'to_ship',
      'completed',
      'to_receive',
      'to_verify',
      'cart_item',
    ];

    // Filter to only show fields that actually exist in the document
    final existingComplexFields = complexFields.where((field) {
      return data.containsKey(field) && data[field] != null;
    }).toList();

    if (existingComplexFields.isEmpty) {
      return const SizedBox(); // Don't show section if no complex data exists
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 20),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete Complex Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Warning: This will permanently delete complex data fields. This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Individual field deletion
            ...existingComplexFields.map((field) {
              final fieldData = data[field];
              final itemCount = fieldData is List ? fieldData.length : fieldData is Map ? fieldData.length : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Type: ${fieldData.runtimeType} • Items: $itemCount',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _deleteComplexData([field]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Bulk deletion option
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: existingComplexFields.isNotEmpty
                    ? () => _deleteComplexData(existingComplexFields)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_forever, size: 20),
                    const SizedBox(width: 8),
                    Text('Delete All Complex Data (${existingComplexFields.length})'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) { 
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = false,
    bool isEmail = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: maxLines == 1 ? 1 : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          if (isEmail && value != null && value.isNotEmpty && !_isValidEmail(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDisplayField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
          Text(value ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _buildComplexDataDisplay(String label, dynamic data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _buildDataPreview(data),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPreview(dynamic data) {
    if (data == null) {
      return const Text('null', style: TextStyle(fontStyle: FontStyle.italic));
    }

    if (data is List) {
      if (data.isEmpty) return const Text('[]', style: TextStyle(fontFamily: 'monospace'));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('List (${data.length} items)', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '[$index] ${_summarizeItem(item)}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
      );
    }

    if (data is Map) {
      if (data.isEmpty) return const Text('{}', style: TextStyle(fontFamily: 'monospace'));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Map (${data.length} keys)', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...data.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '${entry.key}: ${_summarizeValue(entry.value)}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
      );
    }

    return Text(data.toString(), style: const TextStyle(fontFamily: 'monospace'));
  }

  String _summarizeItem(dynamic item) {
    if (item is Map) {
      final name = item['name'] ?? 'N/A';
      final qty = item['quantity'] ?? '?';
      final price = item['price'] ?? '?';
      return 'Name: "$name", Qty: $qty, Price: $price';
    }
    return item.toString();
  }

  String _summarizeValue(dynamic value) {
    if (value is Timestamp) return _formatTimestamp(value);
    if (value is Map || value is List) return '<complex data>';
    return value.toString();
  }
}