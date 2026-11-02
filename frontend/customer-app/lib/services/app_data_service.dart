import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/models/category.dart';
import 'package:shopease_mobile/models/product.dart';

abstract class AppDataService {
  Future<List<Product>> fetchProducts({String? category, String? search});

  Future<Product?> fetchProductById(String id);

  Future<List<Product>> fetchFeaturedProducts();

  Future<List<Category>> fetchCategories();

  Future<AppUser> loginUser(String email, String password);

  Future<AppUser> registerUser(String name, String email, String password);
}
