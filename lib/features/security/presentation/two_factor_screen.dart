import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../auth/providers/auth_provider.dart';

class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  bool _isLoading = false;
  bool _isEnabling = false;
  String? _pendingEmail;
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enable2FA() async {
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authRepositoryProvider).enable2FA();

      setState(() {
        _isEnabling = true;
        _pendingEmail = result['email'] as String?;
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, result['message'] as String);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      SnackBarUtils.showError(context, 'El código debe tener 6 dígitos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .verify2FAActivation(_otpController.text.trim());

      // Refrescar perfil para actualizar el estado de 2FA
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        SnackBarUtils.showSuccess(context, result['message'] as String);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disable2FA() async {
    if (_passwordController.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'Ingresa tu contraseña para continuar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .disable2FA(_passwordController.text.trim());

      // Refrescar perfil para actualizar el estado de 2FA
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        SnackBarUtils.showSuccess(context, result['message'] as String);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_pendingEmail == null) return;

    setState(() => _isLoading = true);

    try {
      final message = await ref
          .read(authRepositoryProvider)
          .resendOTP(_pendingEmail!);

      if (mounted) {
        SnackBarUtils.showSuccess(context, message);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final is2FAEnabled = user?.twoFactorEnabled ?? false;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Autenticación de dos factores'),
        backgroundColor: AppColors.baseBg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icono de seguridad
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: is2FAEnabled
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  is2FAEnabled ? Icons.security : Icons.security_outlined,
                  size: 50,
                  color: is2FAEnabled ? AppColors.success : AppColors.warning,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Estado actual
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          is2FAEnabled
                              ? Icons.check_circle
                              : Icons.warning_amber_rounded,
                          color: is2FAEnabled
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            is2FAEnabled
                                ? '2FA Habilitado'
                                : '2FA Deshabilitado',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: is2FAEnabled
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      is2FAEnabled
                          ? 'Tu cuenta está protegida con autenticación de dos factores. Se te pedirá un código de verificación cada vez que inicies sesión.'
                          : 'Protege tu cuenta habilitando la autenticación de dos factores. Recibirás un código por correo cada vez que inicies sesión.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Información sobre 2FA
            if (!is2FAEnabled && !_isEnabling) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Cómo funciona?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        icon: Icons.email_outlined,
                        text:
                            'Recibirás un código de 6 dígitos en tu correo electrónico',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoItem(
                        icon: Icons.lock_outline,
                        text:
                            'Deberás ingresar este código cada vez que inicies sesión',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoItem(
                        icon: Icons.shield_outlined,
                        text:
                            'Aumenta significativamente la seguridad de tu cuenta',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Habilitar 2FA',
                onPressed: _isLoading ? null : _enable2FA,
                isLoading: _isLoading,
                icon: Icons.security,
              ),
            ],

            // Formulario de verificación OTP
            if (_isEnabling && !is2FAEnabled) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verificar código',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hemos enviado un código de 6 dígitos a tu correo electrónico. Ingrésalo a continuación para completar la activación.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _otpController,
                        label: 'Código de verificación',
                        hint: '000000',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Verificar código',
                onPressed: _isLoading ? null : _verifyOTP,
                isLoading: _isLoading,
                icon: Icons.check,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _resendOTP,
                icon: const Icon(Icons.refresh),
                label: const Text('Reenviar código'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEnabling = false;
                    _pendingEmail = null;
                    _otpController.clear();
                  });
                },
                child: const Text('Cancelar'),
              ),
            ],

            // Formulario para deshabilitar 2FA
            if (is2FAEnabled) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deshabilitar 2FA',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Para deshabilitar la autenticación de dos factores, ingresa tu contraseña actual.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Contraseña actual',
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Deshabilitar 2FA',
                onPressed: _isLoading ? null : _disable2FA,
                isLoading: _isLoading,
                icon: Icons.security_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
