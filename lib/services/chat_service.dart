import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import 'cloudinary_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  /// Generate a consistent chat room ID from two user IDs
  String getChatRoomId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get or create a chat room between two users
  Future<String> getOrCreateChatRoom(String userId1, String userId2) async {
    final chatRoomId = getChatRoomId(userId1, userId2);
    
    final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
    if (!doc.exists) {
      await _firestore.collection('chatRooms').doc(chatRoomId).set({
        'id': chatRoomId,
        'participants': [userId1, userId2],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
      });
    }
    
    return chatRoomId;
  }

  /// Stream of messages in a chat room (real-time)
  Stream<List<ChatMessage>> messagesStream(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data()))
            .toList());
  }

  /// Send a message
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String text,
  }) async {
    try {
      final messageId = const Uuid().v4();
      final message = ChatMessage(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        text: text,
        timestamp: DateTime.now(),
      );

      // Add message to sub-collection
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson());

      // Update chat room with last message
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Send an image message (via Cloudinary)
  Future<void> sendImageMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String receiverId,
    required File imageFile,
  }) async {
    try {
      final messageId = const Uuid().v4();

      // Upload to Cloudinary
      final imageUrl = await _cloudinary.uploadImage(
        imageFile,
        folder: 'medicine_app/chat_images',
      );

      final message = ChatMessage(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        text: '',
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        messageType: 'image',
      );

      // Add message
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson());

      // Update chat room
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      });

      debugPrint('[Chat] Image sent: $imageUrl');
    } catch (e) {
      debugPrint('Error sending image: $e');
      rethrow;
    }
  }

  /// Get all chat rooms for a user
  Stream<List<ChatRoom>> chatRoomsStream(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromJson(doc.data()))
            .toList());
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatRoomId, String currentUserId) async {
    try {
      final unread = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Get unread message count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      // Get all chat rooms for this user
      final rooms = await _firestore
          .collection('chatRooms')
          .where('participants', arrayContains: userId)
          .get();

      int total = 0;
      for (final room in rooms.docs) {
        final unread = await _firestore
            .collection('chatRooms')
            .doc(room.id)
            .collection('messages')
            .where('receiverId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .count()
            .get();
        total += unread.count ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get the other participant's info
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }
}
