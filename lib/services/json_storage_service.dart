import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class JsonStorageService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _sessionKey = 'active_user_session_id';
  static const String _deviceOwnerKey = 'device_registered_owner_id';

  static CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  // Seed Default Super Admin Account into Firestore on Startup
  static Future<void> seedSuperAdmin() async {
    const superAdminUsername = 'superadmin';
    final query = await _usersCol
        .where('username_lowercase', isEqualTo: superAdminUsername)
        .get();

    if (query.docs.isEmpty) {
      final id = _usersCol.doc().id;
      final superAdmin = User(
        id: id,
        username: 'SuperAdmin',
        role: 'superadmin',
        identity: 'none',
        createdAt: DateTime.now(),
        isApproved: true,
      );
      final json = superAdmin.toJson();
      json['username_lowercase'] = superAdminUsername;
      json['isLoggedIn'] = false;
      await _usersCol.doc(id).set(json);
    }
  }

  // Stream single user in real-time
  static Stream<User?> streamUser(String userId) {
    return _usersCol.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return User.fromJson(doc.data()!);
    });
  }

  // Stream all users in real-time
  static Stream<List<User>> streamAllUsers() {
    return _usersCol.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => User.fromJson(doc.data())).toList();
    });
  }

  static Future<User> authenticateUser(String username, String role) async {
    await seedSuperAdmin();

    final prefs = await SharedPreferences.getInstance();
    final normalizedInput = username.trim().toLowerCase();
    final String? lockedDeviceId = prefs.getString(_deviceOwnerKey);

    final query = await _usersCol
        .where('username_lowercase', isEqualTo: normalizedInput)
        .get();

    // 1. RETURNING USER
    if (query.docs.isNotEmpty) {
      final userDoc = query.docs.first;
      final userData = userDoc.data();
      final existingUser = User.fromJson(userData);

      if (lockedDeviceId != null &&
          lockedDeviceId != existingUser.id &&
          existingUser.role != 'superadmin') {
        throw Exception(
          'This device is locked to another player account.',
        );
      }

      if (existingUser.isTerminated) {
        throw Exception(
          'Your account has been terminated. Contact a Moderator to grant access.',
        );
      }

      // Check Moderator Approval Status
      if (existingUser.role == 'moderator' && !existingUser.isApproved) {
        throw Exception(
          'Moderator registration submitted successfully! Please wait for Super Admin approval before logging in.',
        );
      }

      // ⛔ PREVENT MULTI-DEVICE CONCURRENT LOGINS
      final bool alreadyLoggedIn = userData['isLoggedIn'] ?? false;
      final String? currentActiveSession = prefs.getString(_sessionKey);

      if (alreadyLoggedIn && currentActiveSession != existingUser.id) {
        throw Exception(
          'This account is already logged in on another device. Please log out from that device first.',
        );
      }

      await _usersCol.doc(existingUser.id).update({'isLoggedIn': true});
      await prefs.setString(_deviceOwnerKey, existingUser.id);
      await setSession(existingUser.id);
      return existingUser;
    }

    // 2. NEW USER REGISTRATION
    if (lockedDeviceId != null && role != 'superadmin') {
      final ownerDoc = await _usersCol.doc(lockedDeviceId).get();
      final String ownerName = ownerDoc.exists && ownerDoc.data() != null
          ? (ownerDoc.data()!['username'] ?? 'another account')
          : 'another account';
      throw Exception(
        'This device is already registered to "$ownerName".',
      );
    }

    final newId = _usersCol.doc().id;
    final bool requiresApproval = (role == 'moderator');

    final newUser = User(
      id: newId,
      username: username.trim(),
      role: role,
      identity: 'none',
      createdAt: DateTime.now(),
      isApproved: !requiresApproval,
      isAlive: true,
    );

    final userJson = newUser.toJson();
    userJson['username_lowercase'] = normalizedInput;
    userJson['isLoggedIn'] = !requiresApproval;

    await _usersCol.doc(newId).set(userJson);

    if (requiresApproval) {
      throw Exception(
        'Moderator registration submitted successfully! Please wait for Super Admin approval before logging in.',
      );
    }

    await prefs.setString(_deviceOwnerKey, newId);
    await setSession(newId);
    return newUser;
  }

  // SUPER ADMIN ACTIONS
  static Future<void> approveModerator(String userId) async {
    await _usersCol.doc(userId).update({'isApproved': true});
  }

  // MODERATOR ACTIONS
  static Future<void> reactivateUser(String userId) async {
    await _usersCol.doc(userId).update({'isTerminated': false});
  }

  static Future<void> softDeleteUser(String userId) async {
    await _usersCol.doc(userId).update({
      'isTerminated': true,
      'isLoggedIn': false,
    });
  }

  // GAME ENGINE UPDATES
  static Future<void> updateUserIdentity({
    required String userId,
    required String identity,
    required bool isAlive,
  }) async {
    await _usersCol.doc(userId).update({
      'identity': identity,
      'isAlive': isAlive,
    });
  }

  static Future<void> clearDeviceLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceOwnerKey);
  }

  // SESSION MANAGEMENT
  static Future<User?> getActiveSessionUser() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_sessionKey);
    if (activeId == null) return null;

    final doc = await _usersCol.doc(activeId).get();
    if (!doc.exists || doc.data() == null) return null;

    final user = User.fromJson(doc.data()!);
    if (user.isTerminated || (user.role == 'moderator' && !user.isApproved)) {
      await clearSession();
      return null;
    }
    return user;
  }

  static Future<void> setSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userId);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_sessionKey);

    if (activeId != null) {
      await _usersCol.doc(activeId).update({'isLoggedIn': false});
    }

    await prefs.remove(_sessionKey);
  }
}