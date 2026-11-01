import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/services/local_storage_service.dart';

class ThemeController extends Cubit<ThemeMode> {
  ThemeController({required this.storageService}) : super(ThemeMode.system);

  final LocalStorageService storageService;

  Future<void> restoreTheme() async {
    final savedTheme = await storageService.getThemeMode();
    if (savedTheme == null) return;
    final mode = ThemeMode.values.firstWhere(
      (mode) => mode.name == savedTheme,
      orElse: () => ThemeMode.system,
    );
    emit(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    emit(mode);
    await storageService.saveThemeMode(mode.name);
  }
}