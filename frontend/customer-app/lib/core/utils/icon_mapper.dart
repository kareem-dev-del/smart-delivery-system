import 'package:flutter/material.dart';

/// Maps a category name to a suitable Material icon.
/// Add or adjust entries to match the categories your app returns.
class IconMapper {
  IconMapper._();

  static IconData forCategory(String name) {
    final key = name.toLowerCase().trim();

    if (key.contains('electron') || key.contains('tech') || key.contains('gadget')) {
      return Icons.devices_outlined;
    }
    if (key.contains('phone') || key.contains('mobile')) {
      return Icons.smartphone_outlined;
    }
    if (key.contains('laptop') || key.contains('computer')) {
      return Icons.laptop_outlined;
    }
    if (key.contains('cloth') || key.contains('fashion') || key.contains('apparel') || key.contains('wear')) {
      return Icons.checkroom_outlined;
    }
    if (key.contains('shoe') || key.contains('footwear') || key.contains('sneaker')) {
      return Icons.directions_run_outlined;
    }
    if (key.contains('jewelry') || key.contains('jewel') || key.contains('watch') || key.contains('accessory') || key.contains('accessories')) {
      return Icons.watch_outlined;
    }
    if (key.contains('beauty') || key.contains('cosmetic') || key.contains('skincare') || key.contains('makeup')) {
      return Icons.face_retouching_natural_outlined;
    }
    if (key.contains('sport') || key.contains('fitness') || key.contains('gym') || key.contains('outdoor')) {
      return Icons.fitness_center_outlined;
    }
    if (key.contains('home') || key.contains('furniture') || key.contains('decor') || key.contains('kitchen')) {
      return Icons.home_outlined;
    }
    if (key.contains('garden') || key.contains('plant') || key.contains('outdoor')) {
      return Icons.local_florist_outlined;
    }
    if (key.contains('book') || key.contains('education') || key.contains('stationery')) {
      return Icons.menu_book_outlined;
    }
    if (key.contains('toy') || key.contains('kids') || key.contains('baby') || key.contains('children')) {
      return Icons.toys_outlined;
    }
    if (key.contains('food') || key.contains('grocery') || key.contains('drink') || key.contains('beverage')) {
      return Icons.local_grocery_store_outlined;
    }
    if (key.contains('health') || key.contains('pharmacy') || key.contains('medicine') || key.contains('wellness')) {
      return Icons.health_and_safety_outlined;
    }
    if (key.contains('pet') || key.contains('animal')) {
      return Icons.pets_outlined;
    }
    if (key.contains('auto') || key.contains('car') || key.contains('vehicle')) {
      return Icons.directions_car_outlined;
    }
    if (key.contains('music') || key.contains('audio') || key.contains('headphone')) {
      return Icons.headphones_outlined;
    }
    if (key.contains('camera') || key.contains('photo') || key.contains('video')) {
      return Icons.camera_alt_outlined;
    }
    if (key.contains('game') || key.contains('gaming') || key.contains('console')) {
      return Icons.sports_esports_outlined;
    }
    if (key.contains('bag') || key.contains('luggage') || key.contains('travel')) {
      return Icons.luggage_outlined;
    }
    if (key.contains('tool') || key.contains('hardware') || key.contains('diy')) {
      return Icons.build_outlined;
    }
    if (key.contains('office') || key.contains('business') || key.contains('supply')) {
      return Icons.business_center_outlined;
    }

    // Default fallback
    return Icons.category_outlined;
  }
}
