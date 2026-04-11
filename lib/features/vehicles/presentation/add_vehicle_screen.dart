import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../providers/vehicle_provider.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _matriculaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _colorController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  File? _selectedImage;
  String? _uploadedImageUrl;
  String? _selectedColor;
  bool _showCustomColorInput = false;

  // Colores predefinidos comunes para vehículos
  final List<Map<String, dynamic>> _vehicleColors = [
    {'name': 'Blanco', 'color': const Color(0xFFFFFFFF), 'border': true},
    {'name': 'Negro', 'color': const Color(0xFF000000)},
    {'name': 'Gris', 'color': const Color(0xFF9E9E9E)},
    {'name': 'Plata', 'color': const Color(0xFFC0C0C0), 'border': true},
    {'name': 'Rojo', 'color': const Color(0xFFE53935)},
    {'name': 'Azul', 'color': const Color(0xFF1E88E5)},
    {'name': 'Verde', 'color': const Color(0xFF43A047)},
    {'name': 'Amarillo', 'color': const Color(0xFFFDD835), 'border': true},
    {'name': 'Naranja', 'color': const Color(0xFFFF6F00)},
    {'name': 'Café', 'color': const Color(0xFF6D4C41)},
    {'name': 'Beige', 'color': const Color(0xFFD7CCC8), 'border': true},
    {'name': 'Morado', 'color': const Color(0xFF8E24AA)},
  ];

  @override
  void dispose() {
    _matriculaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _colorController.dispose();
    super.dispose();
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
        setState(() {
          _selectedImage = File(pickedFile.path);
        });

        // Subir imagen automáticamente
        await _uploadImage();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final imageUrl = await ref
          .read(vehiclesProvider.notifier)
          .uploadVehicleImage(_selectedImage!);

      setState(() {
        _uploadedImageUrl = imageUrl;
        _isUploadingImage = false;
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Imagen subida exitosamente');
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<void> _deleteImage() async {
    // Si la imagen ya fue subida, eliminarla del storage
    if (_uploadedImageUrl != null) {
      try {
        await ref
            .read(vehiclesProvider.notifier)
            .deleteVehicleImage(_uploadedImageUrl!);

        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Imagen eliminada');
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(
            context,
            'Error al eliminar imagen: ${e.toString()}',
          );
        }
      }
    }

    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(vehiclesProvider.notifier)
          .createVehicle(
            matricula: _matriculaController.text.trim().toUpperCase(),
            marca: _marcaController.text.trim().isEmpty
                ? null
                : _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            anio: int.parse(_anioController.text.trim()),
            color: _selectedColor?.isEmpty ?? true ? null : _selectedColor,
            imagen: _uploadedImageUrl,
          );

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Vehículo registrado exitosamente');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Agregar Vehículo'),
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
              // Selector de imagen con botones interactivos
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
                    : _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _showFullImage(context, _selectedImage!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImage!,
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
                                  onTap: () =>
                                      _showFullImage(context, _selectedImage!),
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
                                  onTap: _deleteImage,
                                  color: AppColors.error,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _uploadedImageUrl != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _showFullImageUrl(context, _uploadedImageUrl!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _uploadedImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: AppColors.error,
                                    ),
                                  );
                                },
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
                                  onTap: () => _showFullImageUrl(
                                    context,
                                    _uploadedImageUrl!,
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
                                  onTap: _deleteImage,
                                  color: AppColors.error,
                                ),
                              ],
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
                              'Agregar foto del vehículo',
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
              const SizedBox(height: 24),
              CustomTextField(
                controller: _matriculaController,
                label: 'Placa / Matrícula *',
                hint: 'ABC-1234',
                prefixIcon: const Icon(Icons.pin),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La placa es requerida';
                  }
                  if (value.trim().length < 3) {
                    return 'La placa debe tener al menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _marcaController,
                label: 'Marca',
                hint: 'Toyota, Ford, etc.',
                prefixIcon: const Icon(Icons.branding_watermark),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _modeloController,
                label: 'Modelo *',
                hint: 'Corolla, Focus, etc.',
                prefixIcon: const Icon(Icons.directions_car),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El modelo es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _anioController,
                label: 'Año *',
                hint: '2020',
                prefixIcon: const Icon(Icons.calendar_today),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El año es requerido';
                  }
                  final anio = int.tryParse(value.trim());
                  if (anio == null) {
                    return 'Ingresa un año válido';
                  }
                  if (anio < 1900 || anio > DateTime.now().year + 1) {
                    return 'Año fuera de rango válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Selector de color mejorado
              Text(
                'Color',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 12),

              // Grid de colores predefinidos
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount:
                    _vehicleColors.length + 1, // +1 para opción personalizada
                itemBuilder: (context, index) {
                  if (index == _vehicleColors.length) {
                    // Opción de color personalizado
                    return _buildCustomColorOption();
                  }

                  final colorData = _vehicleColors[index];
                  final isSelected = _selectedColor == colorData['name'];

                  return _buildColorOption(
                    name: colorData['name'],
                    color: colorData['color'],
                    isSelected: isSelected,
                    hasBorder: colorData['border'] ?? false,
                  );
                },
              ),

              // Input de color personalizado (se muestra cuando se selecciona)
              if (_showCustomColorInput) ...[
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _colorController,
                  label: 'Color Personalizado',
                  hint: 'Ej: Azul Metálico',
                  prefixIcon: const Icon(Icons.palette),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() => _selectedColor = value);
                    }
                  },
                ),
              ],

              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Registrar Vehículo',
                onPressed: _isLoading ? null : _handleSubmit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para opción de color
  Widget _buildColorOption({
    required String name,
    required Color color,
    required bool isSelected,
    bool hasBorder = false,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = name;
          _showCustomColorInput = false;
          _colorController.clear();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: hasBorder
                    ? Border.all(color: AppColors.border, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? Icon(Icons.check, color: _getContrastColor(color), size: 24)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Widget para opción de color personalizado
  Widget _buildCustomColorOption() {
    final isSelected = _showCustomColorInput;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomColorInput = true;
          _selectedColor = null;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE53935),
                    Color(0xFF1E88E5),
                    Color(0xFF43A047),
                    Color(0xFFFDD835),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'Otro',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Obtener color de contraste para el check
  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Método para mostrar imagen completa (File)
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

  // Método para mostrar imagen completa (URL)
  void _showFullImageUrl(BuildContext context, String imageUrl) {
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
                child: Image.network(imageUrl),
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

  // Widget para botones de fuente de imagen (cuando no hay imagen)
  Widget _buildImageSourceButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
        onTap: onTap,
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
