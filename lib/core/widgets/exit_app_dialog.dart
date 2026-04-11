import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class ExitAppDialog extends StatelessWidget {
  const ExitAppDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ExitAppDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            // Título
            const Text(
              '¿Salir de la aplicación?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Descripción
            Text(
              'Puedes volver en cualquier momento',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                // Botón Cancelar
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: AppColors.borderLight,
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Botón Salir
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      // Salir de la aplicación
                      if (Platform.isAndroid) {
                        SystemNavigator.pop();
                      } else if (Platform.isIOS) {
                        exit(0);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Salir',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
