import 'dart:async';
import 'dart:io';
import 'package:dadu_admin_panel/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dadu_admin_panel/services/api_service.dart';
import 'package:dadu_admin_panel/services/chat_storage_service.dart';
import 'package:dadu_admin_panel/services/chat_socket_service.dart';
import 'package:dadu_admin_panel/widgets/voice_note_player.dart';
import 'package:dadu_admin_panel/widgets/typing_indicator.dart';
import 'package:dadu_admin_panel/services/image_upload_service.dart';
import 'package:dadu_admin_panel/services/database_service.dart';
import 'package:dadu_admin_panel/widgets/sports_background_pattern.dart';
import 'package:dadu_admin_panel/widgets/smooth_slow_scroll_physics.dart';

String sanitizeUtf16(dynamic val) {
  if (val == null) return '';
  final String str = val.toString();
  if (str.isEmpty) return str;

  final List<int> codeUnits = str.codeUnits;
  final StringBuffer sb = StringBuffer();
  final int len = codeUnits.length;

  for (int i = 0; i < len; i++) {
    final int unit = codeUnits[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 < len &&
          codeUnits[i + 1] >= 0xDC00 &&
          codeUnits[i + 1] <= 0xDFFF) {
        sb.writeCharCode(unit);
        sb.writeCharCode(codeUnits[i + 1]);
        i++;
      } else {
        sb.writeCharCode(0xFFFD);
      }
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      sb.writeCharCode(0xFFFD);
    } else {
      sb.writeCharCode(unit);
    }
  }

  return sb.toString();
}

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

class _AdminChatScreenState extends State<AdminChatScreen>
    with WidgetsBindingObserver, RouteAware {
  final ApiService _apiService = ApiService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final DatabaseService _databaseService = DatabaseService();
  final ChatSocketService _socketService = ChatSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AudioRecorder _audioRecorder;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isBlocked = false;
  Map<String, dynamic>? _replyingToMessage;
  String? _highlightedMessageId;

  final List<File> _selectedImages = [];
  File? _selectedVoiceNote;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  String _getReplySnippet(Map<String, dynamic> msg) {
    final String text = sanitizeUtf16((msg['message'] ?? '').toString().trim());
    final String? imgUrl = msg['imageUrl'] ?? msg['image'] ?? msg['img_url'];

    if (imgUrl != null && imgUrl.isNotEmpty) {
      final String firstImg = imgUrl.split(',').first.trim();
      if (text.isNotEmpty && text != "Image") {
        return "[IMAGE]:$firstImg|$text";
      }
      return "[IMAGE]:$firstImg";
    }

    if (text.isNotEmpty && text != "Image" && text != "Voice Note") {
      return text;
    }
    if (msg['voiceNoteUrl'] != null || text == "Voice Note") {
      return "🎤 Voice Note";
    }
    return text.isNotEmpty ? text : "Message";
  }

  void _scrollToAndHighlightMessage(String targetId) {
    if (targetId.isEmpty || _messages.isEmpty) return;
    final index = _messages.indexWhere(
      (msg) => (msg['id'] ?? '').toString() == targetId,
    );
    if (index != -1 && _scrollController.hasClients) {
      final double maxScroll = _scrollController.position.maxScrollExtent;
      final double targetOffset = (index / _messages.length) * maxScroll;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      setState(() {
        _highlightedMessageId = targetId;
      });

      Timer(const Duration(milliseconds: 1800), () {
        if (mounted && _highlightedMessageId == targetId) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _isBlocked = widget.isInitialBlocked;
    try {
      _audioRecorder = AudioRecorder();
    } catch (e) {
      debugPrint('AdminChatScreen: AudioRecorder init error: $e');
    }
    WidgetsBinding.instance.addObserver(this);

    _loadMessages();
    _socketService.connect(widget.userId);
    _listenToSocket();
  }

  void _listenToSocket() {
    _socketSubscription?.cancel();
    _socketSubscription = _socketService.messageStream.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'new_message') {
        final String messageId = (event['id'] ?? '').toString();
        final bool alreadyExists =
            messageId.isNotEmpty &&
            _messages.any((msg) => (msg['id'] ?? '').toString() == messageId);

        if (!alreadyExists && mounted) {
          setState(() {
            _messages.add(event);
            _messages.sort((a, b) {
              final String tA =
                  (a['createdAt'] ?? a['timestamp'] ?? '').toString();
              final String tB =
                  (b['createdAt'] ?? b['timestamp'] ?? '').toString();
              return tA.compareTo(tB);
            });
          });
          _scrollToBottom();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    _socketService.sendStopTyping();
    _recordTimer?.cancel();
    _socketSubscription?.cancel();
    try {
      _audioRecorder.dispose();
    } catch (_) {}
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        _socketService.connect(widget.userId);
      }
    }
  }

  @override
  void didPushNext() {}

  @override
  void didPopNext() {
    _socketService.connect(widget.userId);
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading && _messages.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final fetchedMessages = await _apiService.fetchUserMessages(
        widget.userId,
      );

      if (mounted) {
        final bool shouldScroll = _messages.length != fetchedMessages.length;
        setState(() {
          _messages = fetchedMessages;
          _isLoading = false;
        });

        if (shouldScroll) {
          _scrollToBottom();
        }

        // Update local last seen timestamp (fast local fallback for immediate UI).
        final String nowIso = DateTime.now().toUtc().toIso8601String();
        await ChatStorageService.updateLastSeen(widget.userId);

        // Persist read state to DB via WebSocket (real-time sync across devices/admins).
        // The socket may not be connected yet on first load — sendMarkRead is a no-op
        // if the socket is not connected, but the REST fallback covers that case.
        _socketService.sendMarkRead(nowIso);
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
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _isRecording) {
            setState(() {
              _recordDuration++;
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null && path.isNotEmpty) {
          _selectedVoiceNote = File(path);
        }
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _cancelVoiceNote() {
    _recordTimer?.cancel();
    if (_isRecording) {
      _audioRecorder.stop();
    }
    setState(() {
      _isRecording = false;
      _selectedVoiceNote = null;
      _recordDuration = 0;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if ((text.isEmpty &&
            _selectedImages.isEmpty &&
            _selectedVoiceNote == null) ||
        _isSending)
      return;

    setState(() {
      _isSending = true;
    });

    _socketService.sendStopTyping();

    final String? replyToId = _replyingToMessage?['id'];
    final String? replyToText =
        _replyingToMessage != null
            ? _getReplySnippet(_replyingToMessage!)
            : null;
    final String? replyToSenderRole = _replyingToMessage?['senderRole'];

    try {
      String? imageUrl;
      if (_selectedImages.isNotEmpty) {
        final urls = await _imageUploadService.uploadMultipleChatImages(
          _selectedImages,
        );
        if (urls.isNotEmpty) {
          imageUrl = urls.join(',');
        }
      }

      String? voiceNoteUrl;
      if (_selectedVoiceNote != null) {
        voiceNoteUrl = await _imageUploadService.uploadVoiceNote(
          _selectedVoiceNote!,
        );
      }

      if (_socketService.isConnected.value) {
        String bodyMsg = text;
        if (bodyMsg.isEmpty) {
          if (voiceNoteUrl != null) {
            bodyMsg = "Voice Note";
          } else if (imageUrl != null) {
            bodyMsg = "Image";
          }
        }

        _socketService.sendMessage(
          bodyMsg,
          imageUrl: imageUrl,
          voiceNoteUrl: voiceNoteUrl,
          replyToId: replyToId,
          replyToText: replyToText,
          replyToSenderRole: replyToSenderRole,
        );
        _messageController.clear();
        setState(() {
          _selectedImages.clear();
          _selectedVoiceNote = null;
          _replyingToMessage = null;
        });

        // Send push notification
        _databaseService.sendPushNotification(
          email: widget.userEmail,
          title: 'New Message from Admin',
          body:
              voiceNoteUrl != null
                  ? 'Sent a voice note'
                  : (text.isNotEmpty ? text : 'Sent attachment(s)'),
          link: 'https://dadubd.com/message',
          image: imageUrl?.split(',').first,
        );
      } else {
        // Fallback to HTTP
        final success = await _apiService.sendReply(
          widget.userId,
          text,
          imageUrl: imageUrl,
          voiceNoteUrl: voiceNoteUrl,
          replyToId: replyToId,
          replyToText: replyToText,
          replyToSenderRole: replyToSenderRole,
        );
        if (success) {
          _messageController.clear();
          setState(() {
            _selectedImages.clear();
            _selectedVoiceNote = null;
            _replyingToMessage = null;
          });

          _databaseService.sendPushNotification(
            email: widget.userEmail,
            title: 'New Message from Admin',
            body:
                voiceNoteUrl != null
                    ? 'Sent a voice note'
                    : (text.isNotEmpty ? text : 'Sent attachment(s)'),
            link: 'https://dadubd.com/message',
            image: imageUrl?.split(',').first,
          );

          await _loadMessages(showLoading: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    if (newBlockStatus) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Block User'),
              content: Text(
                'Are you sure you want to block ${widget.userName ?? widget.userEmail} from messaging?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
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
      final success = await _apiService.toggleBlockUser(
        widget.userId,
        newBlockStatus,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Widget _buildReplyContent(
    String replyText,
    String? senderRole,
    bool isAdmin,
  ) {
    String textDisplay = sanitizeUtf16(replyText);
    String? imgUrl;

    if (replyText.startsWith("[IMAGE]:")) {
      final parts = replyText.substring(8).split('|');
      imgUrl = parts[0];
      textDisplay = parts.length > 1 ? parts[1] : "Photo";
    } else if (replyText == "📷 Image") {
      textDisplay = "Photo";
    }

    final String? fullImgUrl =
        (imgUrl != null && imgUrl.isNotEmpty)
            ? ApiService.resolveUrl(imgUrl)
            : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fullImgUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: fullImgUrl,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorWidget:
                  (context, url, error) => const Icon(Icons.image, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderRole == 'admin' ? 'Admin' : (widget.userName ?? 'User'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isAdmin ? Colors.white : Colors.blue[900],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                textDisplay,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isAdmin ? Colors.white70 : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String rawName = widget.userName?.trim() ?? '';
    final String rawEmail = widget.userEmail.trim();
    final String displayName =
        rawName.isNotEmpty
            ? rawName
            : (rawEmail.isNotEmpty ? rawEmail : 'User');
    final String avatarInitial =
        displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : '?';

    final String? userImageUrl = widget.userImage?.trim();
    final bool hasValidImage =
        userImageUrl != null &&
        userImageUrl.isNotEmpty &&
        userImageUrl != "null" &&
        (userImageUrl.startsWith('http://') ||
            userImageUrl.startsWith('https://'));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'chat_user_avatar_${widget.userId}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue[100],
                backgroundImage:
                    hasValidImage ? NetworkImage(userImageUrl) : null,
                child:
                    !hasValidImage
                        ? Text(
                          avatarInitial,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    rawEmail,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0A192F), // Deep Stadium Blue
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
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'copy_email',
                    child: Row(
                      children: [
                        Icon(
                          Icons.content_copy,
                          color: Color(0xFFFF5722),
                        ), // Action Orange
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
      backgroundColor: const Color(0xFF112240), // Dark Slate Background
      body: SportsBackgroundPattern(
        child: Column(
          children: [
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF5722),
                        ),
                      )
                      : _messages.isEmpty
                      ? const Center(
                        child: Text(
                          'No messages yet.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        physics: const SmoothSlowScrollPhysics(),
                        cacheExtent: 500,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];

                          final String role =
                              (msg['senderRole'] ??
                                      msg['role'] ??
                                      msg['sender_role'] ??
                                      msg['type'] ??
                                      msg['sender_type'] ??
                                      '')
                                  .toString()
                                  .toLowerCase();
                          final bool isAdmin =
                              role == 'admin' ||
                              msg['isAdmin'] == true ||
                              msg['is_admin'] == true ||
                              msg['admin'] == true ||
                              msg['is_staff'] == true;

                          final String text = sanitizeUtf16(
                            msg['message'] ?? '',
                          );

                          final String? rawVoiceNoteUrl =
                              msg['voiceNoteUrl'] ??
                              msg['voice_note_url'] ??
                              msg['voiceNote'];
                          final String? voiceNoteUrl =
                              rawVoiceNoteUrl != null &&
                                      rawVoiceNoteUrl.isNotEmpty
                                  ? ApiService.resolveUrl(rawVoiceNoteUrl)
                                  : null;

                          final String? rawImageUrl = msg['imageUrl'];
                          final List<String> imageUrls =
                              rawImageUrl != null && rawImageUrl.isNotEmpty
                                  ? rawImageUrl
                                      .split(',')
                                      .map(
                                        (u) => ApiService.resolveUrl(u.trim()),
                                      )
                                      .where((u) => u.isNotEmpty)
                                      .toList()
                                  : [];

                          final dynamic rawCreatedAt =
                              msg['createdAt'] ??
                              msg['timestamp'] ??
                              msg['time'];

                          String formattedTime = '';
                          if (rawCreatedAt != null) {
                            try {
                              DateTime date;
                              if (rawCreatedAt is String) {
                                String formatted = rawCreatedAt;
                                if (!formatted.contains('T')) {
                                  formatted = formatted.replaceFirst(' ', 'T');
                                }
                                if (!formatted.endsWith('Z') &&
                                    !formatted.contains('+')) {
                                  formatted += 'Z';
                                }
                                date = DateTime.parse(formatted).toLocal();
                              } else if (rawCreatedAt is int) {
                                date = DateTime.fromMillisecondsSinceEpoch(
                                  rawCreatedAt,
                                );
                              } else {
                                date = DateTime.now();
                              }

                              formattedTime = DateFormat(
                                'hh:mm a',
                              ).format(date);
                            } catch (e) {
                              formattedTime = '';
                            }
                          }

                          final String? replyToId = msg['replyToId'];
                          final String? replyToText =
                              msg['replyToText'] != null
                                  ? sanitizeUtf16(msg['replyToText'])
                                  : null;
                          final String? replyToSenderRole =
                              msg['replyToSenderRole'];
                          final bool isHighlighted =
                              _highlightedMessageId == msg['id'];

                          return RepaintBoundary(
                            child: Dismissible(
                              key: Key('admin_msg_${msg['id'] ?? ''}_$index'),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (direction) async {
                                setState(() {
                                  _replyingToMessage = msg;
                                });
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                color: Colors.transparent,
                                child: const Icon(
                                  Icons.reply,
                                  color: Color(0xFF39FF14),
                                ), // Neon Green
                              ),
                              child: Align(
                                alignment:
                                    isAdmin
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment:
                                      isAdmin
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        isAdmin
                                            ? 'Admin'
                                            : (widget.userName ?? 'User'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isAdmin
                                                  ? const Color(0xFF39FF14)
                                                  : Colors
                                                      .white70, // Neon Green or white70
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onLongPress: () {
                                        final String textToCopy =
                                            text.isNotEmpty
                                                ? text
                                                : (imageUrls.isNotEmpty
                                                    ? "Image"
                                                    : (voiceNoteUrl != null
                                                        ? "Voice Note"
                                                        : ""));
                                        if (textToCopy.isNotEmpty) {
                                          FlutterClipboard.copy(textToCopy);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Message copied to clipboard',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isHighlighted
                                                  ? const Color(
                                                    0xFF39FF14,
                                                  ) // Neon Green highlight
                                                  : (isAdmin
                                                      ? const Color(0xFFFF5722)
                                                      : const Color(
                                                        0xFF1E2D4A,
                                                      )), // Action Orange for admin, deep slate for user
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ).copyWith(
                                            bottomRight:
                                                isAdmin
                                                    ? const Radius.circular(2)
                                                    : const Radius.circular(16),
                                            bottomLeft:
                                                isAdmin
                                                    ? const Radius.circular(16)
                                                    : const Radius.circular(2),
                                          ),
                                          boxShadow:
                                              isHighlighted
                                                  ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF39FF14,
                                                      ).withValues(alpha: 0.6),
                                                      blurRadius: 10,
                                                      spreadRadius: 2,
                                                    ),
                                                  ]
                                                  : null,
                                          border:
                                              isAdmin
                                                  ? null
                                                  : Border.all(
                                                    color: Colors.white12,
                                                  ),
                                        ),
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.75,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (replyToText != null &&
                                                replyToText.isNotEmpty)
                                              GestureDetector(
                                                onTap: () {
                                                  if (replyToId != null &&
                                                      replyToId.isNotEmpty) {
                                                    _scrollToAndHighlightMessage(
                                                      replyToId,
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isAdmin
                                                            ? const Color(
                                                              0xFFE64A19,
                                                            )
                                                            : const Color(
                                                              0xFF112240,
                                                            ), // Darker orange or slate
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border(
                                                      left: BorderSide(
                                                        color:
                                                            isAdmin
                                                                ? Colors.white
                                                                : const Color(
                                                                  0xFFFF5722,
                                                                ),
                                                        width: 3.5,
                                                      ),
                                                    ),
                                                  ),
                                                  child: _buildReplyContent(
                                                    replyToText,
                                                    replyToSenderRole,
                                                    isAdmin,
                                                  ),
                                                ),
                                              ),
                                            if (voiceNoteUrl != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8.0,
                                                ),
                                                child: Container(
                                                  width: 220,
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isAdmin
                                                            ? const Color(
                                                              0xFFE64A19,
                                                            )
                                                            : const Color(
                                                              0xFF112240,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: VoiceNotePlayer(
                                                    url: voiceNoteUrl,
                                                    activeColor: Colors.white,
                                                    iconColor:
                                                        isAdmin
                                                            ? const Color(
                                                              0xFFFF5722,
                                                            )
                                                            : Colors.white,
                                                    textColor: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            if (imageUrls.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8.0,
                                                ),
                                                child: Column(
                                                  children:
                                                      imageUrls.map((img) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom: 4.0,
                                                              ),
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            child: CachedNetworkImage(
                                                              imageUrl: img,
                                                              placeholder:
                                                                  (
                                                                    context,
                                                                    url,
                                                                  ) => const SizedBox(
                                                                    height: 150,
                                                                    width: 150,
                                                                    child: Center(
                                                                      child:
                                                                          CircularProgressIndicator(),
                                                                    ),
                                                                  ),
                                                              errorWidget:
                                                                  (
                                                                    context,
                                                                    url,
                                                                    error,
                                                                  ) => const Icon(
                                                                    Icons.error,
                                                                  ),
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                ),
                                              ),
                                            if (text.isNotEmpty &&
                                                text != "Voice Note" &&
                                                text != "Image")
                                              Text(
                                                text,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formattedTime,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                if (isAdmin) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.done_all,
                                                    size: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _socketService.isTyping,
              builder: (context, isTyping, child) {
                return isTyping
                    ? const TypingIndicator()
                    : const SizedBox.shrink();
              },
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToMessage != null)
            Builder(
              builder: (context) {
                String snippetText = _getReplySnippet(_replyingToMessage!);
                String? imgUrl =
                    _replyingToMessage!['imageUrl'] ??
                    _replyingToMessage!['image'] ??
                    _replyingToMessage!['img_url'];

                if (snippetText.startsWith("[IMAGE]:")) {
                  final parts = snippetText.substring(8).split('|');
                  imgUrl ??= parts[0];
                  snippetText = parts.length > 1 ? parts[1] : "Photo";
                }

                final String? fullImgUrl =
                    (imgUrl != null && imgUrl.isNotEmpty)
                        ? ApiService.resolveUrl(imgUrl.split(',').first.trim())
                        : null;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D4A), // Deep Slate
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                      left: BorderSide(
                        color: const Color(0xFF39FF14),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (fullImgUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: fullImgUrl,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorWidget:
                                (context, url, error) =>
                                    const Icon(Icons.image, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _replyingToMessage!['senderRole'] == 'admin'
                                  ? 'Replying to Yourself'
                                  : 'Replying to ${widget.userName ?? widget.userEmail}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF39FF14),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              snippetText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed:
                            () => setState(() => _replyingToMessage = null),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.red[50],
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Recording... ${_formatTimer(_recordDuration)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _cancelVoiceNote,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.stop_circle,
                      color: Colors.red,
                      size: 28,
                    ),
                    onPressed: _stopRecording,
                  ),
                ],
              ),
            )
          else if (_selectedVoiceNote != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2D4A),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: VoiceNotePlayer(
                      url: _selectedVoiceNote!.path,
                      isLocal: true,
                      activeColor: const Color(0xFFFF5722),
                      iconColor: Colors.white,
                      textColor: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _cancelVoiceNote,
                  ),
                ],
              ),
            )
          else if (_selectedImages.isNotEmpty)
            Container(
              height: 90,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2D4A),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imgFile = _selectedImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          imgFile,
                          height: 75,
                          width: 75,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A192F), // Deep Stadium Blue
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.image,
                    color: Color(0xFF39FF14),
                  ), // Neon Green
                  onPressed: _pickImages,
                ),
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : const Color(0xFF39FF14),
                  ),
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    maxLines: null,
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _socketService.sendTyping();
                      } else {
                        _socketService.sendStopTyping();
                      }
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                AnimatedScale(
                  scale: _isSending ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child:
                      _isSending
                          ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF5722),
                              ),
                            ),
                          )
                          : IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Color(0xFFFF5722),
                            ), // Action Orange
                            onPressed: _sendMessage,
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
