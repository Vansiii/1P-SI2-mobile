import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_constants.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/logout_dialog.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../services/push_notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getUserTypeLabel(String userType) {
    switch (userType) {
      case AppConstants.userTypeClient:
        return 'Cliente';
      case AppConstants.userTypeWorkshop:
        return 'Taller';
      case AppConstants.userTypeTechnician:
        return 'Técnico';
      case AppConstants.userTypeAdmin:
        return 'Administrador';
      default:
        return userType;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: AppColors.baseBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(authProvider.notifier).refreshProfile();
              if (context.mounted) {
                SnackBarUtils.showSuccess(context, 'Perfil actualizado');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.pushNamed('edit-profile');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),

            const SizedBox(height: 16),

            // Nombre completo (si está disponible)
            if (user.firstName != null || user.lastName != null)
              Text(
                '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

            if (user.firstName != null || user.lastName != null)
              const SizedBox(height: 8),

            // Email
            Text(user.email, style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 8),

            // User Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _getUserTypeLabel(user.userType),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información Personal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // Nombre
                    if (user.firstName != null && user.firstName!.isNotEmpty)
                      _buildInfoRow(
                        context,
                        icon: Icons.person_outline,
                        label: 'Nombre',
                        value: user.firstName!,
                      ),

                    if (user.firstName != null &&
                        user.firstName!.isNotEmpty &&
                        user.lastName != null &&
                        user.lastName!.isNotEmpty)
                      const Divider(height: 24),

                    // Apellido
                    if (user.lastName != null && user.lastName!.isNotEmpty)
                      _buildInfoRow(
                        context,
                        icon: Icons.person_outline,
                        label: 'Apellido',
                        value: user.lastName!,
                      ),

                    if ((user.firstName != null &&
                            user.firstName!.isNotEmpty) ||
                        (user.lastName != null && user.lastName!.isNotEmpty))
                      const Divider(height: 24),

                    // Email
                    _buildInfoRow(
                      context,
                      icon: Icons.email_outlined,
                      label: 'Correo electrónico',
                      value: user.email,
                    ),

                    // Teléfono
                    if (user.phone != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: user.phone!,
                      ),
                    ],

                    // Cliente específico
                    if (user.userType == AppConstants.userTypeClient) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.badge_outlined,
                        label: 'CI',
                        value: user.ci ?? 'N/A',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.location_on_outlined,
                        label: 'Dirección',
                        value: user.direccion ?? 'N/A',
                      ),
                      if (user.fechaNacimiento != null) ...[
                        const Divider(height: 24),
                        _buildInfoRow(
                          context,
                          icon: Icons.cake_outlined,
                          label: 'Fecha de nacimiento',
                          value: DateFormat(
                            'dd/MM/yyyy',
                          ).format(user.fechaNacimiento!),
                        ),
                      ],
                    ],

                    // Taller específico
                    if (user.userType == AppConstants.userTypeWorkshop) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.business_outlined,
                        label: 'Nombre del taller',
                        value: user.workshopName ?? 'N/A',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.person_outline,
                        label: 'Propietario',
                        value: user.ownerName ?? 'N/A',
                      ),
                    ],

                    // Técnico específico
                    if (user.userType == AppConstants.userTypeTechnician) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.business_outlined,
                        label: 'Taller asignado',
                        value: user.workshopName ?? 'Sin asignar',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.work_outline,
                        label: 'Estado de disponibilidad',
                        value: user.isAvailable == true
                            ? 'Disponible'
                            : 'No disponible',
                        valueColor: user.isAvailable == true
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.online_prediction,
                        label: 'Estado de conexión',
                        value: user.isOnline == true
                            ? 'En línea'
                            : 'Desconectado',
                        valueColor: user.isOnline == true
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                      if (user.lastSeenAt != null) ...[
                        const Divider(height: 24),
                        _buildInfoRow(
                          context,
                          icon: Icons.access_time,
                          label: 'Última conexión',
                          value: DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(user.lastSeenAt!),
                        ),
                      ],
                    ],

                    // Administrador específico
                    if (user.userType == AppConstants.userTypeAdmin) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.admin_panel_settings,
                        label: 'Nivel de rol',
                        value: user.roleLevel?.toString() ?? 'N/A',
                      ),
                    ],

                    const Divider(height: 24),

                    // Estado
                    _buildInfoRow(
                      context,
                      icon: user.isActive
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      label: 'Estado',
                      value: user.isActive ? 'Activo' : 'Inactivo',
                      valueColor: user.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),

                    const Divider(height: 24),

                    // 2FA
                    _buildInfoRow(
                      context,
                      icon: user.twoFactorEnabled
                          ? Icons.security
                          : Icons.security_outlined,
                      label: 'Autenticación 2FA',
                      value: user.twoFactorEnabled
                          ? 'Habilitada'
                          : 'Deshabilitada',
                      valueColor: user.twoFactorEnabled
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Account Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información de Cuenta',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    if (user.createdAt != null)
                      _buildInfoRow(
                        context,
                        icon: Icons.calendar_today_outlined,
                        label: 'Miembro desde',
                        value: DateFormat('dd/MM/yyyy').format(user.createdAt!),
                      ),

                    if (user.createdAt != null && user.updatedAt != null)
                      const Divider(height: 24),

                    if (user.updatedAt != null)
                      _buildInfoRow(
                        context,
                        icon: Icons.update_outlined,
                        label: 'Última actualización',
                        value: DateFormat('dd/MM/yyyy').format(user.updatedAt!),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Security Button
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.security, color: AppColors.primary),
                ),
                title: const Text('Seguridad'),
                subtitle: const Text('Contraseña, 2FA y más'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.pushNamed('security');
                },
              ),
            ),

            const SizedBox(height: 16),

            // Notification Settings Button
            _NotificationSettingsCard(),

            const SizedBox(height: 16),

            // Camera Permission Card
            _CameraPermissionCard(),

            const SizedBox(height: 24),

            // Logout Button
            PrimaryButton(
              text: 'Cerrar sesión',
              onPressed: () => _showLogoutDialog(context, ref),
              icon: Icons.logout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const LogoutDialog(),
    );

    if (result == true && context.mounted) {
      await _performLogout(context, ref);
    }
  }

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    // Mostrar overlay de logout con animación
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => LogoutOverlay(
        onComplete: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);

    // Realizar logout inmediatamente (sin esperar)
    await ref.read(authProvider.notifier).logout();

    // Esperar a que la animación llegue a su punto medio (cuando está completamente visible)
    await Future.delayed(const Duration(milliseconds: 800));

    // Navegar al login mientras la animación sigue (fade out)
    if (context.mounted) {
      context.go('/login');
    }

    // La animación continuará y se completará automáticamente
    // El overlay se eliminará cuando termine (después de 2000ms totales)
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor ?? AppColors.textMain,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget para gestionar permisos de notificaciones
class _NotificationSettingsCard extends StatefulWidget {
  @override
  State<_NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<_NotificationSettingsCard> {
  bool _isChecking = true;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    setState(() => _isChecking = true);
    try {
      final enabled = await PushNotificationService().areNotificationsEnabled();
      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      // Solicitar permiso
      final status = await Permission.notification.request();

      if (status.isGranted) {
        // Reinicializar el servicio de notificaciones para obtener el token
        await PushNotificationService().initialize();

        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            'Notificaciones habilitadas correctamente',
          );
          _checkNotificationStatus();
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showOpenSettingsDialog();
        }
      } else {
        if (mounted) {
          SnackBarUtils.showError(
            context,
            'Permiso de notificaciones denegado',
          );
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      if (mounted) {
        SnackBarUtils.showError(context, 'Error al solicitar permisos: $e');
      }
    }
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permisos de notificaciones'),
        content: const Text(
          'Los permisos de notificaciones están deshabilitados. '
          'Para habilitarlos, ve a la configuración de la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
              // Esperar un poco y verificar de nuevo
              await Future.delayed(const Duration(seconds: 1));
              _checkNotificationStatus();
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _notificationsEnabled
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _notificationsEnabled
                ? Icons.notifications_active
                : Icons.notifications_off,
            color: _notificationsEnabled
                ? AppColors.success
                : AppColors.warning,
          ),
        ),
        title: const Text('Notificaciones Push'),
        subtitle: _isChecking
            ? const Text('Verificando...')
            : Text(
                _notificationsEnabled
                    ? 'Habilitadas'
                    : 'Deshabilitadas - Toca para habilitar',
              ),
        trailing: _isChecking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _notificationsEnabled
                    ? Icons.check_circle
                    : Icons.chevron_right,
                color: _notificationsEnabled ? AppColors.success : null,
              ),
        onTap: _isChecking || _notificationsEnabled
            ? null
            : _requestNotificationPermission,
      ),
    );
  }
}

/// Widget para gestionar permisos de cámara
class _CameraPermissionCard extends StatefulWidget {
  @override
  State<_CameraPermissionCard> createState() => _CameraPermissionCardState();
}

class _CameraPermissionCardState extends State<_CameraPermissionCard> {
  bool _isChecking = true;
  bool _cameraEnabled = false;
  bool _photosEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() => _isChecking = true);
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;

      if (mounted) {
        setState(() {
          _cameraEnabled = cameraStatus.isGranted;
          _photosEnabled = photosStatus.isGranted;
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking camera permission status: $e');
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();

      if (status.isGranted) {
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Permiso de cámara habilitado');
          _checkPermissionStatus();
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showOpenSettingsDialog('cámara');
        }
      } else {
        if (mounted) {
          SnackBarUtils.showError(context, 'Permiso de cámara denegado');
        }
      }
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      if (mounted) {
        SnackBarUtils.showError(context, 'Error al solicitar permisos: $e');
      }
    }
  }

  Future<void> _requestPhotosPermission() async {
    try {
      final status = await Permission.photos.request();

      if (status.isGranted) {
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Permiso de galería habilitado');
          _checkPermissionStatus();
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showOpenSettingsDialog('galería');
        }
      } else {
        if (mounted) {
          SnackBarUtils.showError(context, 'Permiso de galería denegado');
        }
      }
    } catch (e) {
      debugPrint('Error requesting photos permission: $e');
      if (mounted) {
        SnackBarUtils.showError(context, 'Error al solicitar permisos: $e');
      }
    }
  }

  void _showOpenSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Permisos de $permissionName'),
        content: Text(
          'Los permisos de $permissionName están deshabilitados. '
          'Para habilitarlos, ve a la configuración de la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissionStatus();
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allEnabled = _cameraEnabled && _photosEnabled;
    final someEnabled = _cameraEnabled || _photosEnabled;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: allEnabled
                    ? AppColors.success.withValues(alpha: 0.1)
                    : someEnabled
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                allEnabled
                    ? Icons.camera_alt
                    : someEnabled
                    ? Icons.camera_alt_outlined
                    : Icons.no_photography,
                color: allEnabled
                    ? AppColors.success
                    : someEnabled
                    ? AppColors.warning
                    : AppColors.error,
              ),
            ),
            title: const Text('Permisos de Cámara y Fotos'),
            subtitle: _isChecking
                ? const Text('Verificando...')
                : Text(
                    allEnabled
                        ? 'Todos los permisos habilitados'
                        : someEnabled
                        ? 'Algunos permisos deshabilitados'
                        : 'Permisos deshabilitados',
                  ),
            trailing: _isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    allEnabled ? Icons.check_circle : Icons.chevron_right,
                    color: allEnabled ? AppColors.success : null,
                  ),
          ),
          if (!_isChecking && !allEnabled) ...[
            const Divider(height: 1),
            if (!_cameraEnabled)
              ListTile(
                dense: true,
                leading: const Icon(Icons.camera_alt_outlined, size: 20),
                title: const Text('Cámara'),
                subtitle: const Text('Toca para habilitar'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _requestCameraPermission,
              ),
            if (!_photosEnabled)
              ListTile(
                dense: true,
                leading: const Icon(Icons.photo_library_outlined, size: 20),
                title: const Text('Galería de fotos'),
                subtitle: const Text('Toca para habilitar'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _requestPhotosPermission,
              ),
          ],
        ],
      ),
    );
  }
}
