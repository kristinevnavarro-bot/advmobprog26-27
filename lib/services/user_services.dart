import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/user_model.dart';
import '../models/login_type.dart';

ValueNotifier<UserService> userService = ValueNotifier(UserService());

class UserService {
  Map<String, dynamic> data = {};

  final fb_auth.FirebaseAuth firebaseAuth = fb_auth.FirebaseAuth.instance;

  fb_auth.User? get currentFirebaseUser => firebaseAuth.currentUser;

  Stream<fb_auth.User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<fb_auth.UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _syncUserToFirestore();
    return credential;
  }

  // Chat (ChatService.getUsersStream/getUidbyEmail) reads user docs from the
  // "Users" collection, keyed by uid - nothing else writes that doc, so both
  // sign-up and sign-in upsert it here to keep it in sync. Best-effort: a
  // Firestore failure here (e.g. rules not published yet) must never break
  // sign-in/sign-up, since Firebase Auth itself already succeeded by the time
  // this runs.
  Future<void> _syncUserToFirestore({
    String? firstName,
    String? lastName,
  }) async {
    final user = currentFirebaseUser;
    if (user == null) return;
    try {
      final profile = await getFirebaseProfileData();
      final resolvedFirstName = firstName ?? profile['fName'] as String?;
      final resolvedLastName = lastName ?? profile['lName'] as String?;
      // logoutUser() clears local prefs (including the cached fb_fName/
      // fb_lName), so a later sign-in can resolve blank names here even
      // though Firestore may already have the real ones. Only write
      // firstName/lastName when we actually have a value, so a blank local
      // cache can never clobber good data already stored in Firestore.
      final data = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? profile['email'],
        if (resolvedFirstName != null && resolvedFirstName.isNotEmpty)
          'firstName': resolvedFirstName,
        if (resolvedLastName != null && resolvedLastName.isNotEmpty)
          'lastName': resolvedLastName,
      };
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
      print('Firestore user sync failed (non-fatal): $e');
    }
  }

  Future<fb_auth.UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  Future<void> updateUsername({required String username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fb_username', username);
    try {
      await currentFirebaseUser!.updateDisplayName(username);
    } catch (_) {
      // firebase_auth's updateDisplayName reloads the user afterwards, which
      // can throw a PigeonUserDetails cast error on some plugin versions even
      // though the update itself succeeded. The username above is already
      // saved and is what getFirebaseProfileData()/the profile screen reads,
      // so this is safe to ignore.
    }
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    fb_auth.AuthCredential credential = fb_auth.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await currentFirebaseUser!.reauthenticateWithCredential(credential);
    await currentFirebaseUser!.delete();
    await firebaseAuth.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    fb_auth.AuthCredential credential = fb_auth.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await currentFirebaseUser!.reauthenticateWithCredential(credential);
    await currentFirebaseUser!.updatePassword(newPassword);
  }

  Future<Map<String, dynamic>> loginUser(
    String username,
    String password,
  ) async {
    // TEMP DEBUG - remove after diagnosing the "Invalid credentials" issue.
    // ignore: avoid_print
    print('LOGIN DEBUG host=$host username="$username" password="$password"');
    final response = await http.post(
      Uri.parse('$host/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'expiresInMins': 60,
      }),
    );
    // ignore: avoid_print
    print('LOGIN DEBUG status=${response.statusCode} body=${response.body}');

    if (response.statusCode == 200) {
      data = jsonDecode(response.body);
      await saveUserData(data);
      return data;
    } else {
      throw Exception(response.body);
    }
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(userData));

    final user = User.fromJson(userData);
    await prefs.setInt('id', user.id);
    await prefs.setString('username', user.username);
    await prefs.setString('email', user.email);
    await prefs.setString('firstName', user.firstName);
    await prefs.setString('lastName', user.lastName);
    await prefs.setString('gender', user.gender);
    await prefs.setString('image', user.image);
    await prefs.setString('accesstoken', user.accessToken);
    await prefs.setString('refreshtoken', user.refreshToken);

    if (userData.containsKey('token')) {
      await prefs.setString('token', userData['token'] ?? '');
    } else if (user.accessToken.isNotEmpty) {
      await prefs.setString('token', user.accessToken);
    }
  }

  // On Flutter Web (and right after a hot restart), the Firebase JS SDK
  // restores the persisted session asynchronously, so currentUser can still
  // read null for a moment even when the user is genuinely signed in. Wait
  // for authStateChanges to settle instead of trusting a synchronous snapshot.
  Future<fb_auth.User?> _resolveFirebaseUser() async {
    final current = currentFirebaseUser;
    if (current != null) return current;
    try {
      return await firebaseAuth.authStateChanges().first.timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUser = await _resolveFirebaseUser();

    return {
      'id': prefs.getInt('id') ?? 0,
      'uid': firebaseUser?.uid ?? '',
      'username': prefs.getString('username') ?? '',
      'email': prefs.getString('email') ?? firebaseUser?.email ?? '',
      'firstName': prefs.getString('firstName') ?? '',
      'lastName': prefs.getString('lastName') ?? '',
      'gender': prefs.getString('gender') ?? '',
      'image': prefs.getString('image') ?? '',
      'accessToken': prefs.getString('accesstoken') ?? '',
      'refreshToken': prefs.getString('refreshtoken') ?? '',
      'token': prefs.getString('token') ?? '',
    };
  }

  Future<User> getUser() async {
    final userData = await getUserData();
    return User.fromJson(userData);
  }

  // Lab 4 - Enhancement 3: resolves the id of the signed-in user (falling
  // back to constants.currentUserId if nobody is signed in yet) so the cart
  // screens can render /carts/user/{id} for whoever is actually logged in
  // instead of a hardcoded id.
  Future<int> getCurrentUserId() async {
    final userData = await getUserData();
    final id = userData['id'] as int?;
    return (id != null && id != 0) ? id : currentUserId;
  }

  Future<bool> isLoggedIn() async {
    final loginType = await getLoginType();
    if (loginType == LoginType.firebase) {
      return currentFirebaseUser != null;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token') && prefs.getString('token')!.isNotEmpty;
  }

  Future<void> logoutUser() async {
    try {
      await firebaseAuth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> setLoginType(LoginType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loginType', type.name);
  }

  Future<LoginType> getLoginType() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('loginType');
    return LoginType.values.firstWhere(
      (type) => type.name == stored,
      orElse: () => LoginType.dummyJson,
    );
  }

  Future<void> saveFirebaseProfile({
    required String fName,
    required String lName,
    required int age,
    required String contactNo,
    required String username,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fb_fName', fName);
    await prefs.setString('fb_lName', lName);
    await prefs.setInt('fb_age', age);
    await prefs.setString('fb_contactNo', contactNo);
    await prefs.setString('fb_username', username);
    await prefs.setString('fb_email', email);
    await setLoginType(LoginType.firebase);
    await _syncUserToFirestore(firstName: fName, lastName: lName);
  }

  Future<Map<String, dynamic>> getFirebaseProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'fName': prefs.getString('fb_fName') ?? '',
      'lName': prefs.getString('fb_lName') ?? '',
      'age': prefs.getInt('fb_age') ?? 0,
      'contactNo': prefs.getString('fb_contactNo') ?? '',
      'username':
          prefs.getString('fb_username') ??
          currentFirebaseUser?.displayName ??
          '',
      'email': prefs.getString('fb_email') ?? currentFirebaseUser?.email ?? '',
    };
  }
}
