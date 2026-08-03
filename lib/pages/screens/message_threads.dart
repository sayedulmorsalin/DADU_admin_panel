import 'dart:async';
import 'package:dadu_admin_panel/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/chat_storage_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _threads = [];
  Map<String, DateTime> _lastSeenMap = {};
  Set<String> _pinnedUserIds = {};
  final Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;
  final Map<String, Map<String, dynamic>> _userCache = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 20;
  
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadThreads();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isSelectionMode) {
        _loadMoreThreads();
      }
    }
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
    _scrollController.dispose();
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

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    try {
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value).toUtc();
      if (value is String && value.isNotEmpty) {
        // If the string doesn't specify a timezone, treat it as UTC
        String cleaned = value.trim();
        if (!cleaned.endsWith('Z') && !cleaned.contains(RegExp(r'[+-]\d{2}:?\d{2}$'))) {
          cleaned += 'Z';
        }
        return DateTime.parse(cleaned).toUtc();
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0).toUtc();
  }

  Future<void> _loadThreads({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final threads = await _apiService.fetchMessageThreads(page: 1, limit: _limit);
      
      // Fetch local last seen timestamps and pinned users
      final userIds = threads.map((t) => (t['uid'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      final lastSeen = await ChatStorageService.getAllLastSeen(userIds);
      final pinned = await ChatStorageService.getPinnedUsers();

      if (mounted) {
        setState(() {
          _threads = threads;
          _lastSeenMap = lastSeen;
          _pinnedUserIds = pinned;
          _isLoading = false;
          _currentPage = 1;
          _hasMore = threads.length == _limit;
          _sortThreads();
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

  void _sortThreads() {
    _threads.sort((a, b) {
      final String idA = (a['uid'] ?? '').toString();
      final String idB = (b['uid'] ?? '').toString();
      final bool isPinnedA = _pinnedUserIds.contains(idA);
      final bool isPinnedB = _pinnedUserIds.contains(idB);

      if (isPinnedA && !isPinnedB) return -1;
      if (!isPinnedA && isPinnedB) return 1;

      final DateTime dateA = _parseDateTime(a['lastMessageAt']);
      final DateTime dateB = _parseDateTime(b['lastMessageAt']);
      return dateB.compareTo(dateA);
    });
  }

  Future<void> _loadMoreThreads() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newThreads = await _apiService.fetchMessageThreads(page: nextPage, limit: _limit);
      
      if (newThreads.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Fetch local last seen for new threads
      final newIds = newThreads.map((t) => (t['uid'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      final newLastSeen = await ChatStorageService.getAllLastSeen(newIds);

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          
          // Avoid duplicates if polling already brought some in
          final existingIds = _threads.map((t) => t['uid']).toSet();
          final uniqueNew = newThreads.where((t) => !existingIds.contains(t['uid'])).toList();
          
          _threads.addAll(uniqueNew);
          _lastSeenMap.addAll(newLastSeen);
          _hasMore = newThreads.length == _limit;
          _isLoadingMore = false;
          _sortThreads();
        });
      }
    } catch (e) {
      debugPrint('Error loading more threads: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        if (_selectedUserIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedUserIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _handlePinAction() async {
    final bool shouldPin = _selectedUserIds.any((id) => !_pinnedUserIds.contains(id));
    
    for (final id in _selectedUserIds) {
      await ChatStorageService.togglePin(id, shouldPin);
    }
    
    _exitSelectionMode();
    _loadThreads(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedUserIds.length} selected'),
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedUserIds.any((id) => !_pinnedUserIds.contains(id))
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                  ),
                  onPressed: _handlePinAction,
                ),
              ],
            )
          : AppBar(
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
                  controller: _scrollController,
                  itemCount: _threads.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == _threads.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final thread = _threads[index];
                    final email = thread['email'] ?? 'Unknown User';
                    final userId = (thread['uid'] ?? '').toString();
                    final lastMessageAt = thread['lastMessageAt'];
                    final bool isBlocked = thread['isBlockedFromMessaging'] == 1 || thread['isBlockedFromMessaging'] == true;
                    final bool isSelected = _selectedUserIds.contains(userId);
                    final bool isPinned = _pinnedUserIds.contains(userId);
                    
                    // Robust Unread message detection
                    // Check local tracking first, then fallback to API fields
                    final DateTime lastMessageDateTime = _parseDateTime(lastMessageAt);
                    final DateTime lastSeenAt = _lastSeenMap[userId] ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc();
                    
                    // A message is unread if:
                    // 1. It arrived AFTER we last saw the chat (with a 2s buffer to prevent self-message false positives)
                    // 2. AND the last sender was NOT the admin (if role is available)
                    final bool isNewerThanSeen = lastMessageDateTime.isAfter(lastSeenAt.add(const Duration(seconds: 2)));
                    
                    final int unreadCount = int.tryParse((thread['unreadCount'] ?? thread['unread_count'] ?? thread['unReadCount'] ?? '0').toString()) ?? 0;
                    final String lastSender = (thread['lastMessageSenderRole'] ?? thread['last_sender_role'] ?? thread['role'] ?? thread['senderRole'] ?? '').toString().toLowerCase();
                    
                    bool isUnread = (unreadCount > 0) || 
                                    thread['isUnread'] == true || 
                                    thread['is_unread'] == true || 
                                    thread['status'] == 'unread';
                    
                    // If not already marked unread by API, check our local tracking
                    if (!isUnread && isNewerThanSeen) {
                      // Only mark as unread if we are sure it's not from the admin
                      if (lastSender.isEmpty || (lastSender != 'admin' && lastSender != 'staff')) {
                        isUnread = true;
                      }
                    }
                    
                    final String? lastMessage = thread['lastMessageSnippet'] ?? 
                                               thread['lastMessage'] ?? 
                                               thread['message'] ?? 
                                               thread['last_message'];
                    
                    String formattedDate = '';
                    if (lastMessageAt != null) {
                      try {
                        // Force Dhaka Time (UTC+6)
                        final dhakaDate = lastMessageDateTime.add(const Duration(hours: 6));
                        final nowDhaka = DateTime.now().toUtc().add(const Duration(hours: 6));
                        
                        if (dhakaDate.year == nowDhaka.year && dhakaDate.month == nowDhaka.month && dhakaDate.day == nowDhaka.day) {
                          formattedDate = DateFormat('hh:mm a').format(dhakaDate);
                        } else {
                          formattedDate = DateFormat('MMM dd, hh:mm a').format(dhakaDate);
                        }
                      } catch (e) {
                        formattedDate = lastMessageAt.toString();
                      }
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
                        final profilePic = userData?['profile_pic']?.toString().trim();
                        final displayEmail = userData?['email'] ?? email;

                        final bool hasValidImage = profilePic != null && 
                                                 profilePic.isNotEmpty && 
                                                 profilePic != "null" && 
                                                 profilePic.startsWith('http');

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: Colors.blue[100],
                          tileColor: isUnread ? Colors.blue.withValues(alpha: 0.15) : (isPinned ? Colors.yellow.withValues(alpha: 0.05) : null),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSelected 
                                    ? Colors.blue[900] 
                                    : (isUnread ? Colors.blue[400] : Colors.blue[100]),
                                backgroundImage: hasValidImage ? NetworkImage(profilePic) : null,
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white)
                                    : (!hasValidImage 
                                        ? Text(
                                            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isUnread ? Colors.white : Colors.blue[800],
                                            ),
                                          )
                                        : null),
                              ),
                              if (isPinned && !isSelected)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: const Icon(Icons.push_pin, size: 10, color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              if (isPinned)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.push_pin, size: 14, color: Colors.orange),
                                ),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.w900 : (isPinned ? FontWeight.bold : FontWeight.bold),
                                    color: isUnread ? Colors.blue[900] : (isPinned ? Colors.orange[900] : Colors.black87),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isBlocked)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
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
                              if (lastMessage != null && lastMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                                  child: Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                      color: isUnread ? Colors.black87 : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              Text(displayEmail, style: const TextStyle(fontSize: 12)),
                              Text('Last message: $formattedDate', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount > 0 
                                      ? (unreadCount > 99 ? '99+' : unreadCount.toString())
                                      : 'NEW',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                              });
                            }
                            _toggleSelection(userId);
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(userId);
                            } else {
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
                            }
                          },
                        );
                      }
                    );
                  },
                ),
    );
  }
}
