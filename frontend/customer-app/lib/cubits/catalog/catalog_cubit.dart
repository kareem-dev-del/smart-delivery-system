import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/catalog_controller.dart';
import 'package:shopease_mobile/models/product.dart';

import 'catalog_state.dart';

export 'catalog_state.dart';

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit({required this.catalogController}) : super(const CatalogState());

  final CatalogController catalogController;

  Future<void> loadInitial({bool isRefresh = false}) async {
    if (isRefresh) {
      emit(state.copyWith(isRefreshing: true, clearError: true));
    } else {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      final featured = await catalogController.fetchFeaturedProducts();
      final categories = await catalogController.fetchCategories();
      final products = await catalogController.fetchProducts();
      emit(state.copyWith(
        featuredProducts: featured,
        categories: categories,
        products: products,
        isLoading: false,
        isRefreshing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<Product?> fetchProductById(String productId) async {
    try {
      return state.products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return catalogController.fetchProductById(productId);
    }
  }

  void setSearchQuery(String value) {
    emit(state.copyWith(searchQuery: value));
  }

  void setSelectedCategory(String? categoryId) {
    if (categoryId == null) {
      emit(state.copyWith(clearSelectedCategory: true));
    } else {
      emit(state.copyWith(selectedCategoryId: categoryId));
    }
  }
}