import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/validators/form_validators.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../auth/providers/auth_provider.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showSuccess = false;

  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteAccount() async {
    if (!_formKey.currentState!.validate()) return;

    // Mostrar confirmación final
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Estás completamente seguro?'),
        content: const Text(
          'Esta acción es PERMANENTE y NO se puede deshacer. Se eliminarán:\n\n'
          '• Tu perfil y datos personales\n'
          '• Tu historial de servicios\n'
          '• Todas tus sesiones activas\n\n'
          'No podrás recuperar tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sí, eliminar mi cuenta'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.deleteAccount(_passwordController.text);

      if (!mounted) return;

      // Mostrar animación de éxito
      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });

      _successController.forward();

      // Esperar y cerrar sesión
      await Future.delayed(const Duration(milliseconds: 2500));

      if (mounted) {
        await ref.read(authProvider.notifier).logout();
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      SnackBarUtils.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Eliminar cuenta'),
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
                // Warning icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.warning_amber,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Eliminar cuenta',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Esta acción es permanente y no se puede deshacer.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),

                const SizedBox(height: 32),

                // Warning box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Se eliminará permanentemente:',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildWarningItem('Tu perfil y datos personales'),
                      _buildWarningItem('Tu historial de servicios'),
                      _buildWarningItem('Todas tus sesiones activas'),
                      _buildWarningItem('No podrás recuperar tu cuenta'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Password field
                Text(
                  'Confirma tu contraseña',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                CustomTextField(
                  controller: _passwordController,
                  label: 'Contraseña actual',
                  hint: 'Ingresa tu contraseña',
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) => FormValidators.required(
                    value,
                    fieldName: 'La contraseña',
                  ),
                ),

                const SizedBox(height: 32),

                // Delete button
                PrimaryButton(
                  text: 'Eliminar mi cuenta permanentemente',
                  onPressed: _isLoading ? null : _handleDeleteAccount,
                  isLoading: _isLoading,
                  backgroundColor: AppColors.error,
                ),

                const SizedBox(height: 16),

                // Cancel button
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.close, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.info.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Icon(
                      Icons.check,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Cuenta eliminada',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Tu cuenta ha sido eliminada exitosamente.\nGracias por usar nuestros servicios.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              FadeTransition(
                opacity: _fadeAnimation,
                child: const CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
