import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/admin/permissions_screen.dart';
import '../../core/config/app_constants.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

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

    return Drawer(
      child: Column(
        children: [
          // Header del drawer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryHover],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                // Nombre
                Text(
                  user?.firstName ?? user?.email.split('@')[0] ?? 'Usuario',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Email
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Badge de tipo de usuario
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getUserTypeLabel(user?.userType ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Opciones del menú
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.home,
                  title: 'Inicio',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/home');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.directions_car,
                  title: 'Mis Vehículos',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/vehicles');
                  },
                ),
                // Solo mostrar "Mis Emergencias" para clientes, no para técnicos
                if (user?.userType != 'technician')
                  _buildDrawerItem(
                    context,
                    icon: Icons.warning,
                    title: 'Mis Emergencias',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/incidents');
                    },
                  ),
                _buildDrawerItem(
                  context,
                  icon: Icons.build,
                  title: 'Mis Servicios',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Servicios - Próximamente')),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.location_on,
                  title: 'Talleres Cercanos',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Talleres - Próximamente')),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.history,
                  title: 'Historial',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Historial - Próximamente')),
                    );
                  },
                ),

                // Sección de administración (solo para admins)
                if (user?.userType == 'admin') ...[
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'ADMINISTRACIÓN',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.admin_panel_settings,
                    title: 'Gestión de Permisos',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PermissionsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people,
                    title: 'Gestión de Usuarios',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gestión de Usuarios - Próximamente'),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics,
                    title: 'Reportes y Métricas',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reportes - Próximamente'),
                        ),
                      );
                    },
                  ),
                ],

                const Divider(height: 32),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings,
                  title: 'Configuración',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Configuración - Próximamente'),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.help_outline,
                  title: 'Ayuda y Soporte',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ayuda - Próximamente')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textMain),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
