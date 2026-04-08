import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'change_password_screen.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Seguridad'),
        backgroundColor: AppColors.baseBg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, size: 48, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seguridad de tu cuenta',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Protege tu información personal',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Password Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Contraseña'),
                    subtitle: const Text('Cambia tu contraseña regularmente'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2FA Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: user?.twoFactorEnabled == true
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        user?.twoFactorEnabled == true
                            ? Icons.verified_user
                            : Icons.security_outlined,
                        color: user?.twoFactorEnabled == true
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                    title: const Text('Autenticación de dos factores'),
                    subtitle: Text(
                      user?.twoFactorEnabled == true
                          ? 'Habilitada - Tu cuenta está protegida'
                          : 'Deshabilitada - Recomendamos habilitarla',
                    ),
                    trailing: Switch(
                      value: user?.twoFactorEnabled ?? false,
                      onChanged: (value) {
                        _handle2FAToggle(context, ref, value);
                      },
                      activeThumbColor: AppColors.success,
                    ),
                  ),

                  if (user?.twoFactorEnabled == false)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'La autenticación de dos factores añade una capa extra de seguridad a tu cuenta.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Account Actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history, color: AppColors.info),
                    ),
                    title: const Text('Historial de sesiones'),
                    subtitle: const Text('Ver dispositivos conectados'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.pushNamed('session-history');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                    ),
                    title: const Text('Eliminar cuenta'),
                    subtitle: const Text('Eliminar permanentemente tu cuenta'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.pushNamed('delete-account');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handle2FAToggle(BuildContext context, WidgetRef ref, bool enable) {
    // Navegar a la pantalla de configuración de 2FA
    context.pushNamed('two-factor');
  }
}
