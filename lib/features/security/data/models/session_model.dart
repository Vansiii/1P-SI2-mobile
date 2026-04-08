class SessionModel {
  final String jti;
  final String deviceName;
  final String deviceType;
  final String? ipAddress;
  final String location;
  final DateTime lastActive;
  final bool isCurrent;

  SessionModel({
    required this.jti,
    required this.deviceName,
    required this.deviceType,
    this.ipAddress,
    required this.location,
    required this.lastActive,
    required this.isCurrent,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      jti: json['jti'] as String,
      deviceName: json['device_name'] as String,
      deviceType: json['device_type'] as String,
      ipAddress: json['ip_address'] as String?,
      location: json['location'] as String,
      lastActive: DateTime.parse(json['last_active'] as String),
      isCurrent: json['is_current'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jti': jti,
      'device_name': deviceName,
      'device_type': deviceType,
      'ip_address': ipAddress,
      'location': location,
      'last_active': lastActive.toIso8601String(),
      'is_current': isCurrent,
    };
  }
}

class SessionListModel {
  final SessionModel currentSession;
  final List<SessionModel> otherSessions;
  final int totalSessions;

  SessionListModel({
    required this.currentSession,
    required this.otherSessions,
    required this.totalSessions,
  });

  factory SessionListModel.fromJson(Map<String, dynamic> json) {
    return SessionListModel(
      currentSession: SessionModel.fromJson(
        json['current_session'] as Map<String, dynamic>,
      ),
      otherSessions: (json['other_sessions'] as List)
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSessions: json['total_sessions'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_session': currentSession.toJson(),
      'other_sessions': otherSessions.map((e) => e.toJson()).toList(),
      'total_sessions': totalSessions,
    };
  }
}
