import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dadu_admin_panel/services/database_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SendNotification extends StatefulWidget {
  const SendNotification({super.key});

  @override
  State<SendNotification> createState() => _SendNotificationState();
}

class _SendNotificationState extends State<SendNotification> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _segmentController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final Set<String> _deletingNotificationIds = <String>{};

  static const List<String> _audiences = <String>[
    'All Users',
    'Specific User',
    'User Segment',
  ];

  String _selectedAudience = _audiences.first;
  bool _highPriority = false;
  bool _withSound = true;
  bool _isSending = false;

  void _clearForm() {
    _titleController.clear();
    _messageController.clear();
    _userIdController.clear();
    _segmentController.clear();
    _linkController.clear();
    _imageController.clear();
    setState(() {
      _selectedAudience = _audiences.first;
      _highPriority = false;
      _withSound = true;
    });
  }

  Future<void> _showProductPickerDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return _ProductPickerDialog(
          dbService: _dbService,
          onSelect: (product) {
            String imageUrl = (product['image20'] != null &&
                    product['image20'].toString().isNotEmpty)
                ? product['image20'].toString()
                : (product['image2'] != null &&
                        product['image2'].toString().isNotEmpty)
                    ? product['image2'].toString()
                    : (product['image3'] != null &&
                            product['image3'].toString().isNotEmpty)
                        ? product['image3'].toString()
                        : (product['image5'] != null &&
                                product['image5'].toString().isNotEmpty)
                            ? product['image5'].toString()
                            : '';
            // Always ensure the highest-resolution version is used (never the low-res 15% quality img5 thumbnail)
            if (imageUrl.contains('img5_')) {
              imageUrl = imageUrl.replaceAll('img5_', 'img20_');
            }
            setState(() {
              _linkController.text =
                  'https://dadubd.com/product?id=${product['id']}';
              _imageController.text = imageUrl;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Linked: ${product['name'] ?? 'Product'}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  String? _validateForm() {
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      return 'Title and message are required.';
    }
    if (_selectedAudience == 'Specific User' &&
        _userIdController.text.trim().isEmpty) {
      return 'Please enter a user ID.';
    }
    if (_selectedAudience == 'User Segment' &&
        _segmentController.text.trim().isEmpty) {
      return 'Please enter a segment name.';
    }
    return null;
  }

  Future<void> _sendNotification() async {
    final String? error = _validateForm();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _isSending = true;
    });

    final Map<String, dynamic> payload = {
      'title': _titleController.text.trim(),
      'body': _messageController.text.trim(),
      'link': _linkController.text.trim(),
      'image': _imageController.text.trim(),
      'audience': _selectedAudience,
      'sentBy': 'admin',
      'status': 'queued',
      'highPriority': _highPriority,
      'withSound': _withSound,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (_selectedAudience == 'Specific User') {
      payload['userId'] = _userIdController.text.trim();
    }

    if (_selectedAudience == 'User Segment') {
      payload['segment'] = _segmentController.text.trim();
    }

    try {
      await FirebaseFirestore.instance.collection('notifications').add(payload);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification queued for delivery.')),
      );
      _clearForm();
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
    }
  }

  String _formatCreatedAt(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Time unavailable';
    }
    final DateTime value = timestamp.toDate();
    final String twoDigitMonth = value.month.toString().padLeft(2, '0');
    final String twoDigitDay = value.day.toString().padLeft(2, '0');
    final String twoDigitHour = value.hour.toString().padLeft(2, '0');
    final String twoDigitMinute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
  }

  Future<void> _deleteNotification(String docId) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text(
              'Are you sure you want to delete this notification?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _deletingNotificationIds.add(docId);
    });

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .delete();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted successfully.')),
      );
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _deletingNotificationIds.remove(docId);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    _segmentController.dispose();
    _linkController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notification'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.surface, colors.surfaceContainerHighest],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Push Notification',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Compose and deliver a message to users with a live '
                      'preview before sending.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Notification Content',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _titleController,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Title',
                                prefixIcon: const Icon(Icons.title_outlined),
                                filled: true,
                                fillColor: colors.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _messageController,
                              maxLines: 4,
                              maxLength: 240,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Message',
                                alignLabelWithHint: true,
                                prefixIcon: const Icon(Icons.message_outlined),
                                filled: true,
                                fillColor: colors.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Action Link & Image',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _showProductPickerDialog,
                                  icon: const Icon(Icons.link),
                                  label: const Text('Link Product'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _linkController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Deep Link URL',
                                prefixIcon: const Icon(Icons.link_outlined),
                                filled: true,
                                fillColor: colors.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _imageController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Image URL',
                                prefixIcon: const Icon(Icons.image_outlined),
                                filled: true,
                                fillColor: colors.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Targeting & Delivery',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedAudience,
                              items:
                                  _audiences
                                      .map(
                                        (String value) =>
                                            DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                      )
                                      .toList(),
                              onChanged: (String? value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedAudience = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Audience',
                                prefixIcon: const Icon(Icons.people_outline),
                                filled: true,
                                fillColor: colors.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child:
                                  _selectedAudience == 'Specific User'
                                      ? TextField(
                                        key: const ValueKey('userIdField'),
                                        controller: _userIdController,
                                        decoration: InputDecoration(
                                          labelText: 'User ID',
                                          prefixIcon: const Icon(
                                            Icons.person_outline,
                                          ),
                                          filled: true,
                                          fillColor:
                                              colors.surfaceContainerHighest,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      )
                                      : _selectedAudience == 'User Segment'
                                      ? TextField(
                                        key: const ValueKey('segmentField'),
                                        controller: _segmentController,
                                        decoration: InputDecoration(
                                          labelText: 'Segment',
                                          prefixIcon: const Icon(
                                            Icons.label_outline,
                                          ),
                                          filled: true,
                                          fillColor:
                                              colors.surfaceContainerHighest,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      )
                                      : const SizedBox.shrink(
                                        key: ValueKey('noUserIdField'),
                                      ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              value: _highPriority,
                              onChanged: (bool value) {
                                setState(() {
                                  _highPriority = value;
                                });
                              },
                              title: const Text('High priority'),
                              subtitle: const Text(
                                'Deliver immediately when possible.',
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            SwitchListTile(
                              value: _withSound,
                              onChanged: (bool value) {
                                setState(() {
                                  _withSound = value;
                                });
                              },
                              title: const Text('Play notification sound'),
                              subtitle: const Text(
                                'Use the default device sound.',
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: colors.primaryContainer,
                                        child: Icon(
                                          Icons.notifications_active_outlined,
                                          color: colors.onPrimaryContainer,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _titleController.text.isEmpty
                                                  ? 'Notification title'
                                                  : _titleController.text,
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _messageController.text.isEmpty
                                                  ? 'Your message will appear here.'
                                                  : _messageController.text,
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_linkController.text.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Link: ${_linkController.text}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: colors.primary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_imageController.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: _imageController.text.trim(),
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          height: 200,
                                          color: colors.surface,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          height: 120,
                                          color: colors.surface,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image_outlined, size: 32, color: colors.error),
                                              const SizedBox(height: 6),
                                              Text('Image preview unavailable', style: TextStyle(fontSize: 11, color: colors.error)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendNotification,
                            icon: const Icon(Icons.send_outlined),
                            label:
                                _isSending
                                    ? const Text('Sending...')
                                    : const Text('Send Notification'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isSending ? null : _clearForm,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification History',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('notifications')
                                      .orderBy('createdAt', descending: true)
                                      .snapshots(),
                              builder: (
                                BuildContext context,
                                AsyncSnapshot<
                                  QuerySnapshot<Map<String, dynamic>>
                                >
                                snapshot,
                              ) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Text(
                                    'Failed to load notifications: ${snapshot.error}',
                                    style: TextStyle(
                                      color: colors.error,
                                    ),
                                  );
                                }

                                final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                                docs = snapshot.data?.docs ?? [];

                                if (docs.isEmpty) {
                                  return const Text(
                                    'No notifications have been sent yet.',
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 16),
                                  itemBuilder: (
                                    BuildContext context,
                                    int index,
                                  ) {
                                    final QueryDocumentSnapshot<
                                      Map<String, dynamic>
                                    >
                                    doc = docs[index];
                                    final Map<String, dynamic> data = doc.data();
                                    final bool isDeleting =
                                        _deletingNotificationIds.contains(
                                          doc.id,
                                        );

                                    final String title =
                                        (data['title'] as String?)?.trim().isNotEmpty == true
                                            ? (data['title'] as String).trim()
                                            : 'Untitled';
                                    final String body =
                                        (data['body'] as String?)?.trim() ?? '';
                                    final String audience =
                                        (data['audience'] as String?)?.trim() ??
                                        'All Users';
                                    final String status =
                                        (data['status'] as String?)?.trim() ??
                                        'queued';
                                    final String? error =
                                        (data['error'] as String?)?.trim();
                                    final Timestamp? createdAt =
                                        data['createdAt'] as Timestamp?;

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(title),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            body.isEmpty
                                                ? 'No message body'
                                                : body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Audience: $audience | ${_formatCreatedAt(createdAt)}',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            error != null && error.isNotEmpty
                                                ? 'Status: $status | $error'
                                                : 'Status: $status',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        tooltip: 'Delete notification',
                                        onPressed:
                                            isDeleting
                                                ? null
                                                : () => _deleteNotification(
                                                  doc.id,
                                                ),
                                        icon:
                                            isDeleting
                                                ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                                : const Icon(
                                                  Icons.delete_outline,
                                                ),
                                        color: colors.error,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductPickerDialog extends StatefulWidget {
  final DatabaseService dbService;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _ProductPickerDialog({
    required this.dbService,
    required this.onSelect,
  });

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _stockFilter = 'all'; // 'all', 'in_stock', 'out_of_stock'
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialProducts();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        _searchController.text.trim().isEmpty) {
      _loadMoreProducts();
    }
  }

  void _onSearchChanged() {
    _applyFilter();
  }

  Future<void> _loadInitialProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final products = await widget.dbService.getProducts(
        page: 1,
        limit: 500,
        stock: 'all',
      );

      if (!mounted) return;

      setState(() {
        _allProducts = products;
        _currentPage = 1;
        _hasMore = products.length >= 500;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final moreProducts = await widget.dbService.getProducts(
        page: nextPage,
        limit: 500,
        stock: 'all',
      );

      if (!mounted) return;

      setState(() {
        _currentPage = nextPage;
        _allProducts.addAll(moreProducts);
        _hasMore = moreProducts.length >= 500;
        _isLoadingMore = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredProducts = _allProducts.where((product) {
        // Stock filter
        final isAvailable =
            product['stock'] == 'Available' || product['stock'] == 1;
        if (_stockFilter == 'in_stock' && !isAvailable) return false;
        if (_stockFilter == 'out_of_stock' && isAvailable) return false;

        // Search query filter
        if (query.isNotEmpty) {
          final name = (product['name'] ?? '').toString().toLowerCase();
          final brand = (product['brand'] ?? '').toString().toLowerCase();
          final category = (product['category'] ?? '').toString().toLowerCase();
          final id = (product['id'] ?? '').toString().toLowerCase();
          final price = (product['price'] ?? '').toString();

          final matches = name.contains(query) ||
              brand.contains(query) ||
              category.contains(query) ||
              id.contains(query) ||
              price.contains(query);

          if (!matches) return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    final inStockCount = _allProducts
        .where((p) => p['stock'] == 'Available' || p['stock'] == 1)
        .length;
    final outOfStockCount = _allProducts.length - inStockCount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withAlpha(128),
                border: Border(
                  bottom: BorderSide(
                    color: colors.outlineVariant.withAlpha(100),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: colors.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Product to Link',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isLoading
                                  ? 'Loading all products...'
                                  : 'Showing ${_filteredProducts.length} of ${_allProducts.length} products',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search products by name, brand, category, or ID...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant.withAlpha(160),
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withAlpha(128),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All (${_allProducts.length})',
                          value: 'all',
                          colors: colors,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'In Stock ($inStockCount)',
                          value: 'in_stock',
                          colors: colors,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Out of Stock ($outOfStockCount)',
                          value: 'out_of_stock',
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Product List / State
            Expanded(
              child: _buildBody(colors, theme),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withAlpha(70),
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withAlpha(100),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap any product to link it to the notification',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required ColorScheme colors,
  }) {
    final isSelected = _stockFilter == value;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
      ),
      selected: isSelected,
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surface,
      side: BorderSide(
        color:
            isSelected ? colors.primary : colors.outlineVariant.withAlpha(128),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onSelected: (_) {
        setState(() {
          _stockFilter = value;
        });
        _applyFilter();
      },
    );
  }

  Widget _buildBody(ColorScheme colors, ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading all products...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInitialProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: colors.onSurfaceVariant.withAlpha(128),
              ),
              const SizedBox(height: 12),
              Text(
                'No products found matching criteria',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try adjusting your search query or filter chips.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant.withAlpha(160),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _stockFilter = 'all';
                  });
                  _applyFilter();
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _filteredProducts.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: colors.outlineVariant.withAlpha(80),
        indent: 76,
      ),
      itemBuilder: (context, index) {
        if (index == _filteredProducts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final product = _filteredProducts[index];
        String imageUrl = (product['image20'] != null &&
                product['image20'].toString().isNotEmpty)
            ? product['image20'].toString()
            : (product['image2'] != null &&
                    product['image2'].toString().isNotEmpty)
                ? product['image2'].toString()
                : (product['image3'] != null &&
                        product['image3'].toString().isNotEmpty)
                    ? product['image3'].toString()
                    : (product['image5'] != null &&
                            product['image5'].toString().isNotEmpty)
                        ? product['image5'].toString()
                        : '';
        if (imageUrl.contains('img5_')) {
          imageUrl = imageUrl.replaceAll('img5_', 'img20_');
        }
        final isAvailable =
            product['stock'] == 'Available' || product['stock'] == 1;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 50,
              height: 50,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: colors.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: colors.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 20),
                      ),
                    )
                  : Container(
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined, size: 20),
                    ),
            ),
          ),
          title: Text(
            product['name']?.toString() ?? 'Unnamed Product',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(
                  '৳${product['price'] ?? '0'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    fontSize: 13,
                  ),
                ),
                if ((product['brand'] ?? '').toString().isNotEmpty &&
                    product['brand'] != 'Others') ...[
                  const SizedBox(width: 8),
                  Text(
                    '• ${product['brand']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if ((product['category'] ?? '').toString().isNotEmpty &&
                    product['category'] != 'Others') ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '• ${product['category']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.green.withAlpha(25)
                        : Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isAvailable
                          ? Colors.green.withAlpha(120)
                          : Colors.orange.withAlpha(120),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isAvailable ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          isAvailable ? Colors.green[800] : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: const Icon(
            Icons.add_link_rounded,
            size: 22,
          ),
          onTap: () {
            widget.onSelect(product);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
