import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_constants.dart';
import '../../../shared/utils/snackbar_utils.dart';
import '../../../shared/utils/permission_utils.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../security/presentation/security_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../incidents/presentation/technician_incidents_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  Future<void> _openCamera() async {
    final photo = await PermissionUtils.requestCameraAndTakePhoto(context);

    if (photo != null && mounted) {
      SnackBarUtils.showSuccess(context, 'Foto capturada: ${photo.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Si es técnico, mostrar navegación con incidencias
    if (user?.userType == AppConstants.userTypeTechnician) {
      return _buildTechnicianHome();
    }

    // Vista completa para clientes
    return _buildClientHome();
  }

  Widget _buildTechnicianHome() {
    final List<Widget> technicianScreens = [
      const DashboardScreen(),
      const TechnicianIncidentsScreen(
        key: ValueKey('technician_incidents_updated'),
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: technicianScreens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Incidencias',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildClientHome() {
    final List<Widget> clientScreens = const [
      DashboardScreen(),
      ProfileScreen(),
      SecurityScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: clientScreens),
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
