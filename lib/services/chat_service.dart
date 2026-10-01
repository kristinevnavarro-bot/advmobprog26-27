import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:navarro_advmobprog/models/message.dart';

class ChatService {
  final firebaseFirestore = FirebaseFirestore.instance;
  final firebaseAuth = FirebaseAuth.instance;

  // Firestore field names are case-sensitive, and user docs entered by hand
  // in the console (vs written by the app itself) have shown up with
  // inconsistent casing (Firstname, firstname, ...). Look keys up
  // case-insensitively so a casing typo doesn't silently show as "Unknown".
  static String fieldCI(Map<String, dynamic> data, String key) {
    if (data[key] != null) return data[key].toString();
    final lowerKey = key.toLowerCase();
    for (final entry in data.entries) {
      if (entry.value != null && entry.key.toLowerCase() == lowerKey) {
        return entry.value.toString();
      }
    }
    return '';
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return firebaseFirestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // go through each individual user
        final user = doc.data();

        // return user
        return user;
      }).toList();
    });
  }

  Future<void> sendMessage(String receiverId, String message) async {
    final String currentUserId = firebaseAuth.currentUser!.uid;
    final String currentUserEmail = firebaseAuth.currentUser!.email ?? '';
    final Timestamp timestamp = Timestamp.now();
    MessageModel newMessage = MessageModel(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
    );

    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    await firebaseFirestore
        .collection("chat_rooms")
        .doc(chatRoomId)
        .collection("messages")
        .add(newMessage.toMap());
  }

  Stream<QuerySnapshot> getMessage(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join("_");

    return firebaseFirestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> markMessagesSeen(
    String currentUserId,
    String otherUserId,
  ) async {
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    final unseen = await firebaseFirestore
        .collection("chat_rooms")
        .doc(chatRoomId)
        .collection("messages")
        .where('receiverId', isEqualTo: currentUserId)
        .where('seen', isEqualTo: false)
        .get();

    if (unseen.docs.isEmpty) return;

    final batch = firebaseFirestore.batch();
    for (final doc in unseen.docs) {
      batch.update(doc.reference, {'seen': true});
    }
    await batch.commit();
  }

  Future<String?> getUidbyEmail(String email) async {
    final q = await firebaseFirestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return (q.docs.first.data()['uid'] ?? '').toString();
  }
}
