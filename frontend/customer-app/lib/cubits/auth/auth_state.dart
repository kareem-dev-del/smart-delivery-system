import 'package:shopease_mobile/models/app_user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.isUpdatingProfile = false,   // [جديد]
    this.isUploadingAvatar = false,   // [جديد]
    this.error,
  });

  final AppUser? user;
  final bool isLoading;
  final bool isUpdatingProfile;   // [جديد]
  final bool isUploadingAvatar;   // [جديد]
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    bool? isUpdatingProfile,   // [جديد]
    bool? isUploadingAvatar,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isUpdatingProfile: isUpdatingProfile ?? this.isUpdatingProfile,   // [جديد]
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
