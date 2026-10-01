import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/chat_service.dart';
import '../services/user_services.dart';
import '../widgets/custom_text.dart';
import 'chat_detailscreen.dart';

// Bottom-nav tab 2 (Shop / Chat / Profile). No AppBar of its own - it's used
// as a tab inside HomeScreen, whose own AppBar already shows the "Chats"
// title when this tab is active (same pattern as CartScreen).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchChatController = TextEditingController();
  final ChatService _chatService = ChatService();
  String? _currentUserEmail;
  String _searchText = '';

  static const _avatarColors = [
    Color(0xFF6C63FF),
    Color(0xFFFF6584),
    Color(0xFF43C6AC),
    Color(0xFFFFA26B),
    Color(0xFF4E9BFF),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserEmail();
  }

  Future<void> _loadCurrentUserEmail() async {
    final userData = await userService.value.getUserData();
    setState(() {
      _currentUserEmail = userData['email'];
    });
  }

  @override
  void dispose() {
    _searchChatController.dispose();
    super.dispose();
  }

  Color _avatarColorFor(String seed) {
    if (seed.isEmpty) return _avatarColors.first;
    return _avatarColors[seed.codeUnitAt(0) % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                controller: _searchChatController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: (_searchChatController.text.isNotEmpty)
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.cancel),
                          onPressed: () {
                            setState(() {
                              _searchChatController.clear();
                              _searchText = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chatService.getUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: CustomText(
                          text: 'Error loading users:\n${snapshot.error}',
                          fontSize: 14.sp,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _EmptyState(
                      icon: Icons.people_outline,
                      text: 'No registered users yet',
                    );
                  }

                  // Enhancement 1 & 2: exclude the current user, filter by search text
                  final users = snapshot.data!.where((user) {
                    final isCurrentUser = user['email'] == _currentUserEmail;
                    if (isCurrentUser) return false;
                    if (_searchText.isEmpty) return true;
                    final query = _searchText.toLowerCase();
                    final firstName = ChatService.fieldCI(
                      user,
                      'firstName',
                    ).toLowerCase();
                    final email = (user['email'] ?? '')
                        .toString()
                        .toLowerCase();
                    return firstName.contains(query) || email.contains(query);
                  }).toList();

                  if (users.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off,
                      text: 'No matching users found',
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 4.h,
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final firstName = ChatService.fieldCI(user, 'firstName');
                      final email = (user['email'] ?? 'No email').toString();
                      final initial = firstName.isNotEmpty
                          ? firstName[0].toUpperCase()
                          : '?';

                      return _ChatListEntry(
                        // Staggers each row's fade/slide-in slightly so the
                        // list feels alive on first load instead of popping in.
                        delay: Duration(milliseconds: 30 * index),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatDetailScreen(
                                    currentUserEmail: _currentUserEmail!,
                                    tappedUser: user,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 4.h),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24.r,
                                    backgroundColor: _avatarColorFor(
                                      firstName.isNotEmpty ? firstName : email,
                                    ),
                                    child: CustomText(
                                      text: initial,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 14.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CustomText(
                                          text: firstName.isNotEmpty
                                              ? firstName
                                              : 'Unknown',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        SizedBox(height: 2.h),
                                        CustomText(
                                          text: email,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48.sp, color: Colors.grey.shade400),
          SizedBox(height: 12.h),
          CustomText(text: text, fontSize: 16.sp, fontWeight: FontWeight.w400),
        ],
      ),
    );
  }
}

/// Fades and slides a chat list row into place on first build.
class _ChatListEntry extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _ChatListEntry({required this.child, this.delay = Duration.zero});

  @override
  State<_ChatListEntry> createState() => _ChatListEntryState();
}

class _ChatListEntryState extends State<_ChatListEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

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
