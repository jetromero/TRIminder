// Department model matching Supabase departments table
class Department {
  final int id;
  final String name;

  Department({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: map['id'],
      name: map['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
    );
  }
}

// Friendship model matching Supabase friendships table
class Friendship {
  final int id;
  final String userId;
  final String friendId;
  final String status; // 'pending', 'accepted', 'blocked'
  final DateTime createdAt;

  Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'friendId': friendId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Friendship.fromMap(Map<String, dynamic> map) {
    return Friendship(
      id: map['id'],
      userId: map['userId'],
      friendId: map['friendId'],
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'friend_id': friendId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'],
      userId: json['user_id'],
      friendId: json['friend_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// Like model matching Supabase likes table
class Like {
  final int id;
  final String likerId;
  final String likedId;
  final DateTime createdAt;
  final DateTime createdDate;

  Like({
    required this.id,
    required this.likerId,
    required this.likedId,
    required this.createdAt,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'likerId': likerId,
      'likedId': likedId,
      'createdAt': createdAt.toIso8601String(),
      'createdDate': createdDate.toIso8601String(),
    };
  }

  factory Like.fromMap(Map<String, dynamic> map) {
    return Like(
      id: map['id'],
      likerId: map['likerId'],
      likedId: map['likedId'],
      createdAt: DateTime.parse(map['createdAt']),
      createdDate: DateTime.parse(map['createdDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'liker_id': likerId,
      'liked_id': likedId,
      'created_at': createdAt.toIso8601String(),
      'created_date': createdDate.toIso8601String(),
    };
  }

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      id: json['id'],
      likerId: json['liker_id'],
      likedId: json['liked_id'],
      createdAt: DateTime.parse(json['created_at']),
      createdDate: DateTime.parse(json['created_date']),
    );
  }
}

// Leaderboard snapshot model matching Supabase leaderboard_snapshots table
class LeaderboardSnapshot {
  final int id;
  final String userId;
  final DateTime date;
  final int xpPoints;
  final int totalLikes;
  final int? globalRank;
  final int? departmentRank;

  LeaderboardSnapshot({
    required this.id,
    required this.userId,
    required this.date,
    required this.xpPoints,
    required this.totalLikes,
    this.globalRank,
    this.departmentRank,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'xpPoints': xpPoints,
      'totalLikes': totalLikes,
      'globalRank': globalRank,
      'departmentRank': departmentRank,
    };
  }

  factory LeaderboardSnapshot.fromMap(Map<String, dynamic> map) {
    return LeaderboardSnapshot(
      id: map['id'],
      userId: map['userId'],
      date: DateTime.parse(map['date']),
      xpPoints: map['xpPoints'],
      totalLikes: map['totalLikes'],
      globalRank: map['globalRank'],
      departmentRank: map['departmentRank'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'date': date.toIso8601String(),
      'xp_points': xpPoints,
      'total_likes': totalLikes,
      'global_rank': globalRank,
      'department_rank': departmentRank,
    };
  }

  factory LeaderboardSnapshot.fromJson(Map<String, dynamic> json) {
    return LeaderboardSnapshot(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      xpPoints: json['xp_points'],
      totalLikes: json['total_likes'],
      globalRank: json['global_rank'],
      departmentRank: json['department_rank'],
    );
  }
}
