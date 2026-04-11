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
