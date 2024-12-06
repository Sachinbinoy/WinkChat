import 'dart:io';
import 'package:chat_app/Screens/userDetails_screen.dart';
import 'package:chat_app/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}


class _HomePageState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _profilePictureUrl;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

@override
  void initState() {
    super.initState();
    _fetchProfilePicture();
  }

  Future<void> _fetchProfilePicture() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final uid = currentUser.uid;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _profilePictureUrl = userDoc.data()?['profile_picture'];
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching profile picture: $e');
        }
      }
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Stream<QuerySnapshot> _getUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: _searchText)
        .where('name', isLessThanOrEqualTo: '$_searchText\uf8ff')
        .snapshots();
  }

  Future<int> _getUnreadMessagesCount(String recipientId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    final chatRoomId = _getChatRoomId(currentUserId, recipientId);
    final unreadMessages = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: recipientId)
        .where('read', isEqualTo: false)
        .get();

    return unreadMessages.size;
  }

  String _getChatRoomId(String userId, String otherUserId) {
    return userId.hashCode <= otherUserId.hashCode
        ? '${userId}_$otherUserId'
        : '${otherUserId}_$userId';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day &&
        time.month == now.month &&
        time.year == now.year) {
      return DateFormat('hh:mm a').format(time);
    } else if (time.year == now.year) {
      return 'Yesterday';
    }
    return DateFormat('MM/dd/yy').format(time);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: White,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: White,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
            ),
          ),
          leading: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UserDetailsPage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: LightGrey,
                backgroundImage: _profilePictureUrl != null
                    ? FileImage(File(_profilePictureUrl!))
                    : null,
                child: _profilePictureUrl == null
                    ?  Icon(Icons.person, color: Grey)
                    : null,
              ),
            ),
          ),
          title:  Text(
            'Wing Chat',
            style: TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.w600,
              color:PrimaryBlue,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon:  Icon(Icons.logout, color:SecondaryBlue),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search message...',
                hintStyle: TextStyle(color: Grey, fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: Grey, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 11),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No conversations yet'));
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData =
                        users[index].data() as Map<String, dynamic>;
                    if (userData['uid'] == _auth.currentUser?.uid) {
                      return const SizedBox.shrink();
                    }

                    return FutureBuilder<int>(
                      future: _getUnreadMessagesCount(userData['uid']),
                      builder: (context, unreadSnapshot) {
                        final unreadCount = unreadSnapshot.data ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    currentUser: _auth.currentUser,
                                    recipientId: userData['uid'],
                                    recipientName: userData['name'],
                                    onMessagesRead: () => setState(() {}),
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                // Profile Picture
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: LightGrey,
                                  backgroundImage:
                                      userData['profile_picture'] != null
                                          ? FileImage(
                                              File(userData['profile_picture']))
                                          : null,
                                  child: userData['photprofile_pictureoUrl'] !=
                                          null
                                      ? Text(
                                          userData['name']?[0].toUpperCase() ??
                                              '?',
                                          style:  TextStyle(
                                            fontSize: 20,
                                            color: Grey,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Message Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                userData['name'] ?? 'No Name',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                userData["phone"],
                                                style: TextStyle(
                                                  color: Grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                _formatTime(DateTime.now()),
                                                style: TextStyle(
                                                  color: Grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (unreadCount > 0)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration:
                                                       BoxDecoration(
                                                    color:SecondaryBlue,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    '$unreadCount',
                                                    style:  TextStyle(
                                                      color: White,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
