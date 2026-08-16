class User {
  final String id;
  final String username;
  final String role; // Permission role: 'mafia', 'moderator', 'superadmin'
  final String identity; // In-game identity: 'killer', 'detective', 'healer', 'villager', 'none'
  final DateTime createdAt;
  final bool isApproved;
  final bool isTerminated;
  final bool isAlive;

  User({
    required this.id,
    required this.username,
    required this.role,
    this.identity = 'none',
    required this.createdAt,
    this.isApproved = false,
    this.isTerminated = false,
    this.isAlive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'mafia',
      identity: json['identity'] ?? 'none',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isApproved: json['isApproved'] ?? false,
      isTerminated: json['isTerminated'] ?? false,
      isAlive: json['isAlive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'identity': identity,
      'createdAt': createdAt.toIso8601String(),
      'isApproved': isApproved,
      'isTerminated': isTerminated,
      'isAlive': isAlive,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? role,
    String? identity,
    DateTime? createdAt,
    bool? isApproved,
    bool? isTerminated,
    bool? isAlive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      identity: identity ?? this.identity,
      createdAt: createdAt ?? this.createdAt,
      isApproved: isApproved ?? this.isApproved,
      isTerminated: isTerminated ?? this.isTerminated,
      isAlive: isAlive ?? this.isAlive,
    );
  }
}