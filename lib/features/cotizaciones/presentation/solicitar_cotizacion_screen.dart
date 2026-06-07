import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/shared/widgets/custom_text_field.dart';
import 'package:merchanic_repair/shared/widgets/primary_button.dart';
import 'package:merchanic_repair/shared/utils/snackbar_utils.dart';
import 'package:merchanic_repair/features/auth/providers/auth_provider.dart';
import 'package:merchanic_repair/features/vehicles/providers/vehicle_provider.dart';
import 'package:merchanic_repair/features/cotizaciones/providers/cotizacion_provider.dart';

class SolicitarCotizacionScreen extends ConsumerStatefulWidget {
  const SolicitarCotizacionScreen({super.key});

  @override
  ConsumerState<SolicitarCotizacionScreen> createState() => _SolicitarCotizacionScreenState();
}

class _SolicitarCotizacionScreenState extends ConsumerState<SolicitarCotizacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _radioController = TextEditingController(text: '15');
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  int? _selectedVehicleId;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  bool _isUploading = false;
  bool _isRecording = false;

  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  File? _audioFile;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _direccionController.dispose();
    _radioController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Servicios de ubicacion deshabilitados');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permiso de ubicacion denegado');
      }
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() { _currentPosition = position; _isLoadingLocation = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      SnackBarUtils.showError(context, 'Error al obtener ubicacion: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
      if (picked != null && mounted) setState(() => _selectedImages.add(File(picked.path)));
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Error al seleccionar imagen');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) SnackBarUtils.showError(context, 'Permiso de microfono denegado');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/cot_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Error al grabar audio');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() { _isRecording = false; if (path != null) _audioFile = File(path); });
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Error al detener grabacion');
    }
  }

  Future<void> _uploadFiles(int cotizacionId) async {
    setState(() => _isUploading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      for (final img in _selectedImages) {
        final fd = FormData.fromMap({'file': await MultipartFile.fromFile(img.path, filename: img.path.split('/').last)});
        final r = await apiService.dio.post('${ApiConfig.apiVersion}/cotizaciones/$cotizacionId/upload-image', data: fd);
        _uploadedImageUrls.add((r.data as Map)['data']['url'] as String);
      }
      if (_audioFile != null) {
        final fd = FormData.fromMap({'file': await MultipartFile.fromFile(_audioFile!.path, filename: _audioFile!.path.split('/').last)});
        await apiService.dio.post('${ApiConfig.apiVersion}/cotizaciones/$cotizacionId/upload-audio', data: fd);
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Error al subir archivos');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) { SnackBarUtils.showError(context, 'Esperando ubicacion GPS...'); return; }
    if (_selectedVehicleId == null) { SnackBarUtils.showError(context, 'Selecciona un vehiculo'); return; }

    setState(() => _isSubmitting = true);
    try {
      final notifier = ref.read(cotizacionesProvider.notifier);
      final cotizacion = await notifier.solicitarCotizacion(
        vehiculoId: _selectedVehicleId!,
        latitud: _currentPosition!.latitude,
        longitud: _currentPosition!.longitude,
        direccionReferencia: _direccionController.text.isNotEmpty ? _direccionController.text : null,
        descripcionDano: _descripcionController.text.trim(),
        imagenesDano: [],
        radioBusquedaKm: double.tryParse(_radioController.text) ?? 15.0,
      );
      if (_selectedImages.isNotEmpty || _audioFile != null) await _uploadFiles(cotizacion.id);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Cotizacion solicitada. Los talleres recibiran tu solicitud.');
      context.push('/cotizaciones');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Solicitar Cotizacion'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 24),
          children: [
            _buildSection(
              icon: Icons.directions_car_outlined,
              title: 'Vehiculo',
              child: _buildVehicleSelector(vehicles),
            ),
            const SizedBox(height: 14),
            _buildSection(
              icon: Icons.location_on_outlined,
              title: 'Ubicacion',
              child: _buildLocationPicker(),
            ),
            const SizedBox(height: 14),
            _buildSection(
              icon: Icons.description_outlined,
              title: 'Descripcion del dano',
              child: Column(
                children: [
                  CustomTextField(
                    controller: _descripcionController,
                    label: 'Describe el problema',
                    hint: 'Ej: El motor no enciende, hace un ruido extrano...',
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Minimo 10 caracteres' : null,
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: _radioController,
                    label: 'Radio de busqueda (km)',
                    hint: '15',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildSection(
              icon: Icons.photo_camera_outlined,
              title: 'Evidencias',
              child: _buildMediaPicker(),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              onPressed: (_isSubmitting || _isUploading) ? null : _submit,
              text: _isUploading ? 'Subiendo archivos...' : _isSubmitting ? 'Enviando...' : 'Solicitar Cotizacion',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMain.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textMain)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildVehicleSelector(AsyncValue vehicles) {
    return vehicles.when(
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                const Text('No tienes vehiculos registrados', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/vehicles/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar vehiculo'),
                ),
              ],
            ),
          );
        }
        final items = list.map<DropdownMenuItem<int>>((v) =>
          DropdownMenuItem<int>(value: v.id, child: Text('${v.marca ?? ''} ${v.modelo} (${v.matricula})'))
        ).toList();
        return DropdownButtonFormField<int>(
          initialValue: _selectedVehicleId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            hintText: 'Selecciona tu vehiculo',
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: items,
          onChanged: (v) => setState(() => _selectedVehicleId = v),
          validator: (v) => v == null ? 'Requerido' : null,
        );
      },
      loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Text('Error al cargar vehiculos: $e', style: const TextStyle(color: AppColors.error)),
    );
  }

  Widget _buildLocationPicker() {
    if (_isLoadingLocation) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_currentPosition == null) return const Text('No se pudo obtener ubicacion', style: TextStyle(color: AppColors.textMuted));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.my_location, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                tooltip: 'Actualizar ubicacion',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CustomTextField(
          controller: _direccionController,
          label: 'Referencia (opcional)',
          hint: 'Ej: Frente a la plaza principal',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildMediaPicker() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Camara'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galeria'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.file(_selectedImages[i], width: 100, height: 100, fit: BoxFit.cover),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _isRecording
                  ? OutlinedButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop, color: AppColors.error, size: 18),
                      label: const Text('Detener grabacion', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                  : _audioFile != null
                      ? OutlinedButton.icon(
                          onPressed: () => setState(() => _audioFile = null),
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                          label: const Text('Eliminar audio', style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _startRecording,
                          icon: const Icon(Icons.mic_outlined, size: 18),
                          label: const Text('Grabar audio'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
            ),
          ],
        ),
        if (_isRecording) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('Grabando...', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ],
    );
  }
}
