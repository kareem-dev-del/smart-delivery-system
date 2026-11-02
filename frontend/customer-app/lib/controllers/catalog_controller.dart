import 'package:shopease_mobile/models/category.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/repositories/catalog_repository.dart';

class CatalogController {
  CatalogController({required CatalogRepository catalogRepository})
      : _catalogRepository = catalogRepository;

  final CatalogRepository _catalogRepository;

  Future<List<Product>> fetchProducts({String? category, String? search}) {
    return _catalogRepository.fetchProducts(category: category, search: search);
  }

  Future<Product?> fetchProductById(String id) {
    return _catalogRepository.fetchProductById(id);
  }

  Future<List<Product>> fetchFeaturedProducts() {
    return _catalogRepository.fetchFeaturedProducts();
  }

  Future<List<Category>> fetchCategories() {
    return _catalogRepository.fetchCategories();
  }
}