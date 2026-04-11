import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/data/models/permission_models.dart';
import 'package:merchanic_repair/data/repositories/permissions_repository.dart';
import 'package:merchanic_repair/features/auth/providers/auth_provider.dart';

// Provider del repositorio
final permissionsRepoProvider = Provider<PermissionsRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return PermissionsRepository(apiService);
});

// Screen principal
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  List<PermissionInfo> _allPermissions = [];
  List<RoleInfo> _allRoles = [];
  RoleInfo? _selectedRole;
  Set<String> _selectedPermissions = {};
  Set<String> _originalPermissions = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(permissionsRepoProvider);
      final permissions = await repo.getAllPermissions();
      final roles = await repo.getAllRoles();

      setState(() {
        _allPermissions = permissions;
        _allRoles = roles.where((role) => role.canModify).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectRole(RoleInfo role) async {
    setState(() {
      _selectedRole = role;
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(permissionsRepoProvider);
      final rolePerms = await repo.getRolePermissions(role.value);

      setState(() {
        _selectedPermissions = rolePerms.permissions.toSet();
        _originalPermissions = rolePerms.permissions.toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar permisos: $e';
        _isLoading = false;
      });
    }
  }

  void _togglePermission(String permissionValue) {
    setState(() {
      if (_selectedPermissions.contains(permissionValue)) {
        _selectedPermissions.remove(permissionValue);
      } else {
        _selectedPermissions.add(permissionValue);
      }
    });
  }

  bool get _hasChanges {
    return _selectedPermissions.length != _originalPermissions.length ||
        !_selectedPermissions.every((p) => _originalPermissions.contains(p));
  }

  Future<void> _savePermissions() async {
    if (_selectedRole == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(permissionsRepoProvider);
      final response = await repo.updateRolePermissions(
        _selectedRole!.value,
        _selectedPermissions.toList(),
      );

      setState(() {
        _originalPermissions = _selectedPermissions.toSet();
        _successMessage = '✓ Permisos actualizados correctamente';
        _isSaving = false;
      });

      // Actualizar conteo de permisos del rol
      final updatedRoles = _allRoles.map((r) {
        if (r.value == _selectedRole!.value) {
          return RoleInfo(
            name: r.name,
            value: r.value,
            description: r.description,
            permissionCount: response.permissions.length,
            canModify: r.canModify,
          );
        }
        return r;
      }).toList();

      setState(() => _allRoles = updatedRoles);

      // Auto-ocultar mensaje de éxito
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _successMessage = null);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar: $e';
        _isSaving = false;
      });
    }
  }

  void _resetPermissions() {
    setState(() {
      _selectedPermissions = _originalPermissions.toSet();
    });
  }

  Map<String, List<PermissionInfo>> get _permissionsByCategory {
    final categories = <String, List<PermissionInfo>>{};
    for (final perm in _allPermissions) {
      final category = perm.value.split(':')[0];
      categories.putIfAbsent(category, () => []).add(perm);
    }
    return categories;
  }

  String _getCategoryName(String category) {
    const names = {
      'auth': 'Autenticación',
      'password': 'Contraseñas',
      'profile': 'Perfil',
      'vehicle': 'Vehículos',
      'emergency': 'Emergencias',
      'request': 'Solicitudes',
      'service': 'Servicios',
      'chat': 'Comunicación',
      'technician': 'Técnicos',
      'workshop': 'Talleres',
      'payment': 'Pagos',
      'commission': 'Comisiones',
      'notification': 'Notificaciones',
      'report': 'Reportes',
      'admin': 'Administración',
      'ai': 'IA',
      'assignment': 'Asignación',
    };
    return names[category] ?? category[0].toUpperCase() + category.substring(1);
  }

  String _getRoleName(String roleValue) {
    const names = {
      'admin': 'Administrador',
      'workshop': 'Taller',
      'technician': 'Técnico',
      'client': 'Cliente',
      'user': 'Usuario',
    };
    return names[roleValue] ??
        roleValue[0].toUpperCase() + roleValue.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Gestión de Permisos'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        actions: [
          if (_selectedRole != null && _hasChanges) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetPermissions,
              tooltip: 'Restablecer',
            ),
            IconButton(
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMain,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _savePermissions,
              tooltip: 'Guardar',
            ),
          ],
        ],
      ),
      body: _isLoading && _allRoles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mensajes
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.error.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _errorMessage = null),
                          color: AppColors.error,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                if (_successMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.success.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _successMessage = null),
                          color: AppColors.success,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                // Selector de roles - Horizontal deslizable
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Seleccionar Rol',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _allRoles.length,
                          itemBuilder: (context, index) {
                            final role = _allRoles[index];
                            final isSelected =
                                _selectedRole?.value == role.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () => _selectRole(role),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.gray100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getRoleName(role.value),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textMain,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${role.permissionCount} permisos',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? Colors.white.withValues(
                                                  alpha: 0.9,
                                                )
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de permisos
                if (_selectedRole != null)
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _permissionsByCategory.length,
                            itemBuilder: (context, index) {
                              final entry = _permissionsByCategory.entries
                                  .elementAt(index);
                              return _buildCategoryCard(entry.key, entry.value);
                            },
                          ),
                  )
                else
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Selecciona un rol para gestionar permisos',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(
    String categoryKey,
    List<PermissionInfo> permissions,
  ) {
    final categoryName = _getCategoryName(categoryKey);
    final selectedCount = permissions
        .where((p) => _selectedPermissions.contains(p.value))
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
                Text(
                  '$selectedCount/${permissions.length}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...permissions.map((permission) {
              final isSelected = _selectedPermissions.contains(
                permission.value,
              );
              return InkWell(
                onTap: () => _togglePermission(permission.value),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _togglePermission(permission.value),
                          activeColor: AppColors.success,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              permission.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              permission.value,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
