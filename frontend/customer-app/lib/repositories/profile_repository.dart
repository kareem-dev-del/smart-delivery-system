import 'dart:io';

import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/services/profile_service.dart';

class ProfileRepository {
  ProfileRepository({required ProfileService profileService})
      : _profileService = profileService;

  final ProfileService _profileService;

  Future<AppUser> updateProfile({required String name, required String email}) {
    return _profileService.updateProfile(name: name, email: email);
  }

  Future<AppUser> uploadAvatar(File imageFile) {
  return _profileService.uploadAvatar(imageFile);
  }
}