import 'package:dio/dio.dart';
import '../../core/config/api_config.dart';
import '../../core/services/data_cache.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Auth Repository - Manejo de autenticación
class AuthRepository {
  final ApiService _apiService;
  final StorageService _storageService;

  AuthRepository(this._apiService, this._storageService);

  /// Login unificado
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Intentando login para: $email');
      final response = await _apiService.post(
        '${ApiConfig.auth}/login',
        data: {'email': email, 'password': password},
      );

      print('📥 Respuesta recibida: $response');
      final authResponse = AuthResponse.fromJson(response);

      // Si no requiere 2FA, guardar tokens
      if (!authResponse.requires2fa &&
          authResponse.accessToken != null &&
          authResponse.refreshToken != null) {
        await _storageService.saveTokens(
          accessToken: authResponse.accessToken!,
          refreshToken: authResponse.refreshToken!,
        );
        await _storageService.saveUserType(authResponse.userType);

        if (authResponse.user != null) {
          await _storageService.saveUserData(authResponse.user!);
        }
      }

      return authResponse;
    } on DioException catch (e) {
      print('🚨 DioException capturado: ${e.response?.statusCode}');
      print('🚨 Datos del error: ${e.response?.data}');
      final errorMessage = _handleError(e);
      print('🚨 Mensaje de error procesado: $errorMessage');
      throw errorMessage;
    } catch (e) {
      print('🚨 Excepción general: $e');
      rethrow;
    }
  }

  /// Verificar 2FA
  Future<AuthResponse> verify2FA({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.auth}/login/verify-2fa',
        data: {'email': email, 'otp_code': otpCode},
      );

      final authResponse = AuthResponse.fromJson(response);

      // Guardar tokens después de 2FA exitoso
      if (authResponse.accessToken != null &&
          authResponse.refreshToken != null) {
        await _storageService.saveTokens(
          accessToken: authResponse.accessToken!,
          refreshToken: authResponse.refreshToken!,
        );
        await _storageService.saveUserType(authResponse.userType);

        if (authResponse.user != null) {
          await _storageService.saveUserData(authResponse.user!);
        }
      }

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Registro de cliente
  /// IMPORTANTE: NO guarda tokens ni inicia sesión automáticamente
  /// El usuario debe hacer login después del registro
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
    try {
      final response = await _apiService.post(
        '${ApiConfig.auth}/register/client',
        data: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'direccion': direccion,
          'ci': ci,
          'fecha_nacimiento': fechaNacimiento.toIso8601String(),
        },
      );

      final authResponse = AuthResponse.fromJson(response);

      // NO guardar tokens después del registro
      // El usuario debe iniciar sesión manualmente para obtener los tokens

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtener perfil
  Future<UserModel> getProfile() async {
    try {
      print('🔍 Obteniendo perfil del usuario...');
      final response = await _apiService.getRaw('${ApiConfig.auth}/me');
      final userData = (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;

      final user = UserModel.fromJson(userData);
      await _storageService.saveUserData(user);
      DataCache.put('profile', userData);

      print('✅ Perfil cargado exitosamente');
      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          (e.response?.statusCode == 0)) {
        final cached = DataCache.get('profile');
        if (cached != null && cached is Map) {
          return UserModel.fromJson(Map<String, dynamic>.from(cached));
        }
      }
      print('❌ Error al obtener perfil: ${e.response?.statusCode}');
      throw _handleError(e);
    }
  }

  /// Actualizar perfil
  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      print('📝 Actualizando perfil con datos: $data');
      await _apiService.patch('${ApiConfig.auth}/me', data: data);
      print('✅ Perfil actualizado exitosamente');
    } on DioException catch (e) {
      print('❌ Error al actualizar perfil: ${e.response?.statusCode}');
      print('📛 Datos del error: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _apiService.post('${ApiConfig.auth}/logout');
    } catch (e) {
      // Continuar con logout local aunque falle el servidor
    } finally {
      await _storageService.clearAll();
    }
  }

  /// Refresh access token using refresh token
  Future<String?> refreshAccessToken() async {
    try {
      print('🔄 Refreshing access token...');
      final refreshToken = await _storageService.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ No refresh token available');
        return null;
      }

      final response = await _apiService.post(
        '${ApiConfig.auth}/tokens/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response['data']['access_token'] as String;
      final newRefreshToken = response['data']['refresh_token'] as String?;

      // Save new tokens
      await _storageService.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );

      print('✅ Access token refreshed successfully');
      return newAccessToken;
    } on DioException catch (e) {
      print('❌ Failed to refresh token: ${e.response?.statusCode}');
      print('📛 Error data: ${e.response?.data}');

      // If refresh fails with 401, the refresh token is invalid
      if (e.response?.statusCode == 401) {
        print('🚫 Refresh token expired or invalid - clearing storage');
        await _storageService.clearAll();
      }

      return null;
    } catch (e) {
      print('❌ Unexpected error refreshing token: $e');
      return null;
    }
  }

  /// Solicitar recuperación de contraseña (móvil con OTP)
  Future<String> forgotPasswordMobile(String email) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.password}/forgot-mobile',
        data: {'email': email},
      );

      return response['message'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verificar código OTP de recuperación de contraseña
  Future<String> verifyPasswordOtp(String email, String otpCode) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.password}/verify-otp',
        data: {'email': email, 'otp_code': otpCode},
      );

      return response['data']['reset_token'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Solicitar recuperación de contraseña
  Future<String> forgotPassword(String email) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.password}/forgot',
        data: {'email': email},
      );

      return response['message'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Restablecer contraseña con token
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.password}/reset',
        data: {'token': token, 'new_password': newPassword},
      );

      return response['message'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Cambiar contraseña
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.password}/change',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      return response['message'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reenviar código OTP
  Future<String> resendOTP(String email) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.twoFactor}/resend',
        data: {'email': email},
      );

      return response['message'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtener estado de 2FA
  Future<Map<String, dynamic>> get2FAStatus() async {
    try {
      final response = await _apiService.get('${ApiConfig.twoFactor}/status');
      return response['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Habilitar 2FA
  Future<Map<String, dynamic>> enable2FA() async {
    try {
      final response = await _apiService.post('${ApiConfig.twoFactor}/enable');
      return response['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verificar código OTP para activar 2FA
  Future<Map<String, dynamic>> verify2FAActivation(String otpCode) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.twoFactor}/verify',
        data: {'otp': otpCode},
      );
      return response['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Deshabilitar 2FA
  Future<Map<String, dynamic>> disable2FA(String password) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.twoFactor}/disable',
        data: {'password': password},
      );
      return response['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Eliminar cuenta
  Future<void> deleteAccount(String password) async {
    try {
      await _apiService.delete(
        '${ApiConfig.auth}/me',
        data: {'password': password},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Manejo de errores
  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;

      // Extraer mensaje de error del backend
      if (data is Map<String, dynamic>) {
        // Formato nuevo: {"error": {"message": "...", "code": "..."}}
        if (data['error'] != null && data['error'] is Map<String, dynamic>) {
          final errorData = data['error'] as Map<String, dynamic>;
          if (errorData['message'] != null) {
            return errorData['message'] as String;
          }
        }

        // Formato antiguo: {"detail": "..."} o {"message": "..."}
        if (data['detail'] != null) {
          return data['detail'] as String;
        }
        if (data['message'] != null) {
          return data['message'] as String;
        }
      }

      // Errores HTTP estándar
      switch (error.response!.statusCode) {
        case 400:
          return 'Datos inválidos. Verifica la información ingresada.';
        case 401:
          return 'Credenciales incorrectas.';
        case 403:
          return 'No tienes permisos para realizar esta acción.';
        case 404:
          return 'Recurso no encontrado.';
        case 422:
          return 'Error de validación. Verifica los datos.';
        case 500:
          return 'Error del servidor. Intenta más tarde.';
        default:
          return 'Error inesperado. Intenta nuevamente.';
      }
    }

    // Errores de conexión
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Tiempo de espera agotado. Verifica tu conexión.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Error de conexión. Verifica tu internet.';
    }

    return 'Error de red. Intenta nuevamente.';
  }
}
