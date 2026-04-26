# Guía de Deployment - MecánicoYa Mobile

Esta guía cubre el proceso completo de deployment de la aplicación móvil Flutter a Google Play Store y Apple App Store.

## 📋 Tabla de Contenidos

1. [Preparación General](#preparación-general)
2. [Android - Google Play Store](#android---google-play-store)
3. [iOS - Apple App Store](#ios---apple-app-store)
4. [Firebase Setup](#firebase-setup)
5. [Variables de Entorno](#variables-de-entorno)
6. [Testing Pre-Release](#testing-pre-release)

---

## Preparación General

### 1. Configurar Variables de Entorno

Crea `.env.production` con tus valores de producción:

```bash
cp .env.example .env.production
```

Edita `.env.production`:

```env
ENVIRONMENT=production
API_BASE_URL=https://tu-backend.railway.app
ENABLE_LOGGING=false
ENABLE_DEBUG_BANNER=false
CONNECT_TIMEOUT=120
RECEIVE_TIMEOUT=120
```

### 2. Actualizar Versión

Edita `pubspec.yaml`:

```yaml
version: 1.0.0+1  # 1.0.0 = version name, 1 = build number
```

- **Version name**: Visible para usuarios (1.0.0, 1.1.0, 2.0.0)
- **Build number**: Número interno incremental (1, 2, 3...)

### 3. Instalar Dependencias

```bash
flutter pub get
```

---

## Android - Google Play Store

### Paso 1: Configurar Firebase para Android

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Agrega una app Android
4. Descarga `google-services.json`
5. Colócalo en `android/app/google-services.json`

**IMPORTANTE**: Este archivo NO debe estar en Git (ya está en `.gitignore`)

### Paso 2: Configurar Signing Key

1. **Generar keystore** (solo primera vez):

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Guarda la contraseña en un lugar seguro.

2. **Crear `android/key.properties`**:

```properties
storePassword=TU_STORE_PASSWORD
keyPassword=TU_KEY_PASSWORD
keyAlias=upload
storeFile=/ruta/a/upload-keystore.jks
```

**IMPORTANTE**: Este archivo NO debe estar en Git (ya está en `.gitignore`)

3. **Configurar `android/app/build.gradle`**:

Ya está configurado para leer de `key.properties` en modo release.

### Paso 3: Configurar App Info

Edita `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.mecanicoya.app">
    
    <application
        android:label="MecánicoYa"
        android:icon="@mipmap/ic_launcher">
        <!-- ... -->
    </application>
</manifest>
```

### Paso 4: Build APK/AAB

**Para testing (APK)**:
```bash
flutter build apk --release
```

**Para Play Store (AAB)**:
```bash
flutter build appbundle --release
```

Los archivos se generan en:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### Paso 5: Subir a Google Play Console

1. Ve a [Google Play Console](https://play.google.com/console)
2. Crea una nueva aplicación
3. Completa la información de la app
4. Sube el archivo AAB en "Producción" o "Testing interno"
5. Completa los requisitos de contenido
6. Envía para revisión

**Tiempo de revisión**: 1-3 días

---

## iOS - Apple App Store

### Paso 1: Configurar Firebase para iOS

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Agrega una app iOS
4. Descarga `GoogleService-Info.plist`
5. Colócalo en `ios/Runner/GoogleService-Info.plist`

**IMPORTANTE**: Este archivo NO debe estar en Git (ya está en `.gitignore`)

### Paso 2: Configurar Xcode

1. **Abrir proyecto en Xcode**:

```bash
open ios/Runner.xcworkspace
```

2. **Configurar Bundle Identifier**:
   - Selecciona "Runner" en el navegador
   - En "General" > "Identity"
   - Bundle Identifier: `com.mecanicoya.app`

3. **Configurar Signing**:
   - En "Signing & Capabilities"
   - Marca "Automatically manage signing"
   - Selecciona tu Team (necesitas Apple Developer Account)

4. **Configurar App Info**:
   - Display Name: `MecánicoYa`
   - Version: `1.0.0`
   - Build: `1`

### Paso 3: Configurar Permisos

Edita `ios/Runner/Info.plist` para agregar descripciones de permisos:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Necesitamos tu ubicación para encontrar talleres cercanos</string>

<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a la cámara para tomar fotos de tu vehículo</string>

<key>NSMicrophoneUsageDescription</key>
<string>Necesitamos acceso al micrófono para grabar notas de audio</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Necesitamos acceso a tus fotos para adjuntar imágenes</string>
```

### Paso 4: Build IPA

1. **Build desde Xcode**:
   - Product > Archive
   - Espera a que termine el build
   - Se abrirá el Organizer

2. **O build desde terminal**:

```bash
flutter build ios --release
```

### Paso 5: Subir a App Store Connect

1. En Xcode Organizer:
   - Selecciona el archive
   - Click "Distribute App"
   - Selecciona "App Store Connect"
   - Sigue el wizard

2. Ve a [App Store Connect](https://appstoreconnect.apple.com/)
3. Crea una nueva app
4. Completa la información
5. Selecciona el build subido
6. Envía para revisión

**Tiempo de revisión**: 1-3 días

---

## Firebase Setup

### Configuración Completa

1. **Crear proyecto en Firebase Console**
2. **Agregar apps Android e iOS**
3. **Habilitar servicios**:
   - Cloud Messaging (notificaciones push)
   - Crashlytics (reportes de crashes)
   - Performance Monitoring (métricas)

### Archivos de Configuración

**Android**: `android/app/google-services.json`
```json
{
  "project_info": {
    "project_number": "TU_PROJECT_NUMBER",
    "project_id": "tu-project-id"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:xxx:android:xxx",
        "android_client_info": {
          "package_name": "com.mecanicoya.app"
        }
      }
    }
  ]
}
```

**iOS**: `ios/Runner/GoogleService-Info.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CLIENT_ID</key>
    <string>TU_CLIENT_ID</string>
    <key>REVERSED_CLIENT_ID</key>
    <string>TU_REVERSED_CLIENT_ID</string>
    <key>API_KEY</key>
    <string>TU_API_KEY</string>
    <key>GCM_SENDER_ID</key>
    <string>TU_SENDER_ID</string>
    <key>PROJECT_ID</key>
    <string>tu-project-id</string>
    <key>BUNDLE_ID</key>
    <string>com.mecanicoya.app</string>
</dict>
</plist>
```

**IMPORTANTE**: Estos archivos contienen configuración pública de Firebase (no son secretos), pero no deben estar en Git para evitar conflictos entre entornos.

---

## Variables de Entorno

### Desarrollo vs Producción

**`.env.development`** (local):
```env
ENVIRONMENT=development
API_BASE_URL=http://localhost:8000
ENABLE_LOGGING=true
ENABLE_DEBUG_BANNER=true
CONNECT_TIMEOUT=120
RECEIVE_TIMEOUT=120
```

**`.env.production`** (stores):
```env
ENVIRONMENT=production
API_BASE_URL=https://tu-backend.railway.app
ENABLE_LOGGING=false
ENABLE_DEBUG_BANNER=false
CONNECT_TIMEOUT=120
RECEIVE_TIMEOUT=120
```

### Cambiar Entorno

La app carga automáticamente el archivo correcto según el modo de build:

- **Debug mode**: Usa `.env.development`
- **Release mode**: Usa `.env.production`

Para forzar un entorno específico, edita `lib/main.dart`:

```dart
// Development
await EnvironmentConfig.init(Environment.development);

// Production
await EnvironmentConfig.init(Environment.production);
```

---

## Testing Pre-Release

### 1. Testing Local

```bash
# Debug mode (development)
flutter run

# Release mode (production)
flutter run --release
```

### 2. Testing en Dispositivos Físicos

**Android**:
```bash
flutter install
```

**iOS**:
- Build desde Xcode
- Instala en dispositivo conectado

### 3. Testing Beta

**Android - Internal Testing**:
1. Sube AAB a Play Console
2. Crea un track de "Internal testing"
3. Agrega testers por email
4. Comparte el link de testing

**iOS - TestFlight**:
1. Sube build a App Store Connect
2. Agrega testers en TestFlight
3. Los testers reciben invitación por email

### 4. Checklist Pre-Release

- [ ] Variables de entorno configuradas
- [ ] Firebase configurado (Android + iOS)
- [ ] Versión actualizada en `pubspec.yaml`
- [ ] Iconos de app configurados
- [ ] Permisos configurados (iOS)
- [ ] Signing configurado (Android + iOS)
- [ ] Build exitoso (APK/AAB + IPA)
- [ ] Testing en dispositivos físicos
- [ ] Testing de notificaciones push
- [ ] Testing de funcionalidades críticas
- [ ] Screenshots para stores
- [ ] Descripción de app lista

---

## Troubleshooting

### Error: "Signing for Runner requires a development team"
- Solución: Configura tu Apple Developer Team en Xcode

### Error: "google-services.json not found"
- Solución: Descarga el archivo de Firebase Console y colócalo en `android/app/`

### Error: "GoogleService-Info.plist not found"
- Solución: Descarga el archivo de Firebase Console y colócalo en `ios/Runner/`

### Error: "Upload keystore not found"
- Solución: Genera el keystore con el comando `keytool` y actualiza `key.properties`

### Build lento en iOS
- Solución: Limpia build folder: `flutter clean && flutter pub get`

---

## Recursos Adicionales

- [Flutter Deployment Docs](https://docs.flutter.dev/deployment)
- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Firebase Console](https://console.firebase.google.com/)

---

**¿Necesitas ayuda?** Contacta al equipo de desarrollo.
