import 'package:shopease_mobile/models/category.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/services/category_service.dart';
import 'package:shopease_mobile/services/product_service.dart';

class CatalogRepository {
  CatalogRepository({
    required ProductService productService,
    required CategoryService categoryService,
  })  : _productService = productService,
        _categoryService = categoryService;

  final ProductService _productService;
  final CategoryService _categoryService;

  Future<List<Product>> fetchProducts({String? category, String? search}) {
    return _productService.fetchProducts(category: category, search: search);
  }

  Future<Product?> fetchProductById(String id) {
    return _productService.fetchProductById(id);
  }

  Future<List<Product>> fetchFeaturedProducts() {
    return _productService.fetchFeaturedProducts();
  }

  Future<List<Category>> fetchCategories() {
    return _categoryService.fetchCategories();
  }
}