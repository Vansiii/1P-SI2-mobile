import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// A floating compass button that appears when the map is rotated.
/// Tapping it resets the map's rotation to 0 (North).
///
/// Usage: Place inside a [Positioned] widget within a [Stack]:
/// ```dart
/// Positioned(
///   top: 16, right: 16,
///   child: MapCompassButton(mapController: _mapController),
/// )
/// ```
class MapCompassButton extends StatelessWidget {
  final MapController mapController;

  // Legacy params kept for backwards compatibility (ignored; use Positioned)
  final double top;
  final double right;

  const MapCompassButton({
    super.key,
    required this.mapController,
    this.top = 16.0,
    this.right = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        final double rotation = mapController.camera.rotation;

        // Only show when rotated (epsilon for floating-point noise)
        final bool isRotated =
            rotation.abs() > 0.5 && (360 - rotation).abs() > 0.5;

        return AnimatedOpacity(
          opacity: isRotated ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            ignoring: !isRotated,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => mapController.rotate(0),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Transform.rotate(
                      // Counter-rotate the icon so it always points North
                      angle: rotation * (3.1415926535897932 / 180),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
