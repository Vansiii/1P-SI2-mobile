import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_2fa_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/verify_password_otp_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/security/presentation/two_factor_screen.dart';
import '../../features/security/presentation/session_history_screen.dart';
import '../../features/security/presentation/delete_account_screen.dart';
import '../../features/security/presentation/change_password_screen.dart';
import '../../features/security/presentation/security_screen.dart';
import '../../features/vehicles/presentation/vehicles_list_screen.dart';
import '../../features/vehicles/presentation/add_vehicle_screen.dart';
import '../../features/vehicles/presentation/vehicle_detail_screen.dart';
import '../../features/vehicles/presentation/edit_vehicle_screen.dart';
import '../../features/vehicles/presentation/vehicle_history_screen.dart';
import '../../features/incidents/presentation/incidents_list_screen.dart';
import '../../features/incidents/presentation/technician_incidents_screen.dart';
import '../../features/incidents/presentation/report_incident_screen.dart';
import '../../features/incidents/presentation/incident_detail_screen.dart';
import '../../features/incidents/presentation/workshop_selection_screen.dart';
import '../../features/incidents/presentation/workshop_map_screen.dart';
import '../../features/incidents/presentation/workshop_detail_screen.dart';
import '../../features/reports/presentation/client_reports_screen.dart';
import '../widgets/sync_center_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

/// App Router Configuration with GoRouter
final goRouterProvider = Provider<GoRouter>((ref) {
  // authNotifier se usa implícitamente a través de refreshListenable
  // ignore: unused_local_variable
  final authNotifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    // Usar refreshListenable para escuchar cambios sin reconstruir el router
    refreshListenable: _AuthStateNotifier(ref),
    redirect: (context, state) {
      // Permitir acceso al splash sin redirección
      if (state.matchedLocation == '/splash') {
        return null;
      }

      // Leer el estado actual sin watch para evitar reconstrucciones
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final hasError = authState.error != null;

      print(
        '🔄 Router redirect - isAuthenticated: $isAuthenticated, isLoading: $isLoading, location: ${state.matchedLocation}',
      );

      // Rutas públicas (accesibles sin autenticación)
      final publicRoutes = ['/login', '/register', '/forgot-password'];

      // Rutas de flujo de autenticación (no requieren estar autenticado, pero tampoco redirigen)
      final authFlowRoutes = [
        '/verify-2fa',
        '/verify-password-otp',
        '/reset-password',
      ];

      final isPublicRoute = publicRoutes.contains(state.matchedLocation);
      final isAuthFlowRoute = authFlowRoutes.any(
        (route) => state.matchedLocation.startsWith(route),
      );

      // Si está cargando, no redirigir
      if (isLoading) {
        print('⏳ Cargando, no redirigir');
        return null;
      }

      // Si hay un error, no redirigir (permitir que la pantalla muestre el error)
      if (hasError) {
        print('❌ Error presente, no redirigir');
        return null;
      }

      // Si está en flujo de autenticación (2FA, reset password), permitir acceso
      if (isAuthFlowRoute) {
        print('🔐 Flujo de autenticación, permitir acceso');
        return null;
      }

      // Si no está autenticado y trata de acceder a ruta privada
      if (!isAuthenticated && !isPublicRoute) {
        print('🚫 No autenticado, redirigir a login');
        return '/login';
      }

      // Si está autenticado y trata de acceder a ruta pública
      if (isAuthenticated && isPublicRoute) {
        print('✅ Autenticado en ruta pública, redirigir a home');
        return '/home';
      }

      print('✅ Sin redirección necesaria');
      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(path: '/', redirect: (context, state) => '/splash'),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-2fa/:email',
        name: 'verify-2fa',
        builder: (context, state) {
          final email = state.pathParameters['email']!;
          return Verify2FAScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-password-otp/:email',
        name: 'verify-password-otp',
        builder: (context, state) {
          final email = state.pathParameters['email']!;
          return VerifyPasswordOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/reset-password/:token',
        name: 'reset-password',
        builder: (context, state) {
          final token = state.pathParameters['token']!;
          return ResetPasswordScreen(token: token);
        },
      ),

      // Private Routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/sync-center',
        name: 'sync-center',
        builder: (context, state) => const SyncCenterScreen(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ClientReportsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/security',
        name: 'security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/two-factor',
        name: 'two-factor',
        builder: (context, state) => const TwoFactorScreen(),
      ),
      GoRoute(
        path: '/session-history',
        name: 'session-history',
        builder: (context, state) => const SessionHistoryScreen(),
      ),
      GoRoute(
        path: '/delete-account',
        name: 'delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),

      // Vehicles Routes
      GoRoute(
        path: '/vehicles',
        name: 'vehicles',
        builder: (context, state) => const VehiclesListScreen(),
      ),
      GoRoute(
        path: '/vehicles/add',
        name: 'add-vehicle',
        builder: (context, state) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: '/vehicles/:id',
        name: 'vehicle-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return VehicleDetailScreen(vehicleId: id);
        },
      ),
      GoRoute(
        path: '/vehicles/:id/edit',
        name: 'edit-vehicle',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return EditVehicleScreen(vehicleId: id);
        },
      ),
      GoRoute(
        path: '/vehicles/:id/history',
        name: 'vehicle-history',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return VehicleHistoryScreen(vehicleId: id);
        },
      ),

      // Incidents Routes
      GoRoute(
        path: '/incidents',
        name: 'incidents',
        builder: (context, state) => const IncidentsListScreen(),
      ),
      GoRoute(
        path: '/technician-incidents',
        name: 'technician-incidents',
        builder: (context, state) => const TechnicianIncidentsScreen(),
      ),
      GoRoute(
        path: '/incidents/report',
        name: 'report-incident',
        builder: (context, state) => const ReportIncidentScreen(),
      ),
      GoRoute(
        path: '/incidents/:id',
        name: 'incident-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return IncidentDetailScreen(incidentId: id);
        },
      ),
      GoRoute(
        path: '/incidents/:id/select-workshop',
        name: 'select-workshop',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return WorkshopSelectionScreen(
            incidentId: id,
            origin: state.uri.queryParameters['origin'] ?? 'report',
          );
        },
      ),
      GoRoute(
        path: '/incidents/:id/workshop-map',
        name: 'workshop-map',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return WorkshopMapScreen(
            incidentId: id,
            origin: state.uri.queryParameters['origin'] ?? 'report',
          );
        },
      ),
      GoRoute(
        path: '/incidents/:incidentId/workshop-detail/:workshopId',
        name: 'workshop-detail',
        builder: (context, state) {
          final incidentId =
              int.parse(state.pathParameters['incidentId']!);
          final workshopId =
              int.parse(state.pathParameters['workshopId']!);
          return WorkshopDetailScreen(
            key: ValueKey('workshop-detail-$incidentId-$workshopId'),
            incidentId: incidentId,
            workshopId: workshopId,
            origin: state.uri.queryParameters['origin'] ?? 'report',
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Página no encontrada',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Error desconocido',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
  );
});

/// Notifier para escuchar cambios en el estado de autenticación
/// sin reconstruir el router completo
class _AuthStateNotifier extends ChangeNotifier {
  final Ref _ref;

  _AuthStateNotifier(this._ref) {
    // Escuchar cambios en el provider
    _ref.listen<AuthState>(authProvider, (previous, next) {
      // Solo notificar si cambió isAuthenticated
      if (previous?.isAuthenticated != next.isAuthenticated) {
        print('🔔 AuthState cambió: isAuthenticated = ${next.isAuthenticated}');
        notifyListeners();
      }
    });
  }
}
