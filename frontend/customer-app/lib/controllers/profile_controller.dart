import 'dart:io';

import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/repositories/profile_repository.dart';

class ProfileController {
  ProfileController({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository;

  final ProfileRepository _profileRepository;

  Future<AppUser> updateProfile({required String name, required String email}) {
    return _profileRepository.updateProfile(name: name, email: email);
  }

  Future<AppUser> uploadAvatar(File imageFile) {
  return _profileRepository.uploadAvatar(imageFile);
}
}