import 'package:shopease_mobile/models/category.dart';
import 'package:shopease_mobile/models/product.dart';

class CatalogState {
  const CatalogState({
    this.featuredProducts = const [],
    this.categories = const [],
    this.products = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategoryId,
  });

  final List<Product> featuredProducts;
  final List<Category> categories;
  final List<Product> products;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String searchQuery;
  final String? selectedCategoryId;

  List<Product> get filteredProducts {
    var result = List<Product>.from(products);
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result =
          result
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.description.toLowerCase().contains(q) ||
                    p.category.toLowerCase().contains(q),
              )
              .toList();
    }
    if (selectedCategoryId != null) {
      result =
          result
              .where((product) => product.matchesCategory(selectedCategoryId!))
              .toList();
    }
    return result;
  }

  List<Product> productsByCategory(String categoryId) =>
      products.where((product) => product.matchesCategory(categoryId)).toList();

  CatalogState copyWith({
    List<Product>? featuredProducts,
    List<Category>? categories,
    List<Product>? products,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    String? searchQuery,
    String? selectedCategoryId,
    bool clearSelectedCategory = false,
  }) {
    return CatalogState(
      featuredProducts: featuredProducts ?? this.featuredProducts,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId:
          clearSelectedCategory
              ? null
              : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }
}
