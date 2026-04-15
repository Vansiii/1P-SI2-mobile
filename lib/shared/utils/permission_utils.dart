import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';

class PermissionUtils {
  /// Solicita permiso de cámara y abre la cámara si se concede
  static Future<XFile?> requestCameraAndTakePhoto(BuildContext context) async {
    // Solicitar permiso de cámara explícitamente
    final status = await Permission.camera.request();

    if (status.isDenied) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Se necesita permiso para usar la cámara',
          AppColors.error,
        );
      }
      return null;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        // Mostrar diálogo para ir a configuración
        await _showPermissionDialog(
          context,
          'Permiso de Cámara Requerido',
          'Para usar la cámara, necesitas habilitar el permiso en la configuración de tu dispositivo.',
        );
      }
      return null;
    }

    if (!status.isGranted) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Se necesita permiso para usar la cámara',
          AppColors.error,
        );
      }
      return null;
    }

    // Si el permiso fue concedido, abrir la cámara
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      return photo;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Error al capturar foto', AppColors.error);
      }
      return null;
    }
  }

  /// Solicita permiso de galería y abre la galería si se concede
  static Future<List<XFile>?> requestGalleryAndPickImages(
    BuildContext context, {
    bool multiple = false,
  }) async {
    // Solicitar permiso de fotos explícitamente
    final status = await Permission.photos.request();

    if (status.isDenied) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Se necesita permiso para acceder a las fotos',
          AppColors.error,
        );
      }
      return null;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermissionDialog(
          context,
          'Permiso de Galería Requerido',
          'Para acceder a tus fotos, necesitas habilitar el permiso en la configuración de tu dispositivo.',
        );
      }
      return null;
    }

    if (!status.isGranted) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Se necesita permiso para acceder a las fotos',
          AppColors.error,
        );
      }
      return null;
    }

    // Si el permiso fue concedido, abrir la galería
    final ImagePicker picker = ImagePicker();
    try {
      if (multiple) {
        final List<XFile> images = await picker.pickMultiImage(
          imageQuality: 85,
        );
        return images;
      } else {
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        return image != null ? [image] : null;
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Error al seleccionar fotos', AppColors.error);
      }
      return null;
    }
  }

  /// Solicita permiso de micrófono
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.request();

    if (status.isDenied) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Se necesita permiso para usar el micrófono',
          AppColors.error,
        );
      }
      return false;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermissionDialog(
          context,
          'Permiso de Micrófono Requerido',
          'Para grabar audio, necesitas habilitar el permiso en la configuración de tu dispositivo.',
        );
      }
      return false;
    }

    return status.isGranted;
  }

  /// Solicita permiso de ubicación
  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.request();

    if (status.isDenied) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Se necesita permiso para acceder a tu ubicación',
          AppColors.error,
        );
      }
      return false;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermissionDialog(
          context,
          'Permiso de Ubicación Requerido',
          'Para obtener tu ubicación, necesitas habilitar el permiso en la configuración de tu dispositivo.',
        );
      }
      return false;
    }

    return status.isGranted;
  }

  static void _showSnackBar(
    BuildContext context,
    String message,
    Color backgroundColor,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<void> _showPermissionDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }
}
