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
        createdAt: DateTime.now(),
        isApproved: true,
      );
      final json = superAdmin.toJson();
      json['username_lowercase'] = superAdminUsername;
      await _usersCol.doc(id).set(json);
    }
  }

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
      final existingUser = User.fromJson(query.docs.first.data());

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

    // Moderators require Super Admin approval by default
    final bool requiresApproval = (role == 'moderator');

    final newUser = User(
      id: newId,
      username: username.trim(),
      role: role,
      createdAt: DateTime.now(),
      isApproved: !requiresApproval,
    );

    final userJson = newUser.toJson();
    userJson['username_lowercase'] = normalizedInput;

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
    await _usersCol.doc(userId).update({'isTerminated': true});
    await clearSession();
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
    await prefs.remove(_sessionKey);
  }
}