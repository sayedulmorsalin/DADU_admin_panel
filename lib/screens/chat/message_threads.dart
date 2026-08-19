import 'dart:async';
import 'package:dadu_admin_panel/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dadu_admin_panel/services/api_service.dart';
import 'package:dadu_admin_panel/services/chat_storage_service.dart';
import 'package:dadu_admin_panel/services/database_service.dart';
import 'package:dadu_admin_panel/services/chat_socket_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dadu_admin_panel/screens/chat/admin_chat_screen.dart';
import 'package:dadu_admin_panel/widgets/sports_background_pattern.dart';
import 'package:dadu_admin_panel/widgets/smooth_slow_scroll_physics.dart';

class MessageThreadsPage extends StatefulWidget {
  const MessageThreadsPage({super.key});

  @override
  State<MessageThreadsPage> createState() => _MessageThreadsPageState();
}

class _MessageThreadsPageState extends State<MessageThreadsPage> with WidgetsBindingObserver, RouteAware {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  final ChatSocketService _socketService = ChatSocketService();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _threads = [];
  Map<String, DateTime> _lastSeenMap = {};
  Set<String> _pinnedUserIds = {};
  final Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, Future<Map<String, dynamic>?>> _userFutures = {};

  // Messaging toggle state
  bool _messagingEnabled = true;
  bool _isTogglingStatus = false;
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 20;
  
  Timer? _refreshTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadThreads();
    _listenToSocketEvents();
    _loadMessagingStatus();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      if (!_isLoadingMore && _hasMore && !_isSelectionMode) {
        _loadMoreThreads();
      }
    }
  }

  void _prefetchUsers(List<Map<String, dynamic>> threadList) {
    for (final t in threadList) {
      final String uid = (t['uid'] ?? '').toString();
      if (uid.isNotEmpty && !_userCache.containsKey(uid)) {
        _dbService.getUserById(uid).then((u) {
          if (u != null && mounted) {
            setState(() {
              _userCache[uid] = u;
            });
          }
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    _stopPolling();
    _socketSubscription?.cancel();
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

  Future<void> _loadMessagingStatus() async {
    try {
      final enabled = await _apiService.fetchMessagingStatus();
      if (mounted) {
        setState(() {
          _messagingEnabled = enabled;
        });
      }
    } catch (e) {
      debugPrint('MessageThreadsPage: Error loading messaging status: $e');
    }
  }

  Future<void> _toggleMessaging(bool value) async {
    if (_isTogglingStatus) return;
    setState(() => _isTogglingStatus = true);

    final success = await _apiService.updateMessagingStatus(value);
    if (mounted) {
      setState(() {
        if (success) _messagingEnabled = value;
        _isTogglingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Messaging ${value ? 'enabled' : 'disabled'} successfully'
                : 'Failed to update messaging status',
          ),
          backgroundColor: success
              ? (value ? Colors.green : Colors.orange)
              : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  bool _isThreadUnread(Map<String, dynamic> thread) {
    final String userId = (thread['uid'] ?? '').toString();
    final lastMessageAt = thread['lastMessageAt'];
    final DateTime lastMessageDateTime = _parseDateTime(lastMessageAt);
    final DateTime lastSeenAt = _lastSeenMap[userId] ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    
    final bool isNewerThanSeen = lastMessageDateTime.isAfter(lastSeenAt.add(const Duration(seconds: 2)));
    
    final int unreadCount = int.tryParse((thread['unreadCount'] ?? thread['unread_count'] ?? thread['unReadCount'] ?? '0').toString()) ?? 0;
    final String lastSender = (thread['lastMessageSenderRole'] ?? thread['last_sender_role'] ?? thread['role'] ?? thread['senderRole'] ?? '').toString().toLowerCase();
    
    bool isUnread = (unreadCount > 0) || 
                   thread['isUnread'] == true || 
                   thread['is_unread'] == true || 
                   thread['status'] == 'unread';
    
    if (!isUnread && isNewerThanSeen) {
      if (lastSender.isEmpty || (lastSender != 'admin' && lastSender != 'staff')) {
        isUnread = true;
      }
    }

    if (lastSender == 'admin' || lastSender == 'staff') {
      isUnread = false;
    }
    
    return isUnread;
  }

  /// Listens to WebSocket events forwarded through [ChatSocketService].
  /// Updates thread list real-time on [new_message] and [thread_read] events.
  void _listenToSocketEvents() {
    _socketSubscription = _socketService.messageStream.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'thread_read') {
        final String? threadUserId = event['threadUserId']?.toString();
        final String? lastReadAtStr = event['lastReadAt']?.toString();
        if (threadUserId != null && lastReadAtStr != null) {
          try {
            final DateTime lastReadAt = DateTime.parse(lastReadAtStr).toUtc();
            setState(() {
              _lastSeenMap[threadUserId] = lastReadAt;
            });
          } catch (_) {}
        }
      } else if (event['type'] == 'new_message' || event['type'] == 'message') {
        final String senderId = (event['userId'] ?? event['uid'] ?? event['senderId'] ?? '').toString();
        final String msgText = (event['message'] ?? event['body'] ?? '').toString();
        final String? imgUrl = event['imageUrl'];
        final String? voiceUrl = event['voiceNoteUrl'];
        final String role = (event['senderRole'] ?? event['role'] ?? '').toString();
        final String timestamp = (event['createdAt'] ?? event['timestamp'] ?? DateTime.now().toUtc().toIso8601String()).toString();

        String snippet = msgText;
        if (imgUrl != null && imgUrl.isNotEmpty) {
          snippet = msgText.isNotEmpty && msgText != 'Image' ? '📷 $msgText' : '📷 Image';
        } else if (voiceUrl != null && voiceUrl.isNotEmpty) {
          snippet = '🎤 Voice Note';
        }

        if (senderId.isNotEmpty) {
          setState(() {
            final int index = _threads.indexWhere((t) => (t['uid'] ?? '').toString() == senderId);
            if (index != -1) {
              _threads[index]['lastMessageSnippet'] = snippet;
              _threads[index]['lastMessageAt'] = timestamp;
              _threads[index]['lastMessageSenderRole'] = role;
              if (role.toLowerCase() != 'admin' && role.toLowerCase() != 'staff') {
                final int currentUnread = int.tryParse((_threads[index]['unreadCount'] ?? 0).toString()) ?? 0;
                _threads[index]['unreadCount'] = currentUnread + 1;
              }
            }
            _sortThreads();
          });
        }
      }
    });
  }

  Future<void> _loadThreads({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // When refreshing/polling or returning after reply (showLoading: false),
      // fetch up to current loaded count so we don't truncate loaded pages.
      final int fetchLimit = showLoading ? _limit : (_currentPage * _limit);
      final threads = await _apiService.fetchMessageThreads(page: 1, limit: fetchLimit);
      
      // Build lastSeenMap: prefer DB lastReadAt from API response,
      // fall back to local SharedPreferences for threads not yet in DB.
      final userIds = threads.map((t) => (t['uid'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      final localLastSeen = await ChatStorageService.getAllLastSeen(userIds);
      final pinned = await ChatStorageService.getPinnedUsers();

      // Seed from the current in-memory map first so that any optimistic
      // read-stamp set before navigation is not lost when we overwrite
      // _lastSeenMap below (the REST / DB update may still be in-flight).
      final Map<String, DateTime> mergedLastSeen = Map.from(_lastSeenMap);

      // Layer local SharedPreferences values (prefer the newer timestamp).
      for (final entry in localLastSeen.entries) {
        final existing = mergedLastSeen[entry.key];
        if (existing == null || entry.value.isAfter(existing)) {
          mergedLastSeen[entry.key] = entry.value;
        }
      }

      // Layer DB values from API response (prefer the newer timestamp).
      for (final t in threads) {
        final String uid = (t['uid'] ?? '').toString();
        final dynamic dbLastRead = t['lastReadAt'];
        if (uid.isNotEmpty && dbLastRead != null) {
          try {
            final DateTime dbDate = DateTime.parse(dbLastRead.toString()).toUtc();
            // DB value wins only if it is newer than what we already have.
            if (dbDate.isAfter(mergedLastSeen[uid] ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc())) {
              mergedLastSeen[uid] = dbDate;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          if (showLoading || _threads.isEmpty) {
            _threads = threads;
            _currentPage = 1;
            _hasMore = threads.length == _limit;
          } else {
            // Update existing threads in-place or add new ones without discarding loaded pages
            final Map<String, int> indexMap = {};
            for (int i = 0; i < _threads.length; i++) {
              final id = (_threads[i]['uid'] ?? '').toString();
              if (id.isNotEmpty) indexMap[id] = i;
            }

            for (final fresh in threads) {
              final id = (fresh['uid'] ?? '').toString();
              if (id.isNotEmpty) {
                if (indexMap.containsKey(id)) {
                  _threads[indexMap[id]!] = fresh;
                } else {
                  _threads.add(fresh);
                }
              }
            }
          }
          _lastSeenMap = mergedLastSeen;
          _pinnedUserIds = pinned;
          _isLoading = false;
          _sortThreads();
          _prefetchUsers(threads);
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

      final bool isUnreadA = _isThreadUnread(a);
      final bool isUnreadB = _isThreadUnread(b);
      
      if (isUnreadA && !isUnreadB) return -1;
      if (!isUnreadA && isUnreadB) return 1;

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

      // Build lastSeen for new threads — merge DB value with local fallback.
      final newIds = newThreads.map((t) => (t['uid'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      final newLocalLastSeen = await ChatStorageService.getAllLastSeen(newIds);

      final Map<String, DateTime> newMergedLastSeen = Map.from(newLocalLastSeen);
      for (final t in newThreads) {
        final String uid = (t['uid'] ?? '').toString();
        final dynamic dbLastRead = t['lastReadAt'];
        if (uid.isNotEmpty && dbLastRead != null) {
          try {
            final DateTime dbDate = DateTime.parse(dbLastRead.toString()).toUtc();
            if (dbDate.isAfter(newMergedLastSeen[uid] ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc())) {
              newMergedLastSeen[uid] = dbDate;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          
          // Avoid duplicates if polling already brought some in
          final existingIds = _threads.map((t) => t['uid']).toSet();
          final uniqueNew = newThreads.where((t) => !existingIds.contains(t['uid'])).toList();
          
          _threads.addAll(uniqueNew);
          _lastSeenMap.addAll(newMergedLastSeen);
          _hasMore = newThreads.length == _limit;
          _isLoadingMore = false;
          _sortThreads();
          _prefetchUsers(uniqueNew);
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
              backgroundColor: const Color(0xFF0A192F), // Deep Stadium Blue
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
              backgroundColor: const Color(0xFF0A192F), // Deep Stadium Blue
              foregroundColor: Colors.white,
              actions: [
                // Messaging toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _messagingEnabled ? Icons.chat : Icons.chat_bubble_outline,
                      size: 18,
                      color: _messagingEnabled ? const Color(0xFF39FF14) : Colors.red[200], // Neon Green
                    ),
                    const SizedBox(width: 4),
                    _isTogglingStatus
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Switch(
                            value: _messagingEnabled,
                            onChanged: _toggleMessaging,
                            activeThumbColor: const Color(0xFF39FF14), // Neon Green
                            inactiveThumbColor: Colors.red[300],
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                    const SizedBox(width: 4),
                  ],
                ),
                IconButton(
                  onPressed: () => _loadThreads(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      backgroundColor: const Color(0xFF112240), // Dark Slate Background
      body: SportsBackgroundPattern(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
            : _threads.isEmpty
                ? const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.white70)))
              : ListView.separated(
                  key: const PageStorageKey<String>('message_threads_list'),
                  controller: _scrollController,
                  physics: const SmoothSlowScrollPhysics(),
                  cacheExtent: 500,
                  itemCount: _threads.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (context, index) {
                    if (index == _threads.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))),
                      );
                    }
                    final thread = _threads[index];
                    final email = thread['email'] ?? 'Unknown User';
                    final userId = (thread['uid'] ?? '').toString();
                    final lastMessageAt = thread['lastMessageAt'];
                    final bool isBlocked = thread['isBlockedFromMessaging'] == 1 || thread['isBlockedFromMessaging'] == true;
                    final bool isSelected = _selectedUserIds.contains(userId);
                    final bool isPinned = _pinnedUserIds.contains(userId);
                    
                    final DateTime lastMessageDateTime = _parseDateTime(lastMessageAt);
                    final int unreadCount = int.tryParse((thread['unreadCount'] ?? thread['unread_count'] ?? thread['unReadCount'] ?? '0').toString()) ?? 0;
                    final bool isUnread = _isThreadUnread(thread);
                    
                    final String? rawLastMessage = thread['lastMessageSnippet'] ?? 
                                               thread['last_message_snippet'] ?? 
                                               thread['lastMessage'] ?? 
                                               thread['last_message'] ?? 
                                               thread['message'] ?? 
                                               thread['snippet'] ?? 
                                               thread['body'] ?? 
                                               thread['lastMessageText'] ?? 
                                               thread['last_message_text'];
                    
                    String? lastMessage;
                    if (rawLastMessage != null && rawLastMessage.toString().trim().isNotEmpty) {
                      String cleaned = sanitizeUtf16(rawLastMessage).trim();
                      if (cleaned.startsWith('[IMAGE]:')) {
                        final parts = cleaned.substring(8).split('|');
                        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
                          cleaned = '📷 ${parts[1].trim()}';
                        } else {
                          cleaned = '📷 Image';
                        }
                      } else if (cleaned == 'Image') {
                        cleaned = '📷 Image';
                      } else if (cleaned == 'Voice Note') {
                        cleaned = '🎤 Voice Note';
                      }
                      lastMessage = cleaned;
                    } else if ((thread['imageUrl'] != null && thread['imageUrl'].toString().trim().isNotEmpty) ||
                               (thread['image_url'] != null && thread['image_url'].toString().trim().isNotEmpty) ||
                               thread['lastMessageType'] == 'image') {
                      lastMessage = '📷 Image';
                    } else if ((thread['voiceNoteUrl'] != null && thread['voiceNoteUrl'].toString().trim().isNotEmpty) ||
                               (thread['voice_note_url'] != null && thread['voice_note_url'].toString().trim().isNotEmpty) ||
                               thread['lastMessageType'] == 'voice_note') {
                      lastMessage = '🎤 Voice Note';
                    }

                    final String lastSenderRole = (thread['lastMessageSenderRole'] ?? thread['last_sender_role'] ?? thread['role'] ?? thread['senderRole'] ?? '').toString().toLowerCase();
                    if (lastMessage != null && lastMessage.isNotEmpty && (lastSenderRole == 'admin' || lastSenderRole == 'staff')) {
                      lastMessage = 'You: $lastMessage';
                    }
                    
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
                        formattedDate = sanitizeUtf16(lastMessageAt);
                      }
                    }

                    final userData = _userCache[userId];
                    if (userData == null && !_userFutures.containsKey(userId)) {
                      _userFutures[userId] = _dbService.getUserById(userId).then((u) {
                        if (u != null && mounted) {
                          setState(() {
                            _userCache[userId] = u;
                          });
                        }
                        return u;
                      });
                    }

                    return RepaintBoundary(
                      child: _buildTileContent(
                        context,
                        thread: thread,
                        userId: userId,
                        email: email,
                        userData: userData,
                        isUnread: isUnread,
                        isPinned: isPinned,
                        isSelected: isSelected,
                        isBlocked: isBlocked,
                        formattedDate: formattedDate,
                        unreadCount: unreadCount,
                        lastMessage: lastMessage,
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildTileContent(
    BuildContext context, {
    required Map<String, dynamic> thread,
    required String userId,
    required String email,
    required Map<String, dynamic>? userData,
    required bool isUnread,
    required bool isPinned,
    required bool isSelected,
    required bool isBlocked,
    required String formattedDate,
    required int unreadCount,
    required String? lastMessage,
  }) {
    final name = sanitizeUtf16(userData?['name'] ?? email);
    final profilePic = userData?['profile_pic']?.toString().trim();
    final displayEmail = sanitizeUtf16(userData?['email'] ?? email);

    final bool hasValidImage = profilePic != null && 
                             profilePic.isNotEmpty && 
                             profilePic != "null" && 
                             profilePic.startsWith('http');

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF0A192F),
                          tileColor: isUnread ? const Color(0xFF39FF14).withValues(alpha: 0.1) : (isPinned ? const Color(0xFFFF5722).withValues(alpha: 0.05) : null),
                          leading: Stack(
                            children: [
                              Hero(
                                tag: 'chat_user_avatar_$userId',
                                child: CircleAvatar(
                                  backgroundColor: isSelected 
                                      ? const Color(0xFF0A192F) 
                                      : (isUnread ? const Color(0xFF39FF14) : Colors.blueGrey[800]),
                                  backgroundImage: hasValidImage ? CachedNetworkImageProvider(profilePic) : null,
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white)
                                      : (!hasValidImage 
                                          ? Text(
                                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: isUnread ? Colors.black : Colors.white,
                                              ),
                                            )
                                          : null),
                                ),
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
                                      border: Border.all(color: const Color(0xFF112240)),
                                    ),
                                    child: const Icon(Icons.push_pin, size: 10, color: Color(0xFFFF5722)), // Action Orange
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              if (isPinned)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.push_pin, size: 14, color: Color(0xFFFF5722)),
                                ),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.w900 : (isPinned ? FontWeight.bold : FontWeight.w600),
                                    color: isUnread ? const Color(0xFF39FF14) : (isPinned ? const Color(0xFFFF5722) : Colors.white),
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
                              Text(displayEmail, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                              if (lastMessage != null && lastMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                                  child: Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                                      color: isUnread ? Colors.white : Colors.white60,
                                    ),
                                  ),
                                ),
                              Text('Last message: $formattedDate', style: const TextStyle(fontSize: 11, color: Colors.white38)),
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
                                    color: const Color(0xFF39FF14), // Neon Green
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF39FF14).withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)
                                    ],
                                  ),
                                  child: Text(
                                    unreadCount > 0 
                                      ? (unreadCount > 99 ? '99+' : unreadCount.toString())
                                      : 'NEW',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              else
                                const Icon(Icons.chevron_right, size: 20, color: Colors.white54),
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
                              // Optimistically mark the thread as read locally
                              // before navigation so the badge disappears immediately.
                              final String nowIso = DateTime.now().toUtc().toIso8601String();
                              setState(() {
                                _lastSeenMap[userId] = DateTime.now().toUtc();
                              });
                              // Persist to DB via REST (the WebSocket mark_read is
                              // sent from AdminChatScreen once the socket is open).
                              _apiService.markThreadRead(userId, nowIso);

                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => AdminChatScreen(
                                    userId: userId,
                                    userEmail: displayEmail,
                                    userName: name,
                                    userImage: profilePic,
                                    isInitialBlocked: isBlocked,
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    final curvedAnimation = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                      reverseCurve: Curves.easeInCubic,
                                    );
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.08, 0.0),
                                        end: Offset.zero,
                                      ).animate(curvedAnimation),
                                      child: FadeTransition(
                                        opacity: curvedAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  transitionDuration: const Duration(milliseconds: 280),
                                ),
                              ).then((_) {
                                // Re-stamp lastSeenMap after returning so any message
                                // the admin sent during the chat does not cause a false
                                // unread badge (their lastMessageAt would otherwise be
                                // newer than the lastSeenAt captured at tap-time).
                                final String returnedNowIso = DateTime.now().toUtc().toIso8601String();
                                if (mounted) {
                                  setState(() {
                                    _lastSeenMap[userId] = DateTime.now().toUtc();
                                  });
                                }
                                _apiService.markThreadRead(userId, returnedNowIso);
                                _loadThreads(showLoading: false);
                              });
                            }
                          },
                        );
                      }
                    }
