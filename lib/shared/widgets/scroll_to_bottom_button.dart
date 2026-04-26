import 'package:flutter/material.dart';

/// Botón flotante para hacer scroll al final del chat
/// Aparece cuando hay mensajes nuevos y el usuario está leyendo mensajes antiguos
class ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final int unreadCount;

  const ScrollToBottomButton({
    super.key,
    required this.onPressed,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 80, // Encima del input
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF007AFF),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
