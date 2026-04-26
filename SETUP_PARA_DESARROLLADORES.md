# Setup para Desarrolladores - MecánicoYa Mobile

Guía completa para configurar el entorno de desarrollo de la aplicación móvil Flutter.

## 📋 Requisitos Previos

### Software Necesario

1. **Flutter SDK 3.8.1+**
   - Descarga: https://docs.flutter.dev/get-started/install
   - Verifica: `flutter --version`

2. **Dart SDK** (incluido con Flutter)
   - Verifica: `dart --version`

3. **Android Studio** (para desarrollo Android)
   - Descarga: https://developer.android.com/studio
   - Incluye: Android SDK, Android Emulator

4. **Xcode** (para desarrollo iOS - solo macOS)
   - Descarga desde Mac App Store
   - Incluye: iOS Simulator, CocoaPods

5. **Git**
   - Descarga: https://git-scm.com/
   - Verifica: `git --version`

6. **Editor de Código**
   - VS Code (recomendado): https://code.visualstudio.com/
   - Android Studio también funciona

### Extensiones VS Code (Recomendadas)

- Flutter (Dart-Code.flutter)
- Dart (Dart-Code.dart-code)
- Flutter Widget Snippets
- Pubspec Assist
- Error Lens

---

## 🚀 Instalación Paso a Paso

### 1. Clonar el Repositorio

```bash
# Clona el repositorio completo
git clone https://github.com/TU_USUARIO/1P-SI2.git
cd 1P-SI2/1P-SI2-mobile
```

### 2. Verificar Flutter

```bash
# Verifica que Flutter esté correctamente instalado
flutter doctor

# Deberías ver algo como:
# [✓] Flutter (Channel stable, 3.8.1)
# [✓] Android toolchain
# [✓] Xcode (solo macOS)
# [✓] VS Code
```

Si hay problemas, sigue las instrucciones de `flutter doctor`.

### 3. Instalar Dependencias

```bash
# Instala todas las dependencias del proyecto
flutter pub get
```

### 4. Configurar Variables de Entorno

```bash
# Copia el archivo de ejemplo
cp .env.example .env.development
```

Edita `.env.development` con tus valores:

```env
ENVIRONMENT=development
API_BASE_URL=http://localhost:8000
ENABLE_LOGGING=true
ENABLE_DEBUG_BANNER=true
CONNECT_TIMEOUT=120
RECEIVE_TIMEOUT=120
```

**IMPORTANTE**: 
- Si usas un dispositivo físico, cambia `localhost` por la IP de tu computadora
- Ejemplo: `API_BASE_URL=http://192.168.1.100:8000`
- Para encontrar tu IP:
  - Windows: `ipconfig`
  - macOS/Linux: `ifconfig` o `ip addr`

### 5. Configurar Firebase (Opcional para desarrollo local)

Si necesitas notificaciones push en desarrollo:

#### Android

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Crea/selecciona tu proyecto
3. Agrega una app Android
4. Descarga `google-services.json`
5. Colócalo en `android/app/google-services.json`

#### iOS (solo macOS)

1. En Firebase Console, agrega una app iOS
2. Descarga `GoogleService-Info.plist`
3. Colócalo en `ios/Runner/GoogleService-Info.plist`

**NOTA**: Estos archivos NO deben subirse a Git (ya están en `.gitignore`)

### 6. Configurar Emuladores/Simuladores

#### Android Emulator

1. Abre Android Studio
2. Tools > Device Manager
3. Create Device
4. Selecciona un dispositivo (ej: Pixel 5)
5. Descarga una imagen del sistema (ej: Android 13)
6. Finish

Inicia el emulador:
```bash
# Lista emuladores disponibles
flutter emulators

# Inicia un emulador
flutter emulators --launch <emulator_id>
```

#### iOS Simulator (solo macOS)

```bash
# Abre el simulador
open -a Simulator

# O desde Xcode: Xcode > Open Developer Tool > Simulator
```

---

## 🏃 Ejecutar la Aplicación

### Opción 1: Desde Terminal

```bash
# Ver dispositivos disponibles
flutter devices

# Ejecutar en el dispositivo conectado
flutter run

# Ejecutar en un dispositivo específico
flutter run -d <device_id>

# Ejecutar en modo release (más rápido)
flutter run --release
```

### Opción 2: Desde VS Code

1. Abre el proyecto en VS Code
2. Selecciona un dispositivo en la barra inferior
3. Presiona F5 o Run > Start Debugging

### Opción 3: Desde Android Studio

1. Abre el proyecto
2. Selecciona un dispositivo en la barra superior
3. Click en el botón Run (▶️)

---

## 🔧 Comandos Útiles

### Desarrollo

```bash
# Hot reload (r en la terminal mientras corre)
r

# Hot restart (R en la terminal)
R

# Limpiar build cache
flutter clean

# Reinstalar dependencias
flutter pub get

# Actualizar dependencias
flutter pub upgrade

# Analizar código
flutter analyze

# Formatear código
dart format .
```

### Testing

```bash
# Ejecutar todos los tests
flutter test

# Ejecutar tests con coverage
flutter test --coverage

# Ejecutar un test específico
flutter test test/widget_test.dart
```

### Build

```bash
# Build APK (Android)
flutter build apk

# Build AAB (Android - Play Store)
flutter build appbundle

# Build iOS (solo macOS)
flutter build ios
```

---

## 📁 Estructura del Proyecto

```
lib/
├── core/                      # Núcleo de la aplicación
│   ├── config/               # Configuración (environment, API)
│   ├── theme/                # Tema visual (colores, tipografía)
│   └── router/               # Navegación (GoRouter)
│
├── data/                      # Capa de datos
│   ├── models/               # Modelos de datos (User, Service, etc.)
│   ├── repositories/         # Repositorios (abstracción de datos)
│   └── services/             # Servicios API (HTTP calls)
│
├── features/                  # Funcionalidades por módulo
│   ├── auth/                 # Autenticación (login, register, 2FA)
│   ├── profile/              # Perfil de usuario
│   ├── security/             # Seguridad (cambio contraseña, 2FA)
│   └── home/                 # Dashboard principal
│
├── shared/                    # Componentes compartidos
│   ├── widgets/              # Widgets reutilizables
│   └── validators/           # Validadores de formularios
│
└── main.dart                  # Punto de entrada
```

---

## 🎨 Convenciones de Código

### Naming

- **Archivos**: `snake_case.dart`
- **Clases**: `PascalCase`
- **Variables/Funciones**: `camelCase`
- **Constantes**: `camelCase` o `UPPER_CASE`
- **Privados**: `_prefixWithUnderscore`

### Ejemplos

```dart
// ✅ Correcto
class UserProfile { }
final userName = 'John';
const maxRetries = 3;
void _privateMethod() { }

// ❌ Incorrecto
class user_profile { }
final UserName = 'John';
const MAX_RETRIES = 3;
void PrivateMethod() { }
```

### Organización de Imports

```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter SDK
import 'package:flutter/material.dart';

// 3. Packages externos
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 4. Archivos locales
import '../models/user.dart';
import '../services/api_service.dart';
```

---

## 🐛 Debugging

### Hot Reload vs Hot Restart

- **Hot Reload (r)**: Actualiza UI sin perder estado
- **Hot Restart (R)**: Reinicia app, pierde estado

### DevTools

```bash
# Abrir DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

Funcionalidades:
- Inspector de widgets
- Timeline de performance
- Memory profiler
- Network inspector
- Logging

### Print Debugging

```dart
// Simple print
print('Debug: $variable');

// Debug print (solo en debug mode)
debugPrint('Debug: $variable');

// Logger (mejor para producción)
import 'package:logger/logger.dart';
final logger = Logger();
logger.d('Debug message');
logger.e('Error message');
```

---

## 🔐 Seguridad

### Archivos Sensibles (NO subir a Git)

- `.env.development`
- `.env.production`
- `.env.local`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `android/key.properties`
- `*.jks` (keystores)

Estos archivos ya están en `.gitignore`.

### Almacenamiento Seguro

```dart
// Usar flutter_secure_storage para tokens
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// Guardar
await storage.write(key: 'token', value: 'jwt_token');

// Leer
final token = await storage.read(key: 'token');

// Eliminar
await storage.delete(key: 'token');
```

---

## 🧪 Testing

### Tipos de Tests

1. **Unit Tests**: Lógica de negocio
2. **Widget Tests**: UI components
3. **Integration Tests**: Flujos completos

### Ejemplo Unit Test

```dart
// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService', () {
    test('login should return user on success', () async {
      // Arrange
      final service = AuthService();
      
      // Act
      final result = await service.login('email', 'password');
      
      // Assert
      expect(result, isNotNull);
    });
  });
}
```

---

## 📚 Recursos Útiles

### Documentación

- [Flutter Docs](https://docs.flutter.dev/)
- [Dart Docs](https://dart.dev/guides)
- [Riverpod Docs](https://riverpod.dev/)
- [Dio Docs](https://pub.dev/packages/dio)

### Comunidad

- [Flutter Discord](https://discord.gg/flutter)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
- [Reddit r/FlutterDev](https://www.reddit.com/r/FlutterDev/)

### Tutoriales

- [Flutter Codelabs](https://docs.flutter.dev/codelabs)
- [Flutter YouTube Channel](https://www.youtube.com/c/flutterdev)

---

## 🆘 Troubleshooting

### Error: "Gradle build failed"

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### Error: "CocoaPods not installed" (macOS)

```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
flutter run
```

### Error: "Unable to locate Android SDK"

1. Abre Android Studio
2. Tools > SDK Manager
3. Instala Android SDK
4. Configura ANDROID_HOME en variables de entorno

### Error: "Xcode not found" (macOS)

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### App no conecta al backend

1. Verifica que el backend esté corriendo
2. Verifica la URL en `.env.development`
3. Si usas dispositivo físico, usa IP en lugar de localhost
4. Verifica firewall/antivirus

---

## 🤝 Contribuir

### Workflow

1. Crea una rama desde `develop`:
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/mi-feature
   ```

2. Haz tus cambios y commits:
   ```bash
   git add .
   git commit -m "feat: descripción del cambio"
   ```

3. Push y crea Pull Request:
   ```bash
   git push origin feature/mi-feature
   ```

### Convenciones de Commits

- `feat:` Nueva funcionalidad
- `fix:` Corrección de bug
- `docs:` Cambios en documentación
- `style:` Formato de código
- `refactor:` Refactorización
- `test:` Tests
- `chore:` Tareas de mantenimiento

---

## 📞 Contacto

¿Problemas con el setup? Contacta al equipo:

- **Backend**: [Responsable Backend]
- **Mobile**: [Responsable Mobile]
- **DevOps**: [Responsable DevOps]

---

**¡Listo para desarrollar!** 🚀
