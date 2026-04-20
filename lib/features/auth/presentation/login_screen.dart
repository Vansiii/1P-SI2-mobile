import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/validators/form_validators.dart';
import '../providers/auth_provider.dart';
import '../../../screens/location_permission_screen.dart';

const String _loginLockoutUntilKey = 'auth_login_lockout_until';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Lockout state
  DateTime? _lockoutUntil;
  int _lockoutRemainingSeconds = 0;
  Timer? _lockoutTimer;
  bool get _isLoginLocked => _lockoutRemainingSeconds > 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
    _restoreLockoutState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _stopLockoutTimer();
    super.dispose();
  }

  Future<void> _restoreLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLockoutUntil = prefs.getString(_loginLockoutUntilKey);

    if (storedLockoutUntil != null) {
      final lockoutUntil = DateTime.tryParse(storedLockoutUntil);
      if (lockoutUntil != null) {
        _activateLockout(lockoutUntil);
      }
    }
  }

  void _activateLockout(DateTime lockoutUntil) {
    if (lockoutUntil.isBefore(DateTime.now())) {
      _clearLockoutState();
      return;
    }

    setState(() {
      _lockoutUntil = lockoutUntil;
    });

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_loginLockoutUntilKey, lockoutUntil.toIso8601String());
    });

    _refreshRemainingLockoutSeconds();
    _startLockoutTimer();
  }

  void _refreshRemainingLockoutSeconds() {
    if (_lockoutUntil == null) {
      setState(() {
        _lockoutRemainingSeconds = 0;
      });
      return;
    }

    final remainingSeconds = _lockoutUntil!
        .difference(DateTime.now())
        .inSeconds;
    setState(() {
      _lockoutRemainingSeconds = remainingSeconds > 0 ? remainingSeconds : 0;
    });

    if (_lockoutRemainingSeconds == 0) {
      _clearLockoutState();
    }
  }

  void _startLockoutTimer() {
    _stopLockoutTimer();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshRemainingLockoutSeconds();
    });
  }

  void _stopLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
  }

  Future<void> _clearLockoutState() async {
    _stopLockoutTimer();
    setState(() {
      _lockoutUntil = null;
      _lockoutRemainingSeconds = 0;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginLockoutUntilKey);
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _navigateToHome() {
    if (!mounted) return;

    final navigator = GoRouter.of(context);
    navigator.go('/home');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('¡Bienvenido de vuelta!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLocationWarning() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'El seguimiento de ubicación no está activo. '
                'El taller no podrá ver tu ubicación en tiempo real.',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Activar',
          textColor: Colors.white,
          onPressed: () async {
            final locationService = ref.read(technicianLocationServiceProvider);
            await locationService.openLocationSettings();
          },
        ),
      ),
    );
  }

  Map<String, dynamic>? _extractLockoutInfo(dynamic error) {
    // Intentar extraer información de bloqueo del error
    if (error is Exception) {
      final errorString = error.toString();

      // Buscar patrón de error de cuenta bloqueada
      if (errorString.contains('ACCOUNT_LOCKED') ||
          errorString.toLowerCase().contains('bloqueada') ||
          errorString.toLowerCase().contains('locked') ||
          errorString.toLowerCase().contains('múltiples intentos')) {
        // Intentar extraer lockout_until o retry_after
        final lockoutUntilMatch = RegExp(
          r'lockout_until["\s:]+([^,}\s]+)',
        ).firstMatch(errorString);
        final retryAfterMatch = RegExp(
          r'retry_after["\s:]+(\d+)',
        ).firstMatch(errorString);
        final remainingSecondsMatch = RegExp(
          r'remaining_seconds["\s:]+(\d+)',
        ).firstMatch(errorString);

        if (lockoutUntilMatch != null) {
          final lockoutUntilStr = lockoutUntilMatch
              .group(1)
              ?.replaceAll('"', '');
          final lockoutUntil = DateTime.tryParse(lockoutUntilStr ?? '');
          if (lockoutUntil != null) {
            return {'lockout_until': lockoutUntil};
          }
        }

        if (retryAfterMatch != null) {
          final retryAfter = int.tryParse(retryAfterMatch.group(1) ?? '');
          if (retryAfter != null) {
            return {'retry_after': retryAfter};
          }
        }

        if (remainingSecondsMatch != null) {
          final remainingSeconds = int.tryParse(
            remainingSecondsMatch.group(1) ?? '',
          );
          if (remainingSeconds != null) {
            return {'retry_after': remainingSeconds};
          }
        }

        // Si no se puede extraer tiempo específico, usar 5 minutos por defecto
        return {'retry_after': 300};
      }
    }

    return null;
  }

  Future<void> _handleLogin() async {
    if (_isLoginLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_clock, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cuenta temporalmente bloqueada. Intenta nuevamente en ${_formatDuration(_lockoutRemainingSeconds)}.',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final response = await ref
          .read(authProvider.notifier)
          .login(email, password);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Limpiar estado de bloqueo si el login es exitoso
      await _clearLockoutState();

      if (!mounted) {
        return;
      }

      if (response.requires2fa) {
        final navigator = GoRouter.of(context);
        navigator.pushNamed('verify-2fa', pathParameters: {'email': email});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.security, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Código de verificación enviado a tu correo'),
                  ),
                ],
              ),
              backgroundColor: AppColors.info,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          // Verificar si el usuario es técnico para solicitar permisos de ubicación
          final authState = ref.read(authProvider);
          final isTechnician = authState.user?.userType == 'technician';

          debugPrint('LoginScreen: Usuario es técnico: $isTechnician');

          if (isTechnician) {
            // Verificar permisos de ubicación
            final locationService = ref.read(technicianLocationServiceProvider);
            final hasPermission = await locationService
                .checkAndRequestPermissions();

            debugPrint('LoginScreen: Tiene permisos: $hasPermission');

            if (!hasPermission) {
              // Mostrar pantalla de permisos
              if (mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LocationPermissionScreen(
                      onPermissionGranted: () {
                        Navigator.of(context).pop();
                        _navigateToHome();
                      },
                      onSkip: () {
                        Navigator.of(context).pop();
                        _navigateToHome();
                        _showLocationWarning();
                      },
                    ),
                  ),
                );
                return; // No navegar automáticamente
              }
            } else {
              _navigateToHome();
            }
          } else {
            _navigateToHome();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Verificar si el error contiene información de bloqueo
      final lockoutInfo = _extractLockoutInfo(e);

      if (lockoutInfo != null) {
        DateTime lockoutUntil;

        if (lockoutInfo.containsKey('lockout_until')) {
          lockoutUntil = lockoutInfo['lockout_until'] as DateTime;
        } else if (lockoutInfo.containsKey('retry_after')) {
          final retryAfter = lockoutInfo['retry_after'] as int;
          lockoutUntil = DateTime.now().add(Duration(seconds: retryAfter));
        } else {
          // Fallback: 5 minutos
          lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
        }

        _activateLockout(lockoutUntil);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu cuenta está bloqueada temporalmente por seguridad. Intenta nuevamente en ${_formatDuration(_lockoutRemainingSeconds)}.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Error normal (no es bloqueo)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.toString())),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),

                        // Logo con animación
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: keyboardVisible ? 72 : 118,
                          child: Center(
                            child: Hero(
                              tag: 'app_logo',
                              child: AppLogo(size: keyboardVisible ? 64 : 104),
                            ),
                          ),
                        ),

                        SizedBox(height: keyboardVisible ? 20 : 40),

                        // Título
                        Text(
                          '¡Bienvenido!',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Inicia sesión para acceder a la plataforma',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // Lockout warning (si está bloqueado) - MOVIDO AQUÍ
                        if (_isLoginLocked)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lock_clock,
                                  color: AppColors.warning,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cuenta bloqueada',
                                        style: TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Intenta nuevamente en ${_formatDuration(_lockoutRemainingSeconds)}',
                                        style: const TextStyle(
                                          color: AppColors.warning,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Email field con animación
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: CustomTextField(
                            controller: _emailController,
                            label: 'Correo electrónico',
                            hint: 'tu@email.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.email_outlined),
                            validator: FormValidators.email,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Password field con animación
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: CustomTextField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            hint: '••••••••',
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            validator: FormValidators.password,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              context.pushNamed('forgot-password');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login button con animación
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: PrimaryButton(
                            text: _isLoginLocked
                                ? 'Bloqueado (${_formatDuration(_lockoutRemainingSeconds)})'
                                : 'Iniciar sesión',
                            onPressed: (_isLoading || _isLoginLocked)
                                ? null
                                : _handleLogin,
                            isLoading: _isLoading,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Para clientes y técnicos',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Info message
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(opacity: value, child: child);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.info,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Accede como cliente para solicitar servicios o como técnico para trabajar.',
                                    style: TextStyle(
                                      color: AppColors.info,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Create account button
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: OutlinedButton(
                            onPressed: () {
                              context.pushNamed('register');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Crear cuenta de cliente',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
