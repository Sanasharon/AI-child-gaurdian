// ============================================================
// user_model.dart
// ------------------------------------------------------------
// Represents a single user document stored in the Firestore
// "users" collection. Both Parent and Child accounts use the
// SAME model - the only difference is the "role" field.
// ============================================================

class AppUser {
  final String uid;          // Firebase Auth unique ID
  final String name;
  final String email;
  final String role;         // "parent" or "child"
  final String? linkedUid;   // parent's uid (if child) / child's uid (if parent)
  final String? linkCode;    // 6-digit code parents share with their child

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.linkedUid,
    this.linkCode,
  });

  // Convert this object into a Map so it can be saved to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'linkedUid': linkedUid,
      'linkCode': linkCode,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  // Build an AppUser object from a Firestore document (Map).
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'child',
      linkedUid: map['linkedUid'],
      linkCode: map['linkCode'],
    );
  }
}
