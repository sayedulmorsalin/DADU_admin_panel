import 'dart:async';
import 'package:dadu_admin_panel/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../services/database_service.dart';
import 'admin_chat_screen.dart';

class MessageThreadsPage extends StatefulWidget {
  const MessageThreadsPage({super.key});

  @override
  State<MessageThreadsPage> createState() => _MessageThreadsPageState();
}

class _MessageThreadsPageState extends State<MessageThreadsPage> with WidgetsBindingObserver, RouteAware {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _threads = [];
  final Map<String, Map<String, dynamic>> _userCache = {};
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThreads();
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
    // When another page is pushed on top of this one
    _stopPolling();
  }

  @override
  void didPopNext() {
    // When the top page is popped and we are visible again
    _startPolling();
  }

  void _startPolling() {
    if (!mounted) return;
    if (_refreshTimer != null && _refreshTimer!.isActive) return;
    
    // Extra safety: Only poll if this route is actually on top
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      debugPrint('MessageThreadsPage: Skipping polling start - route not current');
      return;
    }
    
    debugPrint('ADMIN_PANEL: MessageThreadsPage: Starting 30s polling');
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadThreads(showLoading: false));
  }

  void _stopPolling() {
    debugPrint('MessageThreadsPage: Stopping polling');
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadThreads({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final threads = await _apiService.fetchMessageThreads();
      if (mounted) {
        setState(() {
          _threads = threads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Messages'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _loadThreads(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _threads.isEmpty
              ? const Center(child: Text('No messages yet.'))
              : ListView.separated(
                  itemCount: _threads.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final thread = _threads[index];
                    final email = thread['email'] ?? 'Unknown User';
                    final userId = thread['uid'];
                    final lastMessageAt = thread['lastMessageAt'];
                    final bool isBlocked = thread['isBlockedFromMessaging'] == 1 || thread['isBlockedFromMessaging'] == true;
                    
                    String formattedDate = '';
                    if (lastMessageAt != null) {
                      final date = DateTime.parse(lastMessageAt).toLocal();
                      formattedDate = DateFormat('MMM dd, hh:mm a').format(date);
                    }

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _userCache.containsKey(userId) 
                        ? Future.value(_userCache[userId]) 
                        : _dbService.getUserById(userId).then((u) {
                            if (u != null) _userCache[userId] = u;
                            return u;
                          }),
                      builder: (context, snapshot) {
                        final userData = snapshot.data;
                        final name = userData?['name'] ?? email;
                        final profilePic = userData?['profile_pic'];
                        final displayEmail = userData?['email'] ?? email;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                            child: profilePic == null 
                              ? Text(
                                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )
                              : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isBlocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red),
                                  ),
                                  child: const Text(
                                    'Blocked',
                                    style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayEmail, style: const TextStyle(fontSize: 12)),
                              Text('Last message: $formattedDate', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminChatScreen(
                                  userId: userId,
                                  userEmail: displayEmail,
                                  userName: name,
                                  userImage: profilePic,
                                  isInitialBlocked: isBlocked,
                                ),
                              ),
                            ).then((_) => _loadThreads(showLoading: false));
                          },
                        );
                      }
                    );
                  },
                ),
    );
  }
}
