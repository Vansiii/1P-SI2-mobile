import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../vehicles/providers/vehicle_provider.dart';
import '../providers/incident_provider.dart';
import 'widgets/audio_recorder_widget.dart';

class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _imagePicker = ImagePicker();

  int? _selectedVehicleId;
  Position? _currentPosition;
  MapController? _mapController;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _isUploadingAudio = false;

  // Evidencias
  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  final List<File> _selectedAudios = [];
  final List<String> _uploadedAudioUrls = [];

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAudioIndex;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _direccionController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Obtener dirección desde coordenadas (geocoding inverso)
      await _getAddressFromCoordinates(position.latitude, position.longitude);

      // Mover cámara del mapa solo si el widget ya está montado
      // Esperar un frame para asegurar que el mapa esté renderizado
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_mapController != null && mounted) {
            try {
              _mapController!.move(
                LatLng(position.latitude, position.longitude),
                16,
              );
            } catch (e) {
              // Ignorar error si el mapa aún no está listo
            }
          }
        });
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      // Usar Nominatim (OpenStreetMap) para geocoding inverso
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'SistemaTalleres/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        // Construir dirección legible
        final List<String> addressParts = [];

        if (address['road'] != null) addressParts.add(address['road']);
        if (address['house_number'] != null)
          addressParts.add(address['house_number']);
        if (address['neighbourhood'] != null)
          addressParts.add(address['neighbourhood']);
        if (address['suburb'] != null) addressParts.add(address['suburb']);
        if (address['city'] != null) addressParts.add(address['city']);

        final fullAddress = addressParts.join(', ');

        if (mounted && fullAddress.isNotEmpty) {
          setState(() {
            _direccionController.text = fullAddress;
          });
        }
      }
    } catch (e) {
      // Silenciosamente fallar - el usuario puede ingresar la dirección manualmente
      print('Error obteniendo dirección: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() => _selectedImages.add(file));
        await _uploadImage(file);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() => _isUploadingImage = true);

    try {
      final imageUrl = await ref
          .read(incidentsProvider.notifier)
          .uploadIncidentImage(imageFile);

      setState(() {
        _uploadedImageUrls.add(imageUrl);
        _isUploadingImage = false;
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Imagen subida exitosamente');
      }
    } catch (e) {
      setState(() {
        _selectedImages.remove(imageFile);
        _isUploadingImage = false;
      });
      if (mounted) {
        // Extraer solo el mensaje de error sin "Exception: "
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleAudioRecorded(File audioFile) async {
    setState(() {
      _selectedAudios.add(audioFile);
      _isUploadingAudio = true;
    });

    try {
      final audioUrl = await ref
          .read(incidentsProvider.notifier)
          .uploadIncidentAudio(audioFile);

      setState(() {
        _uploadedAudioUrls.add(audioUrl);
        _isUploadingAudio = false;
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Audio subido exitosamente');
      }
    } catch (e) {
      setState(() {
        _selectedAudios.remove(audioFile);
        _isUploadingAudio = false;
      });
      if (mounted) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        SnackBarUtils.showError(context, errorMessage);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVehicleId == null) {
      SnackBarUtils.showError(context, 'Selecciona un vehículo');
      return;
    }

    if (_currentPosition == null) {
      SnackBarUtils.showWarning(context, 'Esperando ubicación...');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(incidentsProvider.notifier)
          .createIncident(
            vehiculoId: _selectedVehicleId!,
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            direccionReferencia: _direccionController.text.trim().isEmpty
                ? null
                : _direccionController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            imagenes: _uploadedImageUrls,
            audios: _uploadedAudioUrls,
          );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Emergencia reportada. Un taller será asignado pronto.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        SnackBarUtils.showError(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesState = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text(
          'Reportar Emergencia',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mapa con ubicación actual (OpenStreetMap)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(
                            'Ubicación Actual',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: _isLoadingLocation
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Obteniendo ubicación...'),
                                ],
                              ),
                            )
                          : _currentPosition != null
                          ? FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                initialZoom: 16,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.mobile',
                                  maxZoom: 19,
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                      ),
                                      width: 50,
                                      height: 50,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: AppColors.error,
                                        size: 50,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.location_off,
                                    size: 48,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: _getCurrentLocation,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Obtener ubicación'),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (_currentPosition != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Coordenadas GPS:',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ubicación obtenida correctamente',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Selector de vehículo mejorado
              Text(
                'Vehículo *',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              vehiclesState.when(
                data: (vehicles) {
                  if (vehicles.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'No tienes vehículos registrados',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => context.push('/vehicles/add'),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar Vehículo'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GestureDetector(
                    onTap: () => _showVehicleSelector(context, vehicles),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedVehicleId != null
                              ? AppColors.primary
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: _selectedVehicleId != null
                          ? _buildSelectedVehicle(
                              vehicles.firstWhere(
                                (v) => v.id == _selectedVehicleId,
                              ),
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: AppColors.primary,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Selecciona un vehículo',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppColors.textMuted,
                                  size: 16,
                                ),
                              ],
                            ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Error: $error'),
              ),
              const SizedBox(height: 20),

              // Descripción del problema
              CustomTextField(
                controller: _descripcionController,
                label: 'Descripción del Problema *',
                hint: 'Describe qué está pasando con tu vehículo...',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La descripción es requerida';
                  }
                  if (value.trim().length < 10) {
                    return 'Describe el problema con más detalle (mín. 10 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dirección de referencia
              CustomTextField(
                controller: _direccionController,
                label: 'Dirección de Referencia',
                hint: 'Ej: Cerca del mercado central',
                prefixIcon: const Icon(Icons.place),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Sección de evidencias - Imágenes
              Text(
                'Evidencias Fotográficas',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Contenedor de imagen con diseño mejorado
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Subiendo imagen...'),
                          ],
                        ),
                      )
                    : _selectedImages.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _showFullImage(context, _selectedImages.last),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImages.last,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Overlay con botones
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Row(
                              children: [
                                _buildImageActionButton(
                                  icon: Icons.zoom_in_outlined,
                                  onTap: () => _showFullImage(
                                    context,
                                    _selectedImages.last,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.9),
                                  iconColor: Colors.black87,
                                ),
                                const SizedBox(width: 10),
                                _buildImageActionButton(
                                  icon: Icons.camera_alt_outlined,
                                  onTap: () => _pickImage(ImageSource.camera),
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                _buildImageActionButton(
                                  icon: Icons.photo_library_outlined,
                                  onTap: () => _pickImage(ImageSource.gallery),
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: 10),
                                _buildImageActionButton(
                                  icon: Icons.delete_outline,
                                  onTap: () async {
                                    final index = _selectedImages.length - 1;
                                    if (index < _uploadedImageUrls.length) {
                                      final fileUrl = _uploadedImageUrls[index];
                                      try {
                                        await ref
                                            .read(incidentsProvider.notifier)
                                            .deleteIncidentFile(fileUrl);
                                        if (mounted) {
                                          SnackBarUtils.showSuccess(
                                            context,
                                            'Imagen eliminada',
                                          );
                                        }
                                        setState(() {
                                          _uploadedImageUrls.removeAt(index);
                                        });
                                      } catch (e) {
                                        if (mounted) {
                                          SnackBarUtils.showError(
                                            context,
                                            'Error al eliminar',
                                          );
                                        }
                                      }
                                    }
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                  color: AppColors.error,
                                ),
                              ],
                            ),
                          ),
                          // Contador de imágenes
                          if (_selectedImages.length > 1)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_selectedImages.length} fotos',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Agregar evidencias fotográficas',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Botones de acción
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildImageSourceButton(
                                  icon: Icons.camera_alt_outlined,
                                  onTap: () => _pickImage(ImageSource.camera),
                                ),
                                const SizedBox(width: 20),
                                _buildImageSourceButton(
                                  icon: Icons.photo_library_outlined,
                                  onTap: () => _pickImage(ImageSource.gallery),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),

              // Lista horizontal de miniaturas si hay múltiples imágenes
              if (_selectedImages.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          // Mover la imagen seleccionada al final para mostrarla
                          setState(() {
                            final image = _selectedImages.removeAt(index);
                            _selectedImages.add(image);
                            if (index < _uploadedImageUrls.length) {
                              final url = _uploadedImageUrls.removeAt(index);
                              _uploadedImageUrls.add(url);
                            }
                          });
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: index == _selectedImages.length - 1
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: index == _selectedImages.length - 1
                                  ? 3
                                  : 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              _selectedImages[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Sección de evidencias - Audio
              Text(
                'Evidencias de Audio',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_selectedAudios.isNotEmpty)
                Column(
                  children: _selectedAudios.asMap().entries.map((entry) {
                    final index = entry.key;
                    final audioFile = entry.value;
                    return _buildAudioCard(index, audioFile);
                  }).toList(),
                ),
              const SizedBox(height: 12),
              AudioRecorderWidget(onAudioRecorded: _handleAudioRecorded),
              const SizedBox(height: 32),

              // Botón de envío
              PrimaryButton(
                text: 'Reportar Emergencia',
                onPressed:
                    _isSubmitting || _isUploadingImage || _isUploadingAudio
                    ? null
                    : _handleSubmit,
                isLoading: _isSubmitting,
                backgroundColor: AppColors.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para mostrar tarjeta de audio con reproducción
  Widget _buildAudioCard(int index, File audioFile) {
    final isPlaying = _playingAudioIndex == index && _isPlaying;
    final duration = _formatDuration(
      0,
    ); // Placeholder, se puede mejorar con duración real

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Botón de reproducir/pausar
            Material(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _toggleAudioPlayback(index, audioFile),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Información del audio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.audiotrack,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPlaying ? 'Reproduciendo...' : 'Toca para reproducir',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botón de eliminar
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _deleteAudio(index),
            ),
          ],
        ),
      ),
    );
  }

  // Reproducir/pausar audio
  Future<void> _toggleAudioPlayback(int index, File audioFile) async {
    try {
      if (_playingAudioIndex == index && _isPlaying) {
        // Pausar audio actual
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        // Reproducir nuevo audio
        if (_playingAudioIndex != index) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(DeviceFileSource(audioFile.path));
        setState(() {
          _playingAudioIndex = index;
          _isPlaying = true;
        });

        // Listener para cuando termine el audio
        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playingAudioIndex = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error al reproducir audio');
      }
    }
  }

  // Eliminar audio
  Future<void> _deleteAudio(int index) async {
    // Detener reproducción si es el audio actual
    if (_playingAudioIndex == index) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingAudioIndex = null;
      });
    }

    // Eliminar del storage si ya fue subido
    if (index < _uploadedAudioUrls.length) {
      final fileUrl = _uploadedAudioUrls[index];
      try {
        await ref.read(incidentsProvider.notifier).deleteIncidentFile(fileUrl);
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Audio eliminado');
        }
        setState(() {
          _uploadedAudioUrls.removeAt(index);
        });
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(
            context,
            'Error al eliminar: ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }
    }

    setState(() {
      _selectedAudios.removeAt(index);
      // Ajustar índice de reproducción si es necesario
      if (_playingAudioIndex != null && _playingAudioIndex! > index) {
        _playingAudioIndex = _playingAudioIndex! - 1;
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Método para mostrar imagen completa
  void _showFullImage(BuildContext context, File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(imageFile),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mostrar selector de vehículos con búsqueda
  void _showVehicleSelector(BuildContext context, List<dynamic> vehicles) {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredVehicles = vehicles.where((vehicle) {
            final searchTerm = searchController.text.toLowerCase();
            return vehicle.displayName.toLowerCase().contains(searchTerm) ||
                vehicle.matricula.toLowerCase().contains(searchTerm) ||
                (vehicle.marca?.toLowerCase().contains(searchTerm) ?? false);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: AppColors.baseBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Selecciona un Vehículo',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Buscador
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar vehículo...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.cardBg,
                        ),
                        onChanged: (value) => setModalState(() {}),
                      ),
                    ],
                  ),
                ),
                // Lista de vehículos
                Expanded(
                  child: filteredVehicles.isEmpty
                      ? const Center(
                          child: Text(
                            'No se encontraron vehículos',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredVehicles[index];
                            final isSelected = _selectedVehicleId == vehicle.id;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isSelected ? 4 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(
                                    () => _selectedVehicleId = vehicle.id,
                                  );
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Imagen del vehículo
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: vehicle.imagen != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  vehicle.imagen!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return const Icon(
                                                          Icons.directions_car,
                                                          color:
                                                              AppColors.primary,
                                                          size: 35,
                                                        );
                                                      },
                                                ),
                                              )
                                            : const Icon(
                                                Icons.directions_car,
                                                color: AppColors.primary,
                                                size: 35,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Información del vehículo
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              vehicle.displayName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : AppColors.textMain,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Placa: ${vehicle.matricula}',
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (vehicle.color != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Color: ${vehicle.color}',
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Indicador de selección
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 28,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget para mostrar el vehículo seleccionado
  Widget _buildSelectedVehicle(dynamic vehicle) {
    return Row(
      children: [
        // Imagen del vehículo
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: vehicle.imagen != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    vehicle.imagen!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.directions_car,
                        color: AppColors.primary,
                        size: 30,
                      );
                    },
                  ),
                )
              : const Icon(
                  Icons.directions_car,
                  color: AppColors.primary,
                  size: 30,
                ),
        ),
        const SizedBox(width: 16),
        // Información del vehículo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Placa: ${vehicle.matricula}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle, color: AppColors.success, size: 24),
      ],
    );
  }

  // Widget para botones de fuente de imagen (cuando no hay imagen)
  Widget _buildImageSourceButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUploadingImage ? null : onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  // Widget para botones de acción sobre la imagen (cuando hay imagen)
  Widget _buildImageActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUploadingImage ? null : onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: iconColor ?? Colors.white),
        ),
      ),
    );
  }
}
