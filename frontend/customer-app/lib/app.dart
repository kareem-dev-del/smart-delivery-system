import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/theme_controller.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';

import 'core/routes/router.dart';
import 'core/routes/routes.dart';
import 'core/theme/app_theme.dart';

class ShopEaseApp extends StatefulWidget {
  const ShopEaseApp({super.key});

  @override
  State<ShopEaseApp> createState() => _ShopEaseAppState();
}

class _ShopEaseAppState extends State<ShopEaseApp> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeController(
        storageService: AppBlocProviders.storageService,
      )..restoreTheme(),
      child: BlocBuilder<ThemeController, ThemeMode>(
        builder: (context, themeMode) => MultiBlocProvider(
          providers: AppBlocProviders.providers,
          child: MaterialApp(
            navigatorKey: AppBlocProviders.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRouter.generateRoute,
          ),
        ),
      ),
    );
  }
}
