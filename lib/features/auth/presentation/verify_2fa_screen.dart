import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/validators/form_validators.dart';
import '../providers/auth_provider.dart';
import '../../../data/repositories/auth_repository.dart';

class Verify2FAScreen extends ConsumerStatefulWidget {
  final String email;

  const Verify2FAScreen({super.key, required this.email});

  @override
  ConsumerState<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends ConsumerState<Verify2FAScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String? _errorMessage;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  String get _otpCode {
    return _controllers.map((c) => c.text).join();
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;
    if (_otpCode.length != 6) {
      setState(() => _errorMessage = 'Ingresa el código completo');
      return;
    }

    setState(() => _errorMessage = null);

    try {
      await ref.read(authProvider.notifier).verify2FA(widget.email, _otpCode);

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      // Llamar al endpoint de reenvío
      await authRepo.resendOTP(widget.email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código reenviado exitosamente'),
          backgroundColor: AppColors.success,
        ),
      );

      _startResendCountdown();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Verificación 2FA'),
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
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Verificación de seguridad',
                  style: Theme.of(context).textTheme.displaySmall,
                ),

                const SizedBox(height: 8),

                Text(
                  'Ingresa el código de 6 dígitos enviado a:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.email,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null) ...[
                  ErrorMessage(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],

                // OTP Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: Theme.of(context).textTheme.headlineMedium,
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }

                          // Auto-submit cuando se completa
                          if (index == 5 && value.isNotEmpty) {
                            _handleVerify();
                          }
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Verify button
                PrimaryButton(
                  text: 'Verificar',
                  onPressed: _handleVerify,
                  isLoading: authState.isLoading,
                  icon: Icons.check_circle_outline,
                ),

                const SizedBox(height: 16),

                // Resend button
                if (_resendCountdown > 0)
                  Center(
                    child: Text(
                      'Reenviar código en $_resendCountdown segundos',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  Center(
                    child: TextButton(
                      onPressed: _isResending ? null : _handleResend,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Reenviar código'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
