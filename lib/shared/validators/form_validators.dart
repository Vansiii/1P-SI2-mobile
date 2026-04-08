import '../../core/config/app_constants.dart';

/// Form Validators - Validadores de formularios
class FormValidators {
  // Email validator
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo electrónico es requerido';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Ingresa un correo electrónico válido';
    }

    return null;
  }

  // Password validator - Validación básica, el backend valida los requisitos completos
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }

    if (value.length < AppConstants.minPasswordLength) {
      return 'La contraseña debe tener al menos ${AppConstants.minPasswordLength} caracteres';
    }

    if (value.length > AppConstants.maxPasswordLength) {
      return 'La contraseña no puede exceder ${AppConstants.maxPasswordLength} caracteres';
    }

    // El backend validará los requisitos de complejidad (mayúsculas, minúsculas, números, caracteres especiales)
    // y mostrará el error en el snackbar si no cumple

    return null;
  }

  // Required field validator
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Este campo'} es requerido';
    }
    return null;
  }

  // CI validator (Bolivia)
  static String? ci(String? value) {
    if (value == null || value.isEmpty) {
      return 'La cédula de identidad es requerida';
    }

    // Remover espacios y guiones
    final cleanValue = value.replaceAll(RegExp(r'[\s-]'), '');

    // Validar formato básico (números y letras)
    if (cleanValue.length < 5 || cleanValue.length > 20) {
      return 'Ingresa una cédula de identidad válida';
    }

    return null;
  }

  // OTP validator
  static String? otp(String? value) {
    if (value == null || value.isEmpty) {
      return 'El código es requerido';
    }

    if (value.length != AppConstants.otpLength) {
      return 'El código debe tener ${AppConstants.otpLength} dígitos';
    }

    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'El código solo debe contener números';
    }

    return null;
  }

  // Confirm password validator
  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  // Address validator
  static String? address(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La dirección es requerida';
    }

    if (value.trim().length < 5) {
      return 'Ingresa una dirección válida';
    }

    return null;
  }

  // Date validator
  static String? birthDate(DateTime? value) {
    if (value == null) {
      return 'La fecha de nacimiento es requerida';
    }

    final now = DateTime.now();
    final age = now.year - value.year;

    if (age < 18) {
      return 'Debes ser mayor de 18 años';
    }

    if (age > 120) {
      return 'Ingresa una fecha válida';
    }

    return null;
  }

  // Name validator
  static String? name(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'El nombre'} es requerido';
    }

    if (value.trim().length < 2) {
      return '${fieldName ?? 'El nombre'} debe tener al menos 2 caracteres';
    }

    if (value.trim().length > 60) {
      return '${fieldName ?? 'El nombre'} no puede exceder 60 caracteres';
    }

    // Solo letras, espacios y algunos caracteres especiales
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(value)) {
      return '${fieldName ?? 'El nombre'} solo puede contener letras';
    }

    return null;
  }

  // Phone validator
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es requerido';
    }

    // Remover espacios, guiones y paréntesis
    final cleanValue = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Validar que solo contenga números y opcionalmente un + al inicio
    if (!RegExp(r'^\+?\d+$').hasMatch(cleanValue)) {
      return 'Ingresa un número de teléfono válido';
    }

    // Validar longitud (mínimo 7, máximo 15 dígitos)
    final digitsOnly = cleanValue.replaceAll('+', '');
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return 'Ingresa un número de teléfono válido';
    }

    return null;
  }
}
