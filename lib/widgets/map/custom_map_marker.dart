import 'package:flutter/material.dart';

enum MarkerRole { client, technician, workshop }

class CustomMapMarker extends StatelessWidget {
  final MarkerRole role;
  final String label;
  final VoidCallback? onTap;

  const CustomMapMarker({
    super.key,
    required this.role,
    this.label = '',
    this.onTap,
  });

  Color get _color {
    switch (role) {
      case MarkerRole.client:
        return const Color(0xFFEA4335);
      case MarkerRole.technician:
        return const Color(0xFF4285F4);
      case MarkerRole.workshop:
        return const Color(0xFF9333EA);
    }
  }

  Color get _colorLight {
    switch (role) {
      case MarkerRole.client:
        return const Color(0xFFFF6B6B);
      case MarkerRole.technician:
        return const Color(0xFF60A5FA);
      case MarkerRole.workshop:
        return const Color(0xFFA855F7);
    }
  }

  

  IconData get _icon {
    switch (role) {
      case MarkerRole.client:
        return Icons.person;
      case MarkerRole.technician:
        return Icons.build;
      case MarkerRole.workshop:
        return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 50,
        height: 65,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_color, _colorLight],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            Positioned(
              top: 38,
              child: CustomPaint(
                size: const Size(20, 14),
                painter: _PinTailPainter(color: _color),
              ),
            ),
            if (label.isNotEmpty)
              Positioned(
                top: 54,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final path = Path();
    path.moveTo(size.width * 0.15, 0);
    path.lineTo(size.width * 0.85, 0);
    path.lineTo(size.width * 0.5, size.height);
    path.close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}