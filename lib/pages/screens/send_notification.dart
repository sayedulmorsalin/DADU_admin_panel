import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
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
        return AlertDialog(
          title: const Text('Select Product'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _dbService.getProducts(limit: 50),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(child: Text('No products found'));
                }
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final imageUrl = product['image20'] ?? product['image5'] ?? '';
                    return ListTile(
                      leading: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.image),
                      title: Text(product['name'] ?? ''),
                      subtitle: Text('৳${product['price']}'),
                      onTap: () {
                        setState(() {
                          _linkController.text = 'https://dadubd.com/product?id=${product['id']}';
                          _imageController.text = imageUrl;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _imageController.text.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: _imageController.text,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) => CircleAvatar(
                                              radius: 22,
                                              backgroundColor: colors.primaryContainer,
                                              child: Icon(
                                                Icons.notifications_active_outlined,
                                                color: colors.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 22,
                                          backgroundColor: colors.primaryContainer,
                                          child: Icon(
                                            Icons.notifications_active_outlined,
                                            color: colors.onPrimaryContainer,
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
