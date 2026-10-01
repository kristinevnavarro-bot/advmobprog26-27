import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/chat_service.dart';
import '../services/user_services.dart';
import '../widgets/custom_text.dart';

final ChatService chatService = ChatService();

class ChatDetailScreen extends StatefulWidget {
  final String currentUserEmail;
  final Map<String, dynamic> tappedUser;

  const ChatDetailScreen({
    super.key,
    required this.currentUserEmail,
    required this.tappedUser,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late Future<String> _currentUserIdFuture;
  StreamSubscription<QuerySnapshot>? _seenSub;

  bool _isSending = false;
  Timestamp? _sendingStartedAt;
  String? _pendingText;

  static const _postSendDelay = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _currentUserIdFuture = _getCurrentUserId();
    _currentUserIdFuture.then(_watchForSeenUpdates);
  }

  Future<String> _getCurrentUserId() async {
    final userData = await userService.value.getUserData();
    return (userData['uid'] ?? '').toString();
  }

  void _watchForSeenUpdates(String currentUserId) {
    if (currentUserId.isEmpty) return;
    final tappedUserId = (widget.tappedUser['uid'] ?? '').toString();
    _seenSub = chatService
        .getMessage(currentUserId, tappedUserId)
        .listen(
          (_) => chatService.markMessagesSeen(currentUserId, tappedUserId),
        );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.dispose();
    _seenSub?.cancel();
    super.dispose();
  }

  Future<void> _send(String currentUserId, String receiverId) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _sendingStartedAt = Timestamp.now();
      _pendingText = text;
    });
    _msgCtrl.clear();

    try {
      await chatService.sendMessage(receiverId, text);
      _msgFocus.requestFocus();

      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      await Future.delayed(_postSendDelay);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendingStartedAt = null;
          _pendingText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tappedUserId = (widget.tappedUser['uid'] ?? '').toString();
    final tappedUserName = ChatService.fieldCI(widget.tappedUser, 'firstName');

    return FutureBuilder<String>(
      future: _currentUserIdFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Error loading user data')),
          );
        }

        final currentUserId = snap.data!;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            centerTitle: true,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: CustomText(
                    text: tappedUserName.isNotEmpty
                        ? tappedUserName[0].toUpperCase()
                        : '?',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8.w),
                CustomText(
                  text: tappedUserName,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Messages
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: chatService.getMessage(currentUserId, tappedUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading messages: ${snapshot.error}',
                        ),
                      );
                    }

                    List<QueryDocumentSnapshot> docs =
                        snapshot.data?.docs ?? [];

                    // hide the real doc for my just-sent message; the
                    // pending bubble below stands in for it until it lands
                    if (_isSending && _sendingStartedAt != null) {
                      docs = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final senderId = (data['senderId'] ?? '').toString();
                        final ts = data['timestamp'];
                        if (senderId != currentUserId) return true;
                        if (ts is Timestamp) {
                          return ts.compareTo(_sendingStartedAt!) < 0;
                        }
                        return true;
                      }).toList();
                    }

                    final showPending =
                        _isSending &&
                        _pendingText != null &&
                        _pendingText!.isNotEmpty;
                    final pendingOffset = showPending ? 1 : 0;
                    final itemCount = docs.length + pendingOffset;

                    if (itemCount == 0) {
                      return const Center(child: Text('No messages yet'));
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (showPending && index == 0) {
                          return _AnimatedMessageEntry(
                            key: const ValueKey('pending'),
                            child: _MessageBubble(
                              text: _pendingText!,
                              isMe: true,
                              status: _MessageStatus.sending,
                            ),
                          );
                        }

                        final doc = docs[index - pendingOffset];
                        final data = doc.data() as Map<String, dynamic>;
                        final msgText = (data['message'] ?? '').toString();
                        final senderId = (data['senderId'] ?? '').toString();
                        final isMe = senderId == currentUserId;
                        final seen = data['seen'] == true;
                        final timestamp = data['timestamp'];

                        return _AnimatedMessageEntry(
                          key: ValueKey(doc.id),
                          child: _MessageBubble(
                            text: msgText.isNotEmpty ? msgText : '[empty]',
                            isMe: isMe,
                            status: isMe
                                ? (seen
                                      ? _MessageStatus.seen
                                      : _MessageStatus.delivered)
                                : null,
                            timestamp: timestamp is Timestamp
                                ? timestamp
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Composer
              SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          focusNode: _msgFocus,
                          enabled: !_isSending,
                          textInputAction: TextInputAction.send,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => !_isSending
                              ? _send(currentUserId, tappedUserId)
                              : null,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(fontFamily: 'Poppins'),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _isSending
                            ? const SizedBox(
                                key: ValueKey('sending'),
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : CircleAvatar(
                                key: const ValueKey('send'),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _send(currentUserId, tappedUserId),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _MessageStatus { sending, delivered, seen }

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final _MessageStatus? status;
  final Timestamp? timestamp;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    this.status,
    this.timestamp,
  });

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              text: text,
              fontSize: 15.sp,
              fontWeight: FontWeight.normal,
              textAlign: TextAlign.left,
              fontFamily: 'Poppins',
            ),
            if (status != null || timestamp != null) ...[
              SizedBox(height: 4.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (timestamp != null)
                    CustomText(
                      text: _formatTime(timestamp!),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w300,
                    ),
                  if (status != null) ...[
                    SizedBox(width: 4.w),
                    _StatusIcon(status: status!),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final _MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: Colors.white70);
      case _MessageStatus.delivered:
        return const Icon(Icons.done, size: 14, color: Colors.white70);
      case _MessageStatus.seen:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Colors.lightBlueAccent,
        );
    }
  }
}

/// Fades and slides a newly-inserted message into place. Keyed by message
/// id so it only animates once, the first time that message appears.
class _AnimatedMessageEntry extends StatefulWidget {
  final Widget child;
  const _AnimatedMessageEntry({super.key, required this.child});

  @override
  State<_AnimatedMessageEntry> createState() => _AnimatedMessageEntryState();
}

class _AnimatedMessageEntryState extends State<_AnimatedMessageEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
