import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/chat_model.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<UserProvider>().currentUser;

    if (user == null) return const SizedBox();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.darkGradient : null,
          color: isDark ? null : AppColors.lightBg,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.neonGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chat_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // For patients: show "Chat with your Doctor" button if assigned
              if (user.isPatient && user.assignedDoctorId != null && user.assignedDoctorId!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DoctorChatButton(
                    currentUserId: user.uid,
                    currentUserName: user.name,
                    doctorId: user.assignedDoctorId!,
                  ),
                ),

              // Chat rooms
              Expanded(
                child: StreamBuilder<List<ChatRoom>>(
                  stream: ChatService().chatRoomsStream(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rooms = snapshot.data ?? [];

                    if (rooms.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 64,
                              color: AppColors.textMuted.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.isDoctor
                                  ? 'Start a chat from the patients tab'
                                  : user.assignedDoctorId != null
                                      ? 'Tap the button above to chat with your doctor'
                                      : 'Ask your doctor to add you as a patient',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return _ChatRoomTile(
                          room: room,
                          currentUserId: user.uid,
                          currentUserName: user.name,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Doctor Chat Button (for patients) ──────────────────────────────

class _DoctorChatButton extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String doctorId;

  const _DoctorChatButton({
    required this.currentUserId,
    required this.currentUserName,
    required this.doctorId,
  });

  @override
  State<_DoctorChatButton> createState() => _DoctorChatButtonState();
}

class _DoctorChatButtonState extends State<_DoctorChatButton> {
  String _doctorName = 'Your Doctor';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorName();
  }

  Future<void> _loadDoctorName() async {
    final info = await ChatService().getUserInfo(widget.doctorId);
    if (mounted && info != null) {
      setState(() {
        _doctorName = 'Dr. ${info['name'] ?? 'Doctor'}';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final chatService = ChatService();
        final chatRoomId = await chatService.getOrCreateChatRoom(
          widget.currentUserId,
          widget.doctorId,
        );

        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatRoomId: chatRoomId,
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
              otherUserName: _doctorName,
              otherUserId: widget.doctorId,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading ? 'Loading...' : _doctorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to chat with your doctor',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chat_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Room Tile ─────────────────────────────────────────────────

class _ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final String currentUserId;
  final String currentUserName;

  const _ChatRoomTile({
    required this.room,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherUserId = room.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    return FutureBuilder<Map<String, dynamic>?>(
      future: ChatService().getUserInfo(otherUserId),
      builder: (context, snapshot) {
        final otherName = snapshot.data?['name']?.toString() ?? 'User';
        final otherRole = snapshot.data?['role']?.toString() ?? '';
        final displayName = otherRole == 'doctor' ? 'Dr. $otherName' : otherName;
        final isFromMe = room.lastSenderId == currentUserId;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatRoomId: room.id,
                  currentUserId: currentUserId,
                  currentUserName: currentUserName,
                  otherUserName: displayName,
                  otherUserId: otherUserId,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.cardGradient : null,
              color: isDark ? null : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room.lastMessage.isEmpty
                            ? 'No messages yet'
                            : '${isFromMe ? "You: " : ""}${room.lastMessage}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(room.lastMessageTime),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return DateFormat('h:mm a').format(time);
    }
    return DateFormat('MMM d').format(time);
  }
}
