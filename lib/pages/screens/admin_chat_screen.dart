import 'dart:async';
import 'package:dadu_admin_panel/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import '../../services/api_service.dart';

class AdminChatScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String? userName;
  final String? userImage;
  final bool isInitialBlocked;

  const AdminChatScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    this.userName,
    this.userImage,
    this.isInitialBlocked = false,
  });

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> with WidgetsBindingObserver, RouteAware {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isBlocked = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _isBlocked = widget.isInitialBlocked;
    WidgetsBinding.instance.addObserver(this);
    _loadMessages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _stopPolling();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        _startPolling();
      }
    } else {
      _stopPolling();
    }
  }

  @override
  void didPushNext() {
    _stopPolling();
  }

  @override
  void didPopNext() {
    _startPolling();
  }

  void _startPolling() {
    if (!mounted) return;
    if (_pollingTimer != null && _pollingTimer!.isActive) return;

    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      debugPrint('AdminChatScreen: Skipping polling start - route not current');
      return;
    }

    debugPrint('ADMIN_PANEL: AdminChatScreen: Starting 10s polling');
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadMessages(showLoading: false));
  }

  void _stopPolling() {
    debugPrint('ADMIN_PANEL: AdminChatScreen: Stopping polling');
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading && _messages.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final fetchedMessages = await _apiService.fetchUserMessages(widget.userId);
      
      if (mounted) {
        final bool shouldScroll = _messages.length != fetchedMessages.length;
        setState(() {
          _messages = fetchedMessages;
          _isLoading = false;
        });

        if (shouldScroll) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final success = await _apiService.sendReply(widget.userId, text);
      if (success) {
        _messageController.clear();
        await _loadMessages(showLoading: false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _handleBlockToggle() async {
    final bool newBlockStatus = !_isBlocked;
    
    // Show confirmation dialog for blocking
    if (newBlockStatus) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Block User'),
          content: Text('Are you sure you want to block ${widget.userName ?? widget.userEmail} from messaging?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _apiService.toggleBlockUser(widget.userId, newBlockStatus);
      if (success) {
        setState(() => _isBlocked = newBlockStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newBlockStatus ? 'User blocked' : 'User unblocked'),
            backgroundColor: newBlockStatus ? Colors.red : Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update block status')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyEmail() {
    FlutterClipboard.copy(widget.userEmail).then((value) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[100],
              backgroundImage: widget.userImage != null ? NetworkImage(widget.userImage!) : null,
              child: widget.userImage == null 
                ? Text(
                    (widget.userName ?? widget.userEmail).substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  )
                : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName ?? 'Chat with User',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.userEmail,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _handleBlockToggle();
              } else if (value == 'copy_email') {
                _copyEmail();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy_email',
                child: const Row(
                  children: [
                    Icon(Icons.content_copy, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Copy Email'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.check_circle_outline : Icons.block,
                      color: _isBlocked ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(_isBlocked ? 'Unblock User' : 'Block User'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final bool isAdmin = msg['senderRole'] == 'admin';
                          final String text = msg['message'] ?? '';
                          final String createdAt = msg['createdAt'] ?? '';
                          
                          String formattedTime = '';
                          if (createdAt.isNotEmpty) {
                            final date = DateTime.parse(createdAt).toLocal();
                            formattedTime = DateFormat('hh:mm a').format(date);
                          }

                          return Align(
                            alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAdmin ? Colors.blue[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12).copyWith(
                                  bottomRight: isAdmin ? const Radius.circular(0) : const Radius.circular(12),
                                  bottomLeft: isAdmin ? const Radius.circular(12) : const Radius.circular(0),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    text,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: _sendMessage,
            ),
        ],
      ),
    );
  }
}
