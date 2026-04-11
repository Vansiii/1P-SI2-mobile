import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_constants.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers para campos comunes
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  // Controllers para cliente
  late TextEditingController _direccionController;
  late TextEditingController _ciController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;

    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _direccionController = TextEditingController(text: user?.direccion ?? '');
    _ciController = TextEditingController(text: user?.ci ?? '');
    _selectedDate = user?.fechaNacimiento;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _direccionController.dispose();
    _ciController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().subtract(const Duration(days: 6570)), // 18 años atrás
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final Map<String, dynamic> updateData = {};

      // Campos comunes
      if (_firstNameController.text.isNotEmpty) {
        updateData['first_name'] = _firstNameController.text.trim();
      }
      if (_lastNameController.text.isNotEmpty) {
        updateData['last_name'] = _lastNameController.text.trim();
      }
      if (_phoneController.text.isNotEmpty) {
        updateData['phone'] = _phoneController.text.trim();
      }

      // Campos específicos por tipo de usuario
      if (user.userType == AppConstants.userTypeClient) {
        if (_direccionController.text.isNotEmpty) {
          updateData['direccion'] = _direccionController.text.trim();
        }
        if (_ciController.text.isNotEmpty) {
          updateData['ci'] = _ciController.text.trim();
        }
        if (_selectedDate != null) {
          updateData['fecha_nacimiento'] = _selectedDate!.toIso8601String();
        }
      }

      // Actualizar perfil
      await ref.read(authRepositoryProvider).updateProfile(updateData);

      // Refrescar perfil
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Perfil actualizado exitosamente');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: AppColors.baseBg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Email (no editable)
              CustomTextField(
                label: 'Correo electrónico',
                controller: TextEditingController(text: user.email),
                enabled: false,
                prefixIcon: const Icon(Icons.email_outlined),
              ),

              const SizedBox(height: 16),

              // Nombre
              CustomTextField(
                label: 'Nombre',
                controller: _firstNameController,
                prefixIcon: const Icon(Icons.person_outline),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Apellido
              CustomTextField(
                label: 'Apellido',
                controller: _lastNameController,
                prefixIcon: const Icon(Icons.person_outline),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El apellido es requerido';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Teléfono
              CustomTextField(
                label: 'Teléfono',
                controller: _phoneController,
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El teléfono es requerido';
                  }
                  return null;
                },
              ),

              // Campos específicos para clientes
              if (user.userType == AppConstants.userTypeClient) ...[
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'CI',
                  controller: _ciController,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El CI es requerido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Dirección',
                  controller: _direccionController,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La dirección es requerida';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Fecha de nacimiento
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                          : 'Seleccionar fecha',
                      style: TextStyle(
                        color: _selectedDate != null
                            ? AppColors.textMain
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Botón guardar
              PrimaryButton(
                text: 'Guardar cambios',
                onPressed: _isLoading ? null : _saveProfile,
                isLoading: _isLoading,
                icon: Icons.save,
              ),

              const SizedBox(height: 16),

              // Botón cancelar
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => context.pop(),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
