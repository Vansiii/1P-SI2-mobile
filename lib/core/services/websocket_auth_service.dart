import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/config/app_constants.dart';
import 'package:merchanic_repair/core/services/websocket_service.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';

// ── Exceptions ────────────────────────────────────────────────────────────────

/// Typed exception hierarchy for WebSocket authentication errors.
///
/// Requirement 2.2 — authenticate using JWT tokens from secure storage.
sealed class WebSocketAuthException implements Exception {
  const WebSocketAuthException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when no token is found in secure storage (user not logged in).
final class WebSocketAuthNotLoggedInException extends WebSocketAuthException {
  const WebSocketAuthNotLoggedInException()
    : super('No access token found. User is not logged in.');
}

/// Thrown when the token refresh request fails (network error, 401, etc.).
final class WebSocketAuthRefreshFailedException extends WebSocketAuthException {
  const WebSocketAuthRefreshFailedException(super.message);
}

/// Thrown when the token is expired and no refresh token is available.
final class WebSocketAuthTokenExpiredException extends WebSocketAuthException {
  const WebSocketAuthTokenExpiredException()
    : super('Access token is expired and no refresh token is available.');
}

/// Thrown when the JWT payload cannot be decoded.
final class WebSocketAuthInvalidTokenException extends WebSocketAuthException {
  const WebSocketAuthInvalidTokenException(super.message);
}

// ── WebSocketAuthService ──────────────────────────────────────────────────────

/// Provides authenticated WebSocket connections by managing JWT tokens.
///
/// Responsibilities (Requirement 2.2):
/// - Reads the JWT access token from [StorageService] (flutter_secure_storage).
/// - Decodes the JWT payload to check the `exp` claim with a 5-minute buffer.
/// - Attempts a token refresh via the backend `/api/v1/tokens/refresh` endpoint
///   when the access token is expired.
/// - Returns a valid token ready to be passed to [WebSocketService.connect].
/// - Throws typed [WebSocketAuthException] subclasses on failure.
///
/// Usage:
/// ```dart
/// final authService = WebSocketAuthService(storageService);
/// try {
///   final token = await authService.getValidToken();
///   webSocketService.connect('$wsUrl/ws/tracking/$userId', token: token);
/// } on WebSocketAuthException catch (e) {
///   // handle auth error
/// }
/// ```
class WebSocketAuthService {
  WebSocketAuthService(this._storage);

  final StorageService _storage;

  /// Buffer applied before the token's `exp` claim to trigger early refresh.
  static const Duration _expiryBuffer = Duration(minutes: 5);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a valid JWT access token, refreshing it if necessary.
  ///
  /// Throws a [WebSocketAuthException] subclass when authentication fails.
  Future<String> getValidToken() async {
    final accessToken = await _storage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      throw const WebSocketAuthNotLoggedInException();
    }

    if (!_isTokenExpired(accessToken)) {
      return accessToken;
    }

    debugPrint(
      '[WebSocketAuthService] Access token expired — attempting refresh.',
    );
    return _refreshToken();
  }

  /// Connects [webSocketService] to [endpoint] with a valid JWT token.
  ///
  /// Convenience wrapper that calls [getValidToken] and then
  /// [WebSocketService.connect].
  ///
  /// Throws a [WebSocketAuthException] if authentication fails.
  Future<void> connectAuthenticated(
    WebSocketService webSocketService,
    String endpoint,
  ) async {
    final token = await getValidToken();
    webSocketService.connect(endpoint, token: token);
  }

  // ── JWT helpers ────────────────────────────────────────────────────────────

  /// Returns `true` when [token] is expired (accounting for [_expiryBuffer]).
  ///
  /// Returns `false` if the token cannot be decoded — the caller will attempt
  /// to use it and let the server reject it if truly invalid.
  bool _isTokenExpired(String token) {
    try {
      final payload = _decodePayload(token);
      final exp = payload['exp'];
      if (exp == null) return false;

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (exp as int) * 1000,
        isUtc: true,
      );
      final threshold = DateTime.now().toUtc().add(_expiryBuffer);
      return expiry.isBefore(threshold);
    } on WebSocketAuthInvalidTokenException {
      // Cannot decode — treat as not expired; server will validate.
      return false;
    }
  }

  /// Decodes the JWT payload section (base64url) and returns it as a map.
  ///
  /// Throws [WebSocketAuthInvalidTokenException] if the token is malformed.
  Map<String, dynamic> _decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw WebSocketAuthInvalidTokenException(
        'Malformed JWT: expected 3 parts, got ${parts.length}.',
      );
    }

    try {
      // Base64url → base64 padding normalisation.
      var payload = parts[1];
      final remainder = payload.length % 4;
      if (remainder != 0) {
        payload = payload.padRight(payload.length + (4 - remainder), '=');
      }
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');

      final decoded = utf8.decode(base64.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      throw WebSocketAuthInvalidTokenException(
        'Failed to decode JWT payload: $e',
      );
    }
  }

  // ── Token refresh ──────────────────────────────────────────────────────────

  /// Calls the backend refresh endpoint and persists the new tokens.
  ///
  /// Returns the new access token on success.
  /// Throws [WebSocketAuthTokenExpiredException] when no refresh token exists.
  /// Throws [WebSocketAuthRefreshFailedException] on network/server errors.
  Future<String> _refreshToken() async {
    final refreshToken = await _storage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw const WebSocketAuthTokenExpiredException();
    }

    final url = Uri.parse(
      '${ApiConfig.baseUrl}${AppConstants.refreshTokenPath}',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        // Backend wraps data in a `data` key.
        final data = (body['data'] ?? body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken == null || newAccessToken.isEmpty) {
          throw const WebSocketAuthRefreshFailedException(
            'Refresh response did not contain an access token.',
          );
        }

        await _storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? refreshToken,
        );

        debugPrint('[WebSocketAuthService] Token refreshed successfully.');
        return newAccessToken;
      }

      if (response.statusCode == 401) {
        // Refresh token itself is expired — clear storage.
        await _storage.clearTokens();
        throw const WebSocketAuthRefreshFailedException(
          'Refresh token is invalid or expired. Please log in again.',
        );
      }

      throw WebSocketAuthRefreshFailedException(
        'Token refresh failed with status ${response.statusCode}.',
      );
    } on WebSocketAuthException {
      rethrow;
    } catch (e) {
      throw WebSocketAuthRefreshFailedException(
        'Network error during token refresh: $e',
      );
    }
  }
}
