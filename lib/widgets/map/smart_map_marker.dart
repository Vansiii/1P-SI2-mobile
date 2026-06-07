import 'dart:math' as math;
import 'package:flutter/material.dart';

enum MarkerRole { client, technician, workshop }

class SmartMapMarker extends StatelessWidget {
  static const double markerWidth = 40;
  static const double markerHeight = 52;

  final MarkerRole? role;
  final Color? primaryColor;
  final IconData? icon;
  final String label;
  final bool isSelected;
  final double? heading;
  final VoidCallback? onTap;

  const SmartMapMarker({
    super.key,
    this.role,
    this.primaryColor,
    this.icon,
    this.label = '',
    this.isSelected = false,
    this.heading,
    this.onTap,
  });

  Color get _color {
    if (primaryColor != null) return primaryColor!;
    if (role == null) return const Color(0xFF6B7280);
    switch (role!) {
      case MarkerRole.client:
        return const Color(0xFFEA4335);
      case MarkerRole.technician:
        return const Color(0xFF4285F4);
      case MarkerRole.workshop:
        return const Color(0xFF9333EA);
    }
  }

  IconData get _roleIcon {
    if (icon != null) return icon!;
    if (role == null) return Icons.push_pin;
    switch (role!) {
      case MarkerRole.client:
        return Icons.person;
      case MarkerRole.technician:
        return Icons.directions_car;
      case MarkerRole.workshop:
        return Icons.store;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: markerWidth,
        height: markerHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Badge floats above
            if (label.isNotEmpty && isSelected)
              Positioned(
                left: -18,
                right: -18,
                top: 0,
                child: _buildBadge(),
              ),
            // Pin anchored at the very bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildPinBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPinBody() {
    return SizedBox(
      width: markerWidth,
      height: markerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ground shadow
          Positioned(
            left: 6,
            bottom: -2,
            child: Container(
              width: 28,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Triangle tip at the very bottom
          Positioned(
            left: 12,
            bottom: 0,
            child: CustomPaint(
              size: const Size(16, 12),
              painter: _TipPainter(color: _color),
            ),
          ),
          // Circle at the top
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_colorLight(), _color],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.5),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: heading != null ? heading! * math.pi / 180 : 0,
                child: Icon(_roleIcon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorLight() {
    final c = _color;
    return Color.fromARGB(
      c.alpha,
      math.min(255, c.red + 55),
      math.min(255, c.green + 55),
      math.min(255, c.blue + 55),
    );
  }
}

class _TipPainter extends CustomPainter {
  final Color color;
  _TipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
