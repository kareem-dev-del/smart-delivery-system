import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/auth_controller.dart';
import 'package:shopease_mobile/controllers/profile_controller.dart'; // [جديد]
import 'package:shopease_mobile/services/local_storage_service.dart';

import 'auth_state.dart';

export 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.authController,
    required this.storageService,
    required this.profileController, // [جديد]
  }) : super(const AuthState(isLoading: true));

  final AuthController authController;
  final LocalStorageService storageService;
  final ProfileController profileController; // [جديد]

  Future<void> restoreSession() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await storageService.getUser();
      emit(AuthState(user: user, isLoading: false));
    } catch (e) {
      emit(AuthState(isLoading: false, error: _readableError(e)));
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await authController.requestPasswordReset(email.trim());
      emit(state.copyWith(isLoading: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _readableError(e)));
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await authController.login(username.trim(), password);
      await storageService.saveUser(user);
      emit(AuthState(user: user, isLoading: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _readableError(e)));
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await authController.register(
        username: username.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        password: password,
        passwordConfirm: passwordConfirm,
      );
      await storageService.saveUser(user);
      emit(AuthState(user: user, isLoading: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _readableError(e)));
      return false;
    }
  }

  // [جديد]
  Future<bool> updateProfile({
    required String name,
    required String email,
  }) async {
    emit(state.copyWith(isUpdatingProfile: true, clearError: true));
    try {
      final updatedUser = await profileController.updateProfile(
        name: name.trim(),
        email: email.trim(),
      );
      await storageService.saveUser(updatedUser);
      emit(state.copyWith(user: updatedUser, isUpdatingProfile: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isUpdatingProfile: false, error: _readableError(e)));
      return false;
    }
  }

  Future<bool> updateAvatar(File imageFile) async {
    emit(state.copyWith(isUploadingAvatar: true, clearError: true));
    try {
      final updatedUser = await profileController.uploadAvatar(imageFile);
      await storageService.saveUser(updatedUser);
      emit(state.copyWith(user: updatedUser, isUploadingAvatar: false));
      return true;
    } catch (e) {
      emit(state.copyWith(isUploadingAvatar: false, error: _readableError(e)));
      return false;
    }
  }

  Future<void> logout() async {
    await authController.logout();
    await storageService.clearUser();
    emit(const AuthState(isLoading: false));
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
