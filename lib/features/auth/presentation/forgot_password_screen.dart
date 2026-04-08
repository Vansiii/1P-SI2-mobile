import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../../shared/validators/form_validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepository = AuthRepository(
        ApiService(StorageService()),
        StorageService(),
      );

      await authRepository.forgotPasswordMobile(_emailController.text.trim());

      if (!mounted) return;

      // Mostrar mensaje de éxito
      SnackBarUtils.showSuccess(
        null,
        'Código enviado. Revisa tu correo electrónico',
      );

      // Navegar a pantalla de verificación OTP
      context.pushNamed(
        'verify-password-otp',
        pathParameters: {'email': _emailController.text.trim()},
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(null, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: AppColors.baseBg,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.lock_reset,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  '¿Olvidaste tu contraseña?',
                  style: Theme.of(context).textTheme.displayMedium,
                ),

                const SizedBox(height: 8),

                Text(
                  'Ingresa tu correo electrónico y te enviaremos un código de verificación para restablecer tu contraseña.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),

                const SizedBox(height: 32),

                // Email field
                CustomTextField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  hint: 'tu@email.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: FormValidators.email,
                ),

                const SizedBox(height: 24),

                // Send button
                PrimaryButton(
                  text: 'Enviar código',
                  onPressed: _handleForgotPassword,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 16),

                // Back to login
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver al inicio de sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
