/// App usage entry model for local database storage
class AppUsageEntry {
  final int? id;
  final String userId;
  final String packageName;
  final String? appName;
  final int usageMinutes;
  final DateTime date;
  final DateTime createdAt;

  AppUsageEntry({
    this.id,
    required this.userId,
    required this.packageName,
    this.appName,
    required this.usageMinutes,
    required this.date,
    required this.createdAt,
  });

  AppUsageEntry copyWith({
    int? id,
    String? userId,
    String? packageName,
    String? appName,
    int? usageMinutes,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return AppUsageEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      usageMinutes: usageMinutes ?? this.usageMinutes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'packageName': packageName,
      'appName': appName,
      'usageMinutes': usageMinutes,
      'date': date.toIso8601String().split('T')[0], // Store date only (YYYY-MM-DD)
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUsageEntry.fromMap(Map<String, dynamic> map) {
    // Parse date string (format: YYYY-MM-DD)
    final dateStr = map['date'] as String;
    final dateParts = dateStr.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    return AppUsageEntry(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      packageName: map['packageName'] as String,
      appName: map['appName'] as String?,
      usageMinutes: map['usageMinutes'] as int,
      date: date,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// App usage event from UsageStatsManager UsageEvents
class AppUsageEvent {
  final String packageName;
  final int eventType; // UsageEvents.Event.MOVE_TO_FOREGROUND, etc.
  final DateTime timestamp;
  final String className;

  AppUsageEvent({
    required this.packageName,
    required this.eventType,
    required this.timestamp,
    required this.className,
  });

  factory AppUsageEvent.fromJson(Map<String, dynamic> json) {
    return AppUsageEvent(
      packageName: json['packageName'] as String,
      eventType: json['eventType'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      className: json['className'] as String? ?? '',
    );
  }

  bool get isMoveToForeground => eventType == 1; // UsageEvents.Event.MOVE_TO_FOREGROUND
  bool get isMoveToBackground => eventType == 2; // UsageEvents.Event.MOVE_TO_BACKGROUND
}




