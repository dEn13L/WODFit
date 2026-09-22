import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/theme_service.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final ThemeService themeService;

  ThemeCubit({required this.themeService}) : super(themeService.themeMode);

  void toggleTheme() {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }

  void setThemeMode(ThemeMode mode) {
    emit(mode);
    themeService.setThemeMode(mode);
  }
}
