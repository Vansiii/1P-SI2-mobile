import 'user_model.dart';

/// Auth Response Model
class AuthResponse {
  final String? accessToken;
  final String? refreshToken;
  final String? tokenType;
  final int? expiresIn;
  final String userType;
  final bool requires2fa;
  final UserModel? user;

  AuthResponse({
    this.accessToken,
    this.refreshToken,
    this.tokenType,
    this.expiresIn,
    required this.userType,
    this.requires2fa = false,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // El backend puede devolver la respuesta en data o directamente
    final data = json['data'] ?? json;

    print('🔍 Parseando AuthResponse...');
    print('🔍 JSON completo: $json');
    print('🔍 Data extraído: $data');
    print('🔍 requires_2fa en data: ${data['requires_2fa']}');

    // Los tokens pueden estar en data.tokens o directamente en data
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final tokenData = tokens ?? data;

    final requires2fa = data['requires_2fa'] as bool? ?? false;
    print('🔍 requires2fa parseado: $requires2fa');

    return AuthResponse(
      accessToken: tokenData['access_token'] as String?,
      refreshToken: tokenData['refresh_token'] as String?,
      tokenType: tokenData['token_type'] as String? ?? 'bearer',
      expiresIn: tokenData['expires_in'] as int?,
      userType:
          data['user_type'] as String? ??
          (data['user'] != null
              ? (data['user'] as Map<String, dynamic>)['user_type'] as String
              : 'client'),
      requires2fa: requires2fa,
      user: data['user'] != null
          ? UserModel.fromJson(data['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (tokenType != null) 'token_type': tokenType,
      if (expiresIn != null) 'expires_in': expiresIn,
      'user_type': userType,
      'requires_2fa': requires2fa,
      if (user != null) 'user': user!.toJson(),
    };
  }
}
