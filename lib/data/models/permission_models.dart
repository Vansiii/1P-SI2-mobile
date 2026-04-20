/// Permission Models for RBAC system

class PermissionInfo {
  final String name;
  final String value;
  final String description;

  PermissionInfo({
    required this.name,
    required this.value,
    required this.description,
  });

  factory PermissionInfo.fromJson(Map<String, dynamic> json) {
    return PermissionInfo(
      name: json['name'] as String,
      value: json['value'] as String,
      description: json['description'] as String,
    );
  }
}

class RoleInfo {
  final String name;
  final String value;
  final String description;
  final int permissionCount;
  final bool canModify;

  RoleInfo({
    required this.name,
    required this.value,
    required this.description,
    required this.permissionCount,
    required this.canModify,
  });

  factory RoleInfo.fromJson(Map<String, dynamic> json) {
    return RoleInfo(
      name: json['name'] as String,
      value: json['value'] as String,
      description: json['description'] as String,
      permissionCount: json['permission_count'] as int,
      canModify: json['can_modify'] as bool? ?? false,
    );
  }
}

class RolePermissions {
  final String role;
  final List<String> permissions;

  RolePermissions({required this.role, required this.permissions});

  factory RolePermissions.fromJson(Map<String, dynamic> json) {
    return RolePermissions(
      role: json['role'] as String,
      permissions: (json['permissions'] as List).cast<String>(),
    );
  }
}

class UpdateRolePermissionsResponse {
  final String role;
  final List<String> permissions;
  final List<String> added;
  final List<String> removed;

  UpdateRolePermissionsResponse({
    required this.role,
    required this.permissions,
    required this.added,
    required this.removed,
  });

  factory UpdateRolePermissionsResponse.fromJson(Map<String, dynamic> json) {
    return UpdateRolePermissionsResponse(
      role: json['role'] as String,
      permissions: (json['permissions'] as List).cast<String>(),
      added: (json['added'] as List).cast<String>(),
      removed: (json['removed'] as List).cast<String>(),
    );
  }
}
