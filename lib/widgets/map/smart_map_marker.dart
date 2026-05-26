import 'package:flutter/material.dart';

enum MarkerRole { client, technician, workshop }

class SmartMapMarker extends StatelessWidget {
  final MarkerRole? role;
  final Color? primaryColor;
  final String label;
  final bool isSelected;
  final double mapRotation;
  final VoidCallback? onTap;

  const SmartMapMarker({
    super.key,
    this.role,
    this.primaryColor,
    this.label = '',
    this.isSelected = false,
    this.mapRotation = 0.0,
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
    if (role == null) return Icons.push_pin;
    switch (role!) {
      case MarkerRole.client:
        return Icons.person;
      case MarkerRole.technician:
        return Icons.build;
      case MarkerRole.workshop:
        return Icons.store;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0,
          end: isSelected ? 1.0 : 0.0,
        ),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        builder: (context, t, child) {
          final scale = 1.0 + (t * 0.2);
          final lift = t * 6.0;
          return Transform.translate(
            offset: Offset(0, -lift),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: Transform.rotate(
          angle: -mapRotation,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: (label.isNotEmpty && isSelected)
                    ? _buildBadge()
                    : const SizedBox.shrink(),
              ),
              _buildPin(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      key: const ValueKey('badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPin() {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_on,
            color: _color,
            size: 50,
          ),
          Positioned(
            top: 6,
            child: Icon(
              _roleIcon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}