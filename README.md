# Merchanic Repair - Aplicación Móvil

Aplicación móvil profesional para MecanicoYa, desarrollada con Flutter y coherente con el frontend web.

## 🎨 Identidad Visual

### Paleta de Colores
- **Primary**: `#f97316` (Naranja vibrante)
- **Primary Hover**: `#ea580c`
- **Background**: `#f8fafc`
- **Surface**: `#ffffff`
- **Text Main**: `#111827`
- **Text Muted**: `#6b7280`
- **Error**: `#ef4444`

### Tipografía
- **Display** (Títulos): Outfit
- **Body** (Texto): DM Sans

### Estilo
- Moderno, minimalista y profesional
- Bordes redondeados (8px)
- Sombras suaves
- Animaciones sutiles

## 📱 Funcionalidades Implementadas

### Autenticación
- ✅ Login unificado (cliente, mecánico, administrador)
- ✅ Registro de cliente
- ✅ Verificación 2FA
- ✅ Recuperación de contraseña
- ✅ Cambio de contraseña
- ✅ Logout

### Perfil y Seguridad
- ✅ Visualización de perfil
- ✅ Edición de perfil
- ✅ Configuración de seguridad
- ✅ Gestión de 2FA

## 🏗️ Arquitectura

### Estructura de Carpetas

```
lib/
├── core/                      # Núcleo de la aplicación
│   ├── config/               # Configuración (API, constantes)
│   ├── theme/                # Tema visual
│   └── router/               # Navegación
│
├── data/                      # Capa de datos
│   ├── models/               # Modelos de datos
│   ├── repositories/         # Repositorios
│   └── services/             # Servicios API
│
├── features/                  # Funcionalidades por módulo
│   ├── auth/                 # Autenticación
│   ├── profile/              # Perfil
│   ├── security/             # Seguridad
│   └── home/                 # Dashboard
│
├── shared/                    # Componentes compartidos
│   ├── widgets/              # Widgets reutilizables
│   └── validators/           # Validadores
│
└── main.dart                  # Punto de entrada
```

### Principios
- **Separación de responsabilidades**: UI, lógica y datos separados
- **Escalabilidad**: Estructura modular
- **Mantenibilidad**: Código limpio y organizado
- **Reutilización**: Componentes compartidos

## 🔧 Stack Tecnológico

- **Framework**: Flutter 3.8.1+
- **Lenguaje**: Dart
- **Estado**: Riverpod
- **HTTP**: Dio
- **Almacenamiento**: flutter_secure_storage
- **Navegación**: GoRouter
- **UI**: Material Design 3

## 📦 Dependencias

```yaml
dependencies:
  flutter_riverpod: ^2.6.1      # Gestión de estado
  dio: ^5.7.0                   # Cliente HTTP
  flutter_secure_storage: ^9.2.2 # Almacenamiento seguro
  go_router: ^14.6.2            # Navegación
  google_fonts: ^6.2.1          # Tipografía
  intl: ^0.20.1                 # Internacionalización
  flutter_spinkit: ^5.2.1       # Animaciones de carga
```

## 🚀 Instalación y Configuración

### Requisitos Previos
- Flutter 3.8.1 o superior
- Dart SDK
- Android Studio / Xcode (para emuladores)

### Pasos de Instalación

1. **Clonar el repositorio**
```bash
cd 1P-SI2-mobile
```

2. **Instalar dependencias**
```bash
flutter pub get
```

3. **Configurar API**
Editar `lib/core/config/api_config.dart`:
```dart
static const String baseUrl = 'http://TU_IP:8000';
```

4. **Ejecutar la aplicación**
```bash
flutter run
```

## 🔌 Integración con Backend

### Endpoints Utilizados

**Autenticación** (`/api/v1/auth`)
- `POST /auth/register/client` - Registro de cliente
- `POST /auth/login` - Login unificado
- `POST /auth/verify-2fa` - Verificación 2FA
- `POST /auth/logout` - Cerrar sesión
- `GET /auth/profile` - Obtener perfil
- `PUT /auth/profile` - Actualizar perfil

**Password** (`/api/v1/password`)
- `POST /password/forgot` - Solicitar recuperación
- `POST /password/reset` - Restablecer con token
- `POST /password/change` - Cambiar contraseña

**2FA** (`/api/v1/2fa`)
- `GET /2fa/status` - Estado de 2FA
- `POST /2fa/enable` - Habilitar 2FA
- `POST /2fa/verify` - Verificar código OTP
- `POST /2fa/disable` - Deshabilitar 2FA
- `POST /2fa/resend` - Reenviar código

### Manejo de Errores

La aplicación maneja errores del backend de forma inteligente:
- Errores de validación (422)
- Credenciales incorrectas (401)
- Errores de conexión
- Timeouts
- Errores del servidor (500)

Los mensajes se muestran de forma amigable al usuario.

## 🎯 Pantallas

### Públicas (Sin autenticación)
1. **Splash Screen** - Pantalla inicial
2. **Login** - Inicio de sesión
3. **Register** - Registro de cliente
4. **Forgot Password** - Recuperación
5. **Reset Password** - Restablecer
6. **Verify 2FA** - Verificación OTP

### Privadas (Requieren autenticación)
7. **Home** - Dashboard principal
8. **Profile** - Perfil del usuario
9. **Security** - Configuración de seguridad
10. **Change Password** - Cambio de contraseña

## 🔐 Seguridad

- Tokens JWT almacenados en `flutter_secure_storage`
- Refresh token automático
- Logout automático en errores 401
- Validación de entrada en cliente y servidor
- Encriptación de datos sensibles

## 🧪 Testing

```bash
# Ejecutar tests
flutter test

# Ejecutar tests con coverage
flutter test --coverage
```

## 📱 Build

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## 🎨 Componentes Reutilizables

### Widgets
- `PrimaryButton` - Botón principal
- `CustomTextField` - Input personalizado
- `ErrorMessage` - Mensaje de error
- `SuccessMessage` - Mensaje de éxito
- `LoadingOverlay` - Overlay de carga

### Validadores
- `FormValidators.email()` - Validación de email
- `FormValidators.password()` - Validación de contraseña
- `FormValidators.ci()` - Validación de CI
- `FormValidators.otp()` - Validación de código OTP

## 📝 Convenciones de Código

- **Archivos**: `snake_case.dart`
- **Clases**: `PascalCase`
- **Variables**: `camelCase`
- **Constantes**: `camelCase` o `UPPER_CASE`
- **Privados**: `_prefixWithUnderscore`

## 🔄 Flujo de Datos

```
UI (Widgets)
  ↓
Providers (Riverpod)
  ↓
Repositories
  ↓
Services (API)
  ↓
Backend FastAPI
```

## 🚧 Próximas Funcionalidades

- [ ] Home/Dashboard completo
- [ ] Búsqueda de talleres cercanos
- [ ] Solicitud de servicios
- [ ] Historial de servicios
- [ ] Notificaciones push
- [ ] Chat con talleres
- [ ] Valoraciones y reseñas

## 📄 Licencia

Proyecto académico - Universidad [Nombre]

## 👥 Equipo

Desarrollado como parte del proyecto 1P-SI2 - MecanicoYa

---

**Merchanic Repair** - Tu taller mecánico en tu bolsillo 🔧📱
