class User {
  final String id;
  final String username;
  final String role; // 'mafia', 'moderator', or 'superadmin'
  final DateTime createdAt;
  final bool isTerminated;
  final bool isApproved; // Permission status flag

  User({
    required this.id,
    required this.username,
    required this.role,
    required this.createdAt,
    this.isTerminated = false,
    this.isApproved = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
        'isTerminated': isTerminated,
        'isApproved': isApproved,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        username: json['username'],
        role: json['role'],
        createdAt: DateTime.parse(json['createdAt']),
        isTerminated: json['isTerminated'] ?? false,
        isApproved: json['isApproved'] ?? true,
      );

  User copyWith({bool? isTerminated, bool? isApproved}) {
    return User(
      id: id,
      username: username,
      role: role,
      createdAt: createdAt,
      isTerminated: isTerminated ?? this.isTerminated,
      isApproved: isApproved ?? this.isApproved,
    );
  }
}