import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../vehicles/providers/vehicle_provider.dart';
import '../../vehicles/data/models/vehicle_model.dart';
import '../providers/incident_provider.dart';

class CreateIncidentScreen extends ConsumerStatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  ConsumerState<CreateIncidentScreen> createState() =>
      _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends ConsumerState<CreateIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _isGettingLocation = false;
  bool _isRecording = false;

  VehicleModel? _selectedVehicle;
  Position? _currentPosition;

  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];

  File? _recordedAudio;
  String? _uploadedAudioUrl;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _direccionController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Se necesita permiso para acceder a tu ubicación');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Se necesita permiso para acceder a tu ubicación');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) {
        SnackBarUtils.showError(context, 'Error al obtener ubicación: $e');
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final remainingSlots = 5 - _selectedImages.length;
        final filesToAdd = pickedFiles.take(remainingSlots).toList();

        setState(() {
          _selectedImages.addAll(filesToAdd.map((xFile) => File(xFile.path)));
        });

        if (pickedFiles.length > remainingSlots) {
          SnackBarUtils.showWarning(context, 'Máximo 5 imágenes permitidas');
        }
      }
    } catch (e) {
      if (mounted) {
        // Verificar si es un error de permisos
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('photo') ||
            errorMessage.contains('denied') ||
            errorMessage.contains('permission')) {
          SnackBarUtils.showError(
            context,
            'Se necesita permiso para acceder a las fotos',
          );
        } else {
          SnackBarUtils.showError(context, 'Error al seleccionar imágenes');
        }
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (_selectedImages.length >= 5) {
          SnackBarUtils.showWarning(context, 'Máximo 5 imágenes permitidas');
          return;
        }

        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      if (mounted) {
        // Verificar si es un error de permisos
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('camera_access_denied') ||
            errorMessage.contains('denied') ||
            errorMessage.contains('permission')) {
          SnackBarUtils.showError(
            context,
            'Se necesita permiso para usar la cámara',
          );
        } else {
          SnackBarUtils.showError(context, 'Error al tomar foto');
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/incident_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        });
      } else {
        throw Exception('Se necesita permiso para usar el micrófono');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        SnackBarUtils.showError(context, errorMessage);
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      if (path != null) {
        setState(() {
          _recordedAudio = File(path);
          _isRecording = false;
        });

        SnackBarUtils.showSuccess(context, 'Audio grabado exitosamente');
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        SnackBarUtils.showError(context, 'Error al detener grabación: $e');
      }
    }
  }

  void _deleteAudio() {
    setState(() {
      _recordedAudio = null;
      _recordingDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _uploadFiles() async {
    setState(() => _isUploadingFiles = true);

    try {
      _uploadedImageUrls.clear();
      for (final imageFile in _selectedImages) {
        final imageUrl = await ref
            .read(incidentsProvider.notifier)
            .uploadIncidentImage(imageFile);
        _uploadedImageUrls.add(imageUrl);
      }

      if (_recordedAudio != null) {
        _uploadedAudioUrl = await ref
            .read(incidentsProvider.notifier)
            .uploadIncidentAudio(_recordedAudio!);
      }

      setState(() => _isUploadingFiles = false);
    } catch (e) {
      setState(() => _isUploadingFiles = false);
      throw Exception('Error al subir archivos: $e');
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVehicle == null) {
      SnackBarUtils.showError(context, 'Selecciona un vehículo');
      return;
    }

    if (_currentPosition == null) {
      SnackBarUtils.showWarning(context, 'Esperando ubicación...');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedImages.isNotEmpty || _recordedAudio != null) {
        await _uploadFiles();
      }

      await ref
          .read(incidentsProvider.notifier)
          .createIncident(
            vehiculoId: _selectedVehicle!.id,
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            direccionReferencia: _direccionController.text.trim().isEmpty
                ? null
                : _direccionController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            imagenes: _uploadedImageUrls,
            audios: _uploadedAudioUrl != null ? [_uploadedAudioUrl!] : [],
          );

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Incidente reportado exitosamente');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Reportar Incidente'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de vehículo
              const Text(
                'Vehículo *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              vehiclesAsync.when(
                data: (vehicles) {
                  if (vehicles.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: const Text(
                        'No tienes vehículos registrados. Registra uno primero.',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    );
                  }

                  return DropdownButtonFormField<VehicleModel>(
                    value: _selectedVehicle,
                    decoration: InputDecoration(
                      hintText: 'Selecciona un vehículo',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: vehicles.map((vehicle) {
                      return DropdownMenuItem(
                        value: vehicle,
                        child: Text(
                          '${vehicle.matricula} - ${vehicle.displayName}',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedVehicle = value);
                    },
                    validator: (value) {
                      if (value == null) return 'Selecciona un vehículo';
                      return null;
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Error: $error'),
              ),
              const SizedBox(height: 24),

              // Ubicación
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isGettingLocation
                          ? Icons.location_searching
                          : _currentPosition != null
                          ? Icons.location_on
                          : Icons.location_off,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isGettingLocation
                          ? const Text('Obteniendo ubicación...')
                          : _currentPosition != null
                          ? Text(
                              'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                              'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                            )
                          : const Text('Ubicación no disponible'),
                    ),
                    if (_currentPosition != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _getCurrentLocation,
                      ),
                  ],
                ),
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
              const SizedBox(height: 16),

              // Descripción
              CustomTextField(
                controller: _descripcionController,
                label: 'Descripción del Problema *',
                hint: 'Describe detalladamente el problema...',
                prefixIcon: const Icon(Icons.description),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La descripción es requerida';
                  }
                  if (value.trim().length < 10) {
                    return 'La descripción debe tener al menos 10 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Imágenes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fotos del Problema',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_selectedImages.length}/5',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_selectedImages.isEmpty)
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agregar fotos (opcional)',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _selectedImages.length) {
                        if (_selectedImages.length < 5) {
                          return GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 32,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      return Container(
                        width: 120,
                        margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),

              // Audio
              const Text(
                'Nota de Voz (Opcional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              if (_recordedAudio == null && !_isRecording)
                ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('Grabar Nota de Voz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              else if (_isRecording)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grabando...',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _stopRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Detener'),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Audio grabado',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'Duración: ${_formatDuration(_recordingDuration)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _deleteAudio,
                        icon: const Icon(Icons.delete, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Botón de envío
              PrimaryButton(
                text: _isUploadingFiles
                    ? 'Subiendo archivos...'
                    : 'Reportar Incidente',
                onPressed: _isLoading || _isUploadingFiles || _isRecording
                    ? null
                    : _handleSubmit,
                isLoading: _isLoading || _isUploadingFiles,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
