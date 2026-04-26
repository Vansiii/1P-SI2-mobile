import 'package:merchanic_repair/data/models/permission_models.dart';
import 'package:merchanic_repair/data/services/api_service.dart';
import 'package:merchanic_repair/core/config/api_config.dart';

class PermissionsRepository {
  final ApiService _apiService;

  PermissionsRepository(this._apiService);

  /// Get all available permissions
  Future<List<PermissionInfo>> getAllPermissions() async {
    try {
      final response = await _apiService.get('${ApiConfig.admin}/permissions');

      // El backend devuelve {data: {permissions: [...], total: ...}}
      final dataWrapper = response['data'];
      if (dataWrapper == null) {
        return [];
      }

      final permissionsList = dataWrapper['permissions'];
      if (permissionsList == null) {
        return [];
      }

      final permissions = (permissionsList as List)
          .map((json) => PermissionInfo.fromJson(json))
          .toList();
      return permissions;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all roles
  Future<List<RoleInfo>> getAllRoles() async {
    try {
      final response = await _apiService.get('${ApiConfig.admin}/roles');

      // El backend devuelve {data: {roles: [...], total: ...}}
      final dataWrapper = response['data'];
      if (dataWrapper == null) {
        return [];
      }

      final rolesList = dataWrapper['roles'];
      if (rolesList == null) {
        return [];
      }

      final roles = (rolesList as List)
          .map((json) => RoleInfo.fromJson(json))
          .toList();
      return roles;
    } catch (e) {
      rethrow;
    }
  }

  /// Get permissions for a specific role
  Future<RolePermissions> getRolePermissions(String role) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.admin}/roles/$role/permissions',
      );

      // El backend devuelve {data: {role: ..., permissions: [...], total_permissions: ...}}
      final dataWrapper = response['data'];
      if (dataWrapper == null) {
        throw Exception('Data wrapper is null');
      }

      return RolePermissions.fromJson(dataWrapper);
    } catch (e) {
      rethrow;
    }
  }

  /// Update permissions for a role (replace all)
  Future<UpdateRolePermissionsResponse> updateRolePermissions(
    String role,
    List<String> permissions,
  ) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.admin}/roles/$role/permissions',
        data: {'permissions': permissions},
      );

      // El backend devuelve {data: {role: ..., permissions: [...], added: [...], removed: [...], message: ...}}
      final dataWrapper = response['data'];
      if (dataWrapper == null) {
        throw Exception('Data wrapper is null');
      }

      return UpdateRolePermissionsResponse.fromJson(dataWrapper);
    } catch (e) {
      rethrow;
    }
  }
}
