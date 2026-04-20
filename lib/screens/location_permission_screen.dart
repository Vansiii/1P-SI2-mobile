import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Pantalla para solicitar permisos de ubicación al técnico
/// Se muestra después del login si los permisos no están concedidos
class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionGranted;
  final VoidCallback? onSkip;

  const LocationPermissionScreen({
    Key? key,
    required this.onPermissionGranted,
    this.onSkip,
  }) : super(key: key);

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isRequesting = false;
  bool _serviceDisabled = false;
  LocationPermission? _currentPermission;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    setState(() {
      _serviceDisabled = !serviceEnabled;
      _currentPermission = permission;
    });
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
    });

    try {
      // Verificar si el servicio está habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _serviceDisabled = true;
          _isRequesting = false;
        });
        _showServiceDisabledDialog();
        return;
      }

      // Solicitar permisos
      final permission = await Geolocator.requestPermission();

      setState(() {
        _currentPermission = permission;
        _isRequesting = false;
      });

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Permisos concedidos
        widget.onPermissionGranted();
      } else if (permission == LocationPermission.deniedForever) {
        // Permisos denegados permanentemente
        _showPermanentlyDeniedDialog();
      } else {
        // Permisos denegados
        _showDeniedDialog();
      }
    } catch (e) {
      setState(() {
        _isRequesting = false;
      });
      _showErrorDialog(e.toString());
    }
  }

  void _showServiceDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Servicio de ubicación deshabilitado'),
        content: const Text(
          'Para usar esta función, debes habilitar el servicio de ubicación en la configuración de tu dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              await _checkCurrentStatus();
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos denegados'),
        content: const Text(
          'Los permisos de ubicación han sido denegados permanentemente. '
          'Para usar esta función, debes habilitar los permisos en la configuración de la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  void _showDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos requeridos'),
        content: const Text(
          'Los permisos de ubicación son necesarios para que el taller pueda hacer seguimiento en tiempo real. '
          '¿Deseas intentar nuevamente?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onSkip != null) {
                widget.onSkip!();
              }
            },
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestPermission();
            },
            child: const Text('Intentar nuevamente'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text('Ocurrió un error al solicitar permisos: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icono
              Icon(
                Icons.location_on,
                size: 120,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),

              // Título
              Text(
                'Permisos de ubicación',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Descripción
              Text(
                'Para que el taller pueda hacer seguimiento en tiempo real de tu ubicación, '
                'necesitamos acceso a tu ubicación GPS.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Lista de beneficios
              _buildBenefitItem(
                icon: Icons.track_changes,
                title: 'Seguimiento en tiempo real',
                description:
                    'El taller podrá ver tu ubicación mientras trabajas',
              ),
              const SizedBox(height: 16),
              _buildBenefitItem(
                icon: Icons.navigation,
                title: 'Navegación optimizada',
                description:
                    'Recibe direcciones precisas a los lugares de servicio',
              ),
              const SizedBox(height: 16),
              _buildBenefitItem(
                icon: Icons.security,
                title: 'Seguridad',
                description:
                    'Tu ubicación solo se comparte con tu taller asignado',
              ),
              const SizedBox(height: 48),

              // Estado actual
              if (_serviceDisabled)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Servicio de ubicación deshabilitado',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_currentPermission == LocationPermission.deniedForever)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Permisos denegados permanentemente',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Botón principal
              ElevatedButton(
                onPressed: _isRequesting ? null : _requestPermission,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isRequesting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Permitir acceso a ubicación',
                        style: TextStyle(fontSize: 16),
                      ),
              ),

              // Botón secundario (omitir)
              if (widget.onSkip != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('Omitir por ahora'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
