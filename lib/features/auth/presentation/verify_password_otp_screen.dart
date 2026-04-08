import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';

class VerifyPasswordOtpScreen extends StatefulWidget {
  final String email;

  const VerifyPasswordOtpScreen({super.key, required this.email});

  @override
  State<VerifyPasswordOtpScreen> createState() =>
      _VerifyPasswordOtpScreenState();
}

class _VerifyPasswordOtpScreenState extends State<VerifyPasswordOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepository = AuthRepository(
        ApiService(StorageService()),
        StorageService(),
      );

      final resetToken = await authRepository.verifyPasswordOtp(
        widget.email,
        _otpController.text.trim(),
      );

      if (!mounted) return;

      // Mostrar mensaje de éxito
      SnackBarUtils.showSuccess(null, 'Código verificado correctamente');

      // Navegar a pantalla de nueva contraseña
      context.pushReplacementNamed(
        'reset-password',
        pathParameters: {'token': resetToken},
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

  Future<void> _handleResendCode() async {
    setState(() => _isLoading = true);

    try {
      final authRepository = AuthRepository(
        ApiService(StorageService()),
        StorageService(),
      );

      await authRepository.forgotPasswordMobile(widget.email);

      if (!mounted) return;

      SnackBarUtils.showInfo(
        null,
        'Código reenviado. Revisa tu correo electrónico',
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
        title: const Text('Verificar Código'),
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
                    Icons.verified_user,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Ingresa el código',
                  style: Theme.of(context).textTheme.displayMedium,
                ),

                const SizedBox(height: 8),

                Text(
                  'Hemos enviado un código de 6 dígitos a ${widget.email}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),

                const SizedBox(height: 32),

                // OTP field
                CustomTextField(
                  controller: _otpController,
                  label: 'Código de verificación',
                  hint: '123456',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.pin_outlined),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa el código';
                    }
                    if (value.length != 6) {
                      return 'El código debe tener 6 dígitos';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Verify button
                PrimaryButton(
                  text: 'Verificar código',
                  onPressed: _handleVerifyOtp,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 16),

                // Resend code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No recibiste el código? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _handleResendCode,
                      child: const Text('Reenviar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
