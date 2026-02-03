import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SendNotification extends StatefulWidget {
  const SendNotification({super.key});

  @override
  State<SendNotification> createState() => _SendNotificationState();
}

class _SendNotificationState extends State<SendNotification> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _deepLinkController = TextEditingController();
  final TextEditingController _segmentController = TextEditingController();

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
    _deepLinkController.clear();
    _segmentController.clear();
    setState(() {
      _selectedAudience = _audiences.first;
      _highPriority = false;
      _withSound = true;
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final Map<String, dynamic> payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'body': _messageController.text.trim(),
      'deepLink': _deepLinkController.text.trim(),
      'audience': _selectedAudience,
      'userId': _userIdController.text.trim(),
      'segment': _segmentController.text.trim(),
      'highPriority': _highPriority,
      'withSound': _withSound,
      'createdAt': FieldValue.serverTimestamp(),
    };

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    _deepLinkController.dispose();
    _segmentController.dispose();
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
                            TextField(
                              controller: _deepLinkController,
                              decoration: InputDecoration(
                                labelText: 'Deep Link (optional)',
                                prefixIcon: const Icon(Icons.link_outlined),
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
                                children: [
                                  CircleAvatar(
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
