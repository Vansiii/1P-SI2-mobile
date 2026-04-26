/// User Model - Representa los diferentes tipos de usuario
class UserModel {
  final int id;
  final String email;
  final String userType;
  final bool isActive;
  final bool twoFactorEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Campos comunes
  final String? firstName;
  final String? lastName;
  final String? phone;

  // Campos específicos por tipo
  final String? direccion; // Client
  final String? ci; // Client
  final DateTime? fechaNacimiento; // Client
  final String? workshopName; // Workshop
  final String? ownerName; // Workshop
  final double? latitude; // Workshop
  final double? longitude; // Workshop
  final double? coverageRadiusKm; // Workshop
  final int? workshopId; // Technician
  final double? currentLatitude; // Technician
  final double? currentLongitude; // Technician
  final bool? isAvailable; // Technician
  final bool? isOnline; // Technician
  final DateTime? lastSeenAt; // Technician
  final DateTime? locationUpdatedAt; // Technician
  final double? locationAccuracy; // Technician
  final int? roleLevel; // Administrator

  UserModel({
    required this.id,
    required this.email,
    required this.userType,
    this.isActive = true,
    this.twoFactorEnabled = false,
    this.createdAt,
    this.updatedAt,
    this.firstName,
    this.lastName,
    this.phone,
    this.direccion,
    this.ci,
    this.fechaNacimiento,
    this.workshopName,
    this.ownerName,
    this.latitude,
    this.longitude,
    this.coverageRadiusKm,
    this.workshopId,
    this.currentLatitude,
    this.currentLongitude,
    this.isAvailable,
    this.isOnline,
    this.lastSeenAt,
    this.locationUpdatedAt,
    this.locationAccuracy,
    this.roleLevel,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String,
      userType: json['user_type'] as String,
      isActive: json['is_active'] as bool? ?? true,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      direccion: json['direccion'] as String?,
      ci: json['ci'] as String?,
      fechaNacimiento: json['fecha_nacimiento'] != null
          ? DateTime.parse(json['fecha_nacimiento'] as String)
          : null,
      workshopName: json['workshop_name'] as String?,
      ownerName: json['owner_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      coverageRadiusKm: (json['coverage_radius_km'] as num?)?.toDouble(),
      workshopId: json['workshop_id'] as int?,
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      isAvailable: json['is_available'] as bool?,
      isOnline: json['is_online'] as bool?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.parse(json['location_updated_at'] as String)
          : null,
      locationAccuracy: (json['location_accuracy'] as num?)?.toDouble(),
      roleLevel: json['role_level'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'user_type': userType,
      'is_active': isActive,
      'two_factor_enabled': twoFactorEnabled,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phone != null) 'phone': phone,
      if (direccion != null) 'direccion': direccion,
      if (ci != null) 'ci': ci,
      if (fechaNacimiento != null)
        'fecha_nacimiento': fechaNacimiento!.toIso8601String(),
      if (workshopName != null) 'workshop_name': workshopName,
      if (ownerName != null) 'owner_name': ownerName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (coverageRadiusKm != null) 'coverage_radius_km': coverageRadiusKm,
      if (workshopId != null) 'workshop_id': workshopId,
      if (currentLatitude != null) 'current_latitude': currentLatitude,
      if (currentLongitude != null) 'current_longitude': currentLongitude,
      if (isAvailable != null) 'is_available': isAvailable,
      if (isOnline != null) 'is_online': isOnline,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
      if (locationUpdatedAt != null)
        'location_updated_at': locationUpdatedAt!.toIso8601String(),
      if (locationAccuracy != null) 'location_accuracy': locationAccuracy,
      if (roleLevel != null) 'role_level': roleLevel,
    };
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? userType,
    bool? isActive,
    bool? twoFactorEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? firstName,
    String? lastName,
    String? phone,
    String? direccion,
    String? ci,
    DateTime? fechaNacimiento,
    String? workshopName,
    String? ownerName,
    double? latitude,
    double? longitude,
    double? coverageRadiusKm,
    int? workshopId,
    double? currentLatitude,
    double? currentLongitude,
    bool? isAvailable,
    bool? isOnline,
    DateTime? lastSeenAt,
    DateTime? locationUpdatedAt,
    double? locationAccuracy,
    int? roleLevel,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      isActive: isActive ?? this.isActive,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      direccion: direccion ?? this.direccion,
      ci: ci ?? this.ci,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      workshopName: workshopName ?? this.workshopName,
      ownerName: ownerName ?? this.ownerName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      coverageRadiusKm: coverageRadiusKm ?? this.coverageRadiusKm,
      workshopId: workshopId ?? this.workshopId,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      isAvailable: isAvailable ?? this.isAvailable,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      roleLevel: roleLevel ?? this.roleLevel,
    );
  }
}
