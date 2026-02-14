import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final String messageType; // 'text' or 'image'

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.messageType = 'text',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
    'isRead': isRead,
    'imageUrl': imageUrl,
    'messageType': messageType,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    final ts = json['timestamp'];
    if (ts is Timestamp) {
      parsedTime = ts.toDate();
    } else if (ts is String) {
      parsedTime = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      timestamp: parsedTime,
      isRead: json['isRead'] ?? false,
      imageUrl: json['imageUrl']?.toString(),
      messageType: json['messageType']?.toString() ?? 'text',
    );
  }
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    final ts = json['lastMessageTime'];
    if (ts is Timestamp) {
      parsedTime = ts.toDate();
    } else {
      parsedTime = DateTime.now();
    }

    return ChatRoom(
      id: json['id']?.toString() ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: parsedTime,
      lastSenderId: json['lastSenderId']?.toString() ?? '',
    );
  }
}
