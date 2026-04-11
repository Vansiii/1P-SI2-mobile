# Audio Recorder Widget

Widget mejorado para grabación de audio con mejor UX/UI.

## Características

### 🎨 Diseño Visual
- **Animación pulsante** durante la grabación
- **Indicador visual** con círculo animado
- **Temporizador** con formato MM:SS
- **Estados visuales** claros (Grabando/Pausado)
- **Gradiente de fondo** sutil
- **Diseño en card** con elevación

### 🎛️ Controles
- **Cancelar**: Descarta la grabación actual
- **Pausar/Reanudar**: Control de pausa durante la grabación
- **Guardar**: Finaliza y guarda el audio

### 🎯 Funcionalidades
- Grabación en formato AAC (M4A)
- Temporizador en tiempo real
- Animación de pulso durante grabación
- Feedback visual del estado
- Manejo de permisos de micrófono

## Uso

```dart
AudioRecorderWidget(
  onAudioRecorded: (File audioFile) {
    // Manejar el archivo de audio grabado
    print('Audio grabado: ${audioFile.path}');
  },
  onCancel: () {
    // Opcional: manejar cancelación
    print('Grabación cancelada');
  },
)
```

## Estados

1. **Inicial**: Botón simple "Grabar Audio"
2. **Grabando**: Card expandido con controles y animación
3. **Pausado**: Indicador amarillo y botón de reanudar

## Colores

- **Grabando**: Rojo (AppColors.error)
- **Pausado**: Amarillo (AppColors.warning)
- **Guardar**: Verde (AppColors.success)
- **Cancelar**: Gris (AppColors.textMuted)

## Dependencias

- `record`: Para grabación de audio
- `path_provider`: Para almacenamiento temporal
