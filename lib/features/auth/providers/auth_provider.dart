import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../services/technician_location_service.dart';
import 'push_token_provider.dart';

// Providers
final storageServiceProvider = Provider((ref) => StorageService());

final apiServiceProvider = Provider((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ApiService(storageService);
});

final authRepositoryProvider = Provider((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AuthRepository(apiService, storageService);
});

final technicianLocationServiceProvider = Provider((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return TechnicianLocationService(apiService);
});

// Auth State
class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Auth Provider
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final StorageService _storageService;
  final TechnicianLocationService _locationService;
  final Ref _ref;

  AuthNotifier(
    this._authRepository,
    this._storageService,
    this._locationService,
    this._ref,
  ) : super(AuthState()) {
    _checkAuthStatus();
  }

  // Check auth status on init
  Future<void> _checkAuthStatus() async {
    if (mounted) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final isAuth = await _storageService.isAuthenticated();
      if (isAuth) {
        final user = await _storageService.getUserData();
        if (mounted) {
          state = state.copyWith(
            isAuthenticated: true,
            user: user,
            isLoading: false,
          );
        }
      } else {
        if (mounted) {
          state = state.copyWith(isLoading: false);
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  // Login
  // Tipos de usuario permitidos en app móvil: client, technician, administrator
  Future<AuthResponse> login(String email, String password) async {
    if (mounted) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _authRepository.login(
        email: email,
        password: password,
      );

      if (!response.requires2fa) {
        // Login sin 2FA - autenticar inmediatamente
        await _authenticateUser(response);
      } else {
        // Si requiere 2FA, NO actualizar el estado de autenticación
        // Solo quitar el loading para permitir la navegación
        if (mounted) {
          state = state.copyWith(isLoading: false);
        }
      }

      return response;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      rethrow;
    }
  }

  // Verify 2FA
  Future<AuthResponse> verify2FA(String email, String otpCode) async {
    if (mounted) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _authRepository.verify2FA(
        email: email,
        otpCode: otpCode,
      );

      // Login con 2FA exitoso - autenticar
      await _authenticateUser(response);

      return response;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      rethrow;
    }
  }

  // Método privado para autenticar usuario y obtener perfil completo
  Future<void> _authenticateUser(AuthResponse response) async {
    // VALIDACIÓN: Clientes y técnicos pueden usar la app móvil
    final allowedTypes = ['client', 'technician'];
    if (response.user?.userType != null &&
        !allowedTypes.contains(response.user!.userType)) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
      throw Exception(
        'Esta aplicación es para clientes y técnicos. '
        'Si eres administrador o taller, por favor usa la plataforma web.',
      );
    }

    // Obtener el perfil completo del usuario
    // Los endpoints de login y verify-2fa pueden no devolver todos los campos
    try {
      final fullUser = await _authRepository.getProfile();

      if (mounted) {
        state = state.copyWith(
          isAuthenticated: true,
          user: fullUser,
          isLoading: false,
        );
      }

      // Si el usuario es técnico, iniciar seguimiento de ubicación
      if (fullUser.userType == 'technician') {
        await _startTechnicianLocationTracking();
      }

      // Registrar token FCM después del login exitoso
      await _registerPushToken();
    } catch (profileError) {
      // Si falla obtener el perfil, usar los datos básicos de la respuesta

      if (mounted) {
        state = state.copyWith(
          isAuthenticated: true,
          user: response.user,
          isLoading: false,
        );
      }

      // Si el usuario es técnico, iniciar seguimiento de ubicación
      if (response.user?.userType == 'technician') {
        await _startTechnicianLocationTracking();
      }

      // Registrar token FCM después del login exitoso
      await _registerPushToken();
    }
  }

  // Iniciar seguimiento de ubicación para técnicos
  Future<void> _startTechnicianLocationTracking() async {
    try {
      print(
        '🚀 AuthNotifier: Intentando iniciar seguimiento de ubicación para técnico',
      );
      final success = await _locationService.startContinuousTracking();
      if (success) {
        print('✅ AuthNotifier: Seguimiento de ubicación iniciado para técnico');
      } else {
        print('❌ AuthNotifier: No se pudo iniciar seguimiento de ubicación');
      }
    } catch (e) {
      print('❌ AuthNotifier: Error al iniciar seguimiento de ubicación: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Registrar token FCM después del login
  Future<void> _registerPushToken() async {
    try {
      final pushTokenManager = _ref.read(pushTokenManagerProvider);
      await pushTokenManager.registerTokenAfterLogin();
    } catch (e) {
      print('❌ AuthNotifier: Error registrando token FCM: $e');
      // No lanzar error para no interrumpir el flujo de login
    }
  }

  // Desregistrar tokens FCM antes del logout
  Future<void> _unregisterPushTokens() async {
    try {
      final pushTokenManager = _ref.read(pushTokenManagerProvider);
      await pushTokenManager.unregisterAllTokensOnLogout();
    } catch (e) {
      print('❌ AuthNotifier: Error desregistrando tokens FCM: $e');
      // No lanzar error para no interrumpir el flujo de logout
    }
  }

  // Register Client
  // NOTA: Solo los clientes pueden registrarse desde la app móvil
  // Los técnicos, talleres y administradores se registran desde la plataforma web
  // IMPORTANTE: El registro NO inicia sesión automáticamente, el usuario debe hacer login después
  Future<AuthResponse> registerClient({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String direccion,
    required String ci,
    required DateTime fechaNacimiento,
  }) async {
    if (mounted) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _authRepository.registerClient(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        direccion: direccion,
        ci: ci,
        fechaNacimiento: fechaNacimiento,
      );

      // NO autenticar automáticamente después del registro
      // El usuario debe iniciar sesión manualmente
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }

      return response;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    if (mounted) {
      state = state.copyWith(isLoading: true);
    }

    try {
      // Desregistrar tokens FCM antes del logout
      await _unregisterPushTokens();

      // Detener seguimiento de ubicación si está activo
      if (_locationService.isTracking) {
        await _locationService.stopContinuousTracking();
        print('AuthNotifier: Seguimiento de ubicación detenido');
      }

      await _authRepository.logout();
      if (mounted) {
        state = AuthState();
      }
    } catch (e) {
      if (mounted) {
        state = AuthState();
      }
    }
  }

  // Refresh profile
  Future<void> refreshProfile() async {
    try {
      final user = await _authRepository.getProfile();
      if (mounted) {
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // Handle error silently
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final storageService = ref.watch(storageServiceProvider);
  final locationService = ref.watch(technicianLocationServiceProvider);
  return AuthNotifier(authRepository, storageService, locationService, ref);
});
