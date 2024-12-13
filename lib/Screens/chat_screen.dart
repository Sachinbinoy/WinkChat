import 'dart:io';
import 'package:chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final User currentUser;
  final String recipientId;
  final String recipientName;
  final String? recipientProfilePictureUrl; // Add this
  final VoidCallback onMessagesRead;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.recipientId,
    required this.recipientName,
    required this.onMessagesRead,
    this.recipientProfilePictureUrl,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late String chatRoomId;

  @override
  void initState() {
    super.initState();
    chatRoomId = _getChatRoomId(widget.currentUser.uid, widget.recipientId);
    _markMessagesAsRead();
    // _fetchRecipientProfilePicture(); 
  }

  // Helper to create chat room ID based on user IDs
  String _getChatRoomId(String userId, String otherUserId) {
    return userId.hashCode <= otherUserId.hashCode
        ? '${userId}_$otherUserId'
        : '${otherUserId}_$userId';
  }

  // Fetch the recipient's profile picture URL or file path
  // Future<void> _fetchRecipientProfilePicture() async {
  //   final doc = await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(widget.recipientId)
  //       .get();

  //   if (doc.exists) {
  //     if (kDebugMode) {
  //       print("profile_picture==${doc['profile_picture']}");
  //     }
  //     setState(() {
  //       recipientProfilePictureUrl = doc['profile_picture'];
  //     });
  //   }
  // }

  // Mark all messages from the recipient as read
  Future<void> _markMessagesAsRead() async {
    final unreadMessages = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.recipientId)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in unreadMessages.docs) {
      doc.reference.update({'read': true});
    }

    // Call the callback to update unread count in HomePage
    widget.onMessagesRead();
  }

  // Send a message
  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': _messageController.text,
        'senderId': widget.currentUser.uid,
        'recipientId': widget.recipientId,
        'timestamp': FieldValue.serverTimestamp(), // Ensure server timestamp
        'read': false,
      });
      _messageController.clear();
    }
  }

  // Function to format the timestamp with null check
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return ''; // Return empty if timestamp is null
    }

    try {
      final DateTime dateTime = timestamp.toDate(); // Convert to DateTime
      final DateFormat dateFormat = DateFormat('dd-MM-yyyy');
      final DateFormat timeFormat = DateFormat('hh:mm a');
      return '${dateFormat.format(dateTime)} | ${timeFormat.format(dateTime)}';
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting timestamp: $e');
      }
      return ''; // Return empty string in case of error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0), // AppBar height
        child: AppBar(
          backgroundColor: White, // Soft background color
          elevation: 0, // No shadow for a clean look
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
            ),
          ),
          title: Row(
            children: [
              // Profile Picture
              CircleAvatar(
                backgroundImage: widget.recipientProfilePictureUrl != null
                    ? FileImage(File(widget.recipientProfilePictureUrl!))
                    : null,
                radius: 15,
                child: widget.recipientProfilePictureUrl == null
                    ? Text(
                        widget.recipientName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          color: Grey,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8), // Space between avatar and name
              // Recipient Name
              Text(
                widget.recipientName,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: Black,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: PrimaryBlue),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Container(
        color: White,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chatRooms')
                    .doc(chatRoomId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // If the stream is still waiting for data, show the loading spinner
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    // If no data or documents exist, stop loading and show a message
                    return const Center(child: Text("No messages yet"));
                  }

                  // If there is data, show the list of messages
                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    reverse: true, // to show the most recent message at the bottom
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isSentByCurrentUser =
                          message['senderId'] == widget.currentUser.uid;
                      final timestamp = message['timestamp'] as Timestamp?;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Align(
                          alignment: isSentByCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isSentByCurrentUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 15.0),
                                decoration: BoxDecoration(
                                  color: isSentByCurrentUser
                                      ? PrimaryBlue
                                      : LightGrey,
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                child: Text(
                                  message['text'],
                                  style: TextStyle(
                                    color: isSentByCurrentUser
                                        ? White
                                        : Black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 5.0, right: 5.0),
                                child: Text(
                                  _formatTimestamp(timestamp),
                                  style:  TextStyle(
                                    color: Black,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: White,
                        borderRadius: BorderRadius.circular(30.0),
                        boxShadow: [
                          BoxShadow(
                            color: Grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Send a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Grey),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SecondaryBlue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SecondaryBlue.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.send,
                        color: White,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
