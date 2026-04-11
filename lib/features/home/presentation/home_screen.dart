import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../security/presentation/security_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ProfileScreen(),
    SecurityScreen(),
  ];

  Future<void> _openCamera() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null && mounted) {
        SnackBarUtils.showSuccess(context, 'Foto capturada: ${photo.name}');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error al abrir cámara: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 3) {
            // Cámara
            _openCamera();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            activeIcon: Icon(Icons.security),
            label: 'Seguridad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: 'Cámara',
          ),
        ],
      ),
    );
  }
}
