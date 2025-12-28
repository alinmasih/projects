import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user in the application with role-based access control.
class AppUser {
  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.fcmToken,
    this.isOnline = false,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? photoUrl;
  final String? fcmToken;
  final bool isOnline;
  final DateTime lastSeen;

  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({
    String? displayName,
    UserRole? role,
    String? photoUrl,
    String? fcmToken,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory AppUser.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'User',
      role: UserRoleX.fromString(data['role'] as String? ?? UserRole.user.name),
      photoUrl: data['photoUrl'] as String?,
      fcmToken: data['fcmToken'] as String?,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'photoUrl': photoUrl,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(lastSeen),
    };
  }
}

/// Supported user roles inside the app.
enum UserRole { admin, user }

extension UserRoleX on UserRole {
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.user,
    );
  }

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.user:
        return 'User';
    }
  }
}
