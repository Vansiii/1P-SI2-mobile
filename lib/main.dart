import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_constants.dart';
import 'core/router/app_router.dart';
import 'shared/utils/snackbar_utils.dart';
import 'data/services/api_service.dart';
import 'features/auth/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: MerchanicRepairApp()));
}

class MerchanicRepairApp extends ConsumerStatefulWidget {
  const MerchanicRepairApp({super.key});

  @override
  ConsumerState<MerchanicRepairApp> createState() => _MerchanicRepairAppState();
}

class _MerchanicRepairAppState extends ConsumerState<MerchanicRepairApp> {
  @override
  void initState() {
    super.initState();

    // Configurar callback para manejar sesión expirada
    ApiService.onSessionExpired = () {
      // Invalidar el auth provider para forzar logout
      ref.invalidate(authProvider);
    };
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      scaffoldMessengerKey: SnackBarUtils.scaffoldMessengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      locale: const Locale('es', 'ES'),
    );
  }
}
