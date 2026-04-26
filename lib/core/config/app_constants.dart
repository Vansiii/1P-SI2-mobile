/// Application Constants
class AppConstants {
  // App Info
  static const String appName = 'MecánicoYa';
  static const String appVersion = '1.0.0';
  static const String appLogoAsset = 'assets/images/logo.png';

  // API Paths
  static const String refreshTokenPath = '/api/v1/tokens/refresh';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userTypeKey = 'user_type';
  static const String userDataKey = 'user_data';

  // User Types
  static const String userTypeClient = 'client';
  static const String userTypeWorkshop = 'workshop';
  static const String userTypeTechnician = 'technician';
  static const String userTypeAdmin = 'administrator';

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int otpLength = 6;

  // UI
  static const double borderRadius = 8.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 52.0;
}
