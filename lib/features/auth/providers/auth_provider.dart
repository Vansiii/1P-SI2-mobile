import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/websocket/connection_status.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../services/technician_location_service.dart';
import '../../../services/websocket_service.dart';
import '../../incidents/services/incident_realtime_service.dart';
import '../../incidents/services/cancellation_realtime_service.dart';
import '../../technicians/data/models/technician_model.dart';
import '../../technicians/providers/technicians_websocket_provider.dart';
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
    _syncTechnicianIncidentToLocationService();
  }

  /// Watch the technicians WebSocket provider and sync the current incident ID
  /// to the location service so the technician sends location via WS correctly.
  void _syncTechnicianIncidentToLocationService() {
    _ref.listen<List<TechnicianModel>>(
      techniciansWebSocketProvider,
      (prev, next) {
        final user = state.user;
        if (user == null || user.userType != 'technician') return;

        // Find the current technician in the list
        for (final tech in next) {
          if (tech.id == user.id && tech.currentIncidentId != null) {
            _locationService.currentIncidentId = tech.currentIncidentId;
            return;
          }
        }
        // No active incident found
        _locationService.currentIncidentId = null;
      },
    );
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
        // Conectar WebSocket al restaurar sesión
        if (user != null) {
          await _connectWebSocket(user);
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

      // ✅ Conectar WebSocket después del login exitoso
      await _connectWebSocket(fullUser);

      // ✅ Inicializar servicio de eventos en tiempo real para incidentes
      // Solo para administradores que necesitan recibir notificaciones de nuevos incidentes
      if (fullUser.userType == 'administrator') {
        _initializeIncidentRealtimeService();
        _initializeCancellationRealtimeService();
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

      // ✅ Conectar WebSocket con datos básicos si falla el perfil completo
      if (response.user != null) {
        await _connectWebSocket(response.user!);

        // ✅ Inicializar servicio de eventos en tiempo real para incidentes
        // Solo para administradores
        if (response.user!.userType == 'administrator') {
          _initializeIncidentRealtimeService();
          _initializeCancellationRealtimeService();
        }
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

  // ✅ Conectar WebSocket al autenticar usuario
  Future<void> _connectWebSocket(UserModel user) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null || token.isEmpty) return;

      final wsService = _ref.read(webSocketServiceProvider);

      // ✅ Registrar callback de refresh token
      wsService.setTokenRefreshCallback(() async {
        print('🔄 WebSocket: Token refresh callback invoked');
        final newToken = await _authRepository.refreshAccessToken();
        if (newToken != null) {
          print('✅ WebSocket: Token refreshed successfully');
        } else {
          print('❌ WebSocket: Token refresh failed');
        }
        return newToken;
      });

      // ✅ Registrar callback de sesión expirada
      wsService.setSessionExpiredCallback(() {
        print('🚫 WebSocket: Session expired - logging out');
        logout();
      });

      final endpoint = '/api/v1/ws/tracking/${user.id}';
      wsService.connect(endpoint, token: token);

      // Wire up WebSocket sender for TechnicianLocationService real-time delivery
      if (user.userType == 'technician') {
        _locationService.setWebSocketSender((message) {
          if (wsService.isConnected) {
            wsService.send(message);
            return true;
          }
          return false;
        });
        print('🔗 AuthNotifier: WebSocket sender wired for technician location');

        // Listen for WebSocket disconnects to clear the sender for HTTP fallback
        wsService.connectionStatus.listen((status) {
          if (status == ConnectionStatus.disconnected) {
            print(
              '🔌 WebSocket disconnected — clearing location sender (HTTP fallback active)',
            );
            _locationService.clearWebSocketSender();
          }
        });
      }

      print(
        '✅ AuthNotifier: WebSocket conectado para usuario ${user.id} (${user.userType})',
      );
    } catch (e) {
      print('❌ AuthNotifier: Error conectando WebSocket: $e');
      // No lanzar error para no interrumpir el flujo de login
    }
  }

  // ✅ Inicializar servicio de eventos en tiempo real para incidentes
  void _initializeIncidentRealtimeService() {
    try {
      // El servicio se inicializa automáticamente al ser leído por primera vez
      // gracias al provider que llama a initialize() en su constructor
      _ref.read(incidentRealtimeServiceProvider);
      print('✅ AuthNotifier: Incident realtime service initialized');
    } catch (e) {
      print('❌ AuthNotifier: Error initializing incident realtime service: $e');
      // No lanzar error para no interrumpir el flujo de login
    }
  }

  // ✅ Inicializar servicio de eventos en tiempo real para cancelaciones
  void _initializeCancellationRealtimeService() {
    try {
      // El servicio se inicializa automáticamente al ser leído por primera vez
      // gracias al provider que llama a initialize() en su constructor
      _ref.read(cancellationRealtimeServiceProvider);
      print('✅ AuthNotifier: Cancellation realtime service initialized');
    } catch (e) {
      print(
        '❌ AuthNotifier: Error initializing cancellation realtime service: $e',
      );
      // No lanzar error para no interrumpir el flujo de login
    }
  }

  // ✅ Desconectar WebSocket al hacer logout
  void _disconnectWebSocket() {
    try {
      final wsService = _ref.read(webSocketServiceProvider);
      _locationService.clearWebSocketSender();
      wsService.disconnect();
      print('✅ AuthNotifier: WebSocket desconectado');
    } catch (e) {
      print('❌ AuthNotifier: Error desconectando WebSocket: $e');
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

      // ✅ Desconectar WebSocket antes del logout
      _disconnectWebSocket();

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
