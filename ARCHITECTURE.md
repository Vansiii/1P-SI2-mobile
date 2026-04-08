# Merchanic Repair - Arquitectura Móvil

## Estructura del Proyecto

```
lib/
├── core/                      # Núcleo de la aplicación
│   ├── config/               # Configuración (API, constantes)
│   ├── theme/                # Tema visual (colores, tipografía, estilos)
│   ├── router/               # Navegación y rutas
│   └── utils/                # Utilidades compartidas
│
├── data/                      # Capa de datos
│   ├── models/               # Modelos de datos
│   ├── repositories/         # Repositorios (abstracción de datos)
│   └── services/             # Servicios API
│
├── features/                  # Funcionalidades por módulo
│   ├── auth/                 # Autenticación
│   │   ├── presentation/    # UI (screens, widgets)
│   │   ├── providers/       # Estado (Riverpod/Provider)
│   │   └── models/          # Modelos específicos
│   │
│   ├── profile/              # Perfil de usuario
│   ├── security/             # Seguridad y 2FA
│   └── home/                 # Dashboard principal
│
├── shared/                    # Componentes compartidos
│   ├── widgets/              # Widgets reutilizables
│   ├── validators/           # Validadores de formularios
│   └── extensions/           # Extensiones de Dart
│
└── main.dart                  # Punto de entrada

```

## Principios Arquitectónicos

1. **Separación de responsabilidades**: UI, lógica de negocio y datos separados
2. **Escalabilidad**: Estructura modular que permite crecer sin desorden
3. **Mantenibilidad**: Código limpio, organizado y fácil de mantener
4. **Reutilización**: Componentes compartidos para consistencia
5. **Testabilidad**: Arquitectura que facilita testing

## Stack Tecnológico

- **Framework**: Flutter 3.8.1+
- **Lenguaje**: Dart
- **Estado**: Riverpod (gestión de estado moderna)
- **HTTP**: Dio (cliente HTTP robusto)
- **Almacenamiento**: flutter_secure_storage (tokens JWT)
- **Validación**: Validadores personalizados
- **Navegación**: GoRouter (navegación declarativa)
- **UI**: Material Design 3

## Flujo de Datos

```
UI (Widgets) 
  ↓
Providers (Estado)
  ↓
Repositories (Abstracción)
  ↓
Services (API)
  ↓
Backend FastAPI
```

## Pantallas Implementadas

### Públicas (Sin autenticación)
1. **Splash Screen** - Pantalla inicial con logo
2. **Login** - Inicio de sesión unificado
3. **Register Client** - Registro solo para clientes
4. **Forgot Password** - Solicitar recuperación
5. **Reset Password** - Restablecer con token
6. **Verify 2FA** - Verificación de código OTP

### Privadas (Requieren autenticación)
7. **Home/Dashboard** - Pantalla principal con navegación inferior
8. **Profile** - Perfil del usuario
9. **Security** - Configuración de seguridad y 2FA
10. **Change Password** - Cambio de contraseña

## Navegación

- **Bottom Navigation Bar** para pantallas principales (Home, Profile, Security)
- **Stack Navigation** para flujos lineales (auth, formularios)
- **Modal Sheets** para acciones secundarias

## Manejo de Errores

- Interceptor HTTP para errores globales
- Mensajes de error traducidos y amigables
- Estados de carga, error y éxito en UI
- Validación en tiempo real en formularios

## Seguridad

- Tokens JWT almacenados en flutter_secure_storage
- Refresh token automático
- Logout automático en errores 401
- Validación de entrada en cliente y servidor
