import 'package:shopease_mobile/models/product.dart';

enum SearchSort { featured, priceAsc, priceDesc, rating }

enum SearchPriceRange { any, under50, from50to200, from200to500, over500 }

enum SearchRatingFilter { any, from4, from45 }

class SearchState {
  const SearchState({
    this.query = '',
    this.sourceProducts = const [],
    this.isLoading = false,
    this.error,
    this.sort = SearchSort.featured,
    this.priceRange = SearchPriceRange.any,
    this.ratingFilter = SearchRatingFilter.any,
    this.category = 'all',
  });

  final String query;
  final List<Product> sourceProducts;
  final bool isLoading;
  final String? error;
  final SearchSort sort;
  final SearchPriceRange priceRange;
  final SearchRatingFilter ratingFilter;
  final String category;

  bool get isSearching => isLoading;

  int get activeFilterCount {
    var count = 0;
    if (sort != SearchSort.featured) count++;
    if (priceRange != SearchPriceRange.any) count++;
    if (ratingFilter != SearchRatingFilter.any) count++;
    if (category != 'all') count++;
    return count;
  }

  List<String> get categoryOptions {
    final cats = sourceProducts.map((p) => p.category).toSet().toList()..sort();
    return ['all', ...cats];
  }

  List<Product> get results {
    var items = List<Product>.from(sourceProducts);

    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      items =
          items
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.description.toLowerCase().contains(q) ||
                    p.category.toLowerCase().contains(q),
              )
              .toList();
    }

    if (category != 'all') {
      items = items.where((p) => p.matchesCategory(category)).toList();
    }

    switch (priceRange) {
      case SearchPriceRange.any:
        break;
      case SearchPriceRange.under50:
        items = items.where((p) => p.price < 50).toList();
        break;
      case SearchPriceRange.from50to200:
        items = items.where((p) => p.price >= 50 && p.price <= 200).toList();
        break;
      case SearchPriceRange.from200to500:
        items = items.where((p) => p.price > 200 && p.price <= 500).toList();
        break;
      case SearchPriceRange.over500:
        items = items.where((p) => p.price > 500).toList();
        break;
    }

    switch (ratingFilter) {
      case SearchRatingFilter.any:
        break;
      case SearchRatingFilter.from4:
        items = items.where((p) => p.rating >= 4.0).toList();
        break;
      case SearchRatingFilter.from45:
        items = items.where((p) => p.rating >= 4.5).toList();
        break;
    }

    switch (sort) {
      case SearchSort.featured:
        items.sort(
          (a, b) => (b.badge != null ? 1 : 0) - (a.badge != null ? 1 : 0),
        );
        break;
      case SearchSort.priceAsc:
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SearchSort.priceDesc:
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SearchSort.rating:
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }

    return items;
  }

  SearchState copyWith({
    String? query,
    List<Product>? sourceProducts,
    bool? isLoading,
    String? error,
    bool clearError = false,
    SearchSort? sort,
    SearchPriceRange? priceRange,
    SearchRatingFilter? ratingFilter,
    String? category,
  }) {
    return SearchState(
      query: query ?? this.query,
      sourceProducts: sourceProducts ?? this.sourceProducts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sort: sort ?? this.sort,
      priceRange: priceRange ?? this.priceRange,
      ratingFilter: ratingFilter ?? this.ratingFilter,
      category: category ?? this.category,
    );
  }
}
