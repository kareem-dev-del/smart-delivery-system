import 'package:flutter/foundation.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/services/app_data_service.dart';

enum SearchSort { featured, priceAsc, priceDesc, rating }

enum SearchPriceRange { any, under50, from50to200, from200to500, over500 }

enum SearchRatingFilter { any, from4, from45 }

class SearchController extends ChangeNotifier {
  SearchController({required this.dataService});

  final AppDataService dataService;

  bool _isLoading = false;
  String? _error;
  List<Product> _sourceProducts = <Product>[];
  String _query = '';
  SearchSort _sort = SearchSort.featured;
  SearchPriceRange _priceRange = SearchPriceRange.any;
  SearchRatingFilter _ratingFilter = SearchRatingFilter.any;
  String _category = 'all';

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get query => _query;
  SearchSort get sort => _sort;
  SearchPriceRange get priceRange => _priceRange;
  SearchRatingFilter get ratingFilter => _ratingFilter;
  String get category => _category;

  int get activeFilterCount {
    var count = 0;
    if (_sort != SearchSort.featured) count++;
    if (_priceRange != SearchPriceRange.any) count++;
    if (_ratingFilter != SearchRatingFilter.any) count++;
    if (_category != 'all') count++;
    return count;
  }

  List<String> get categoryOptions {
    final categories =
        _sourceProducts.map((product) => product.category).toSet().toList()
          ..sort();
    return <String>['all', ...categories];
  }

  Future<void> initialize({String initialQuery = ''}) async {
    _query = initialQuery;
    _error = null;

    if (_sourceProducts.isNotEmpty) {
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      _sourceProducts = await dataService.fetchProducts();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setSort(SearchSort sort) {
    _sort = sort;
    notifyListeners();
  }

  void setPriceRange(SearchPriceRange range) {
    _priceRange = range;
    notifyListeners();
  }

  void setRatingFilter(SearchRatingFilter filter) {
    _ratingFilter = filter;
    notifyListeners();
  }

  void setCategory(String category) {
    _category = category;
    notifyListeners();
  }

  void resetFilters() {
    _sort = SearchSort.featured;
    _priceRange = SearchPriceRange.any;
    _ratingFilter = SearchRatingFilter.any;
    _category = 'all';
    notifyListeners();
  }

  List<Product> get results {
    var items = List<Product>.from(_sourceProducts);

    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase().trim();
      items =
          items
              .where(
                (product) =>
                    product.name.toLowerCase().contains(q) ||
                    product.description.toLowerCase().contains(q) ||
                    product.category.toLowerCase().contains(q),
              )
              .toList();
    }

    if (_category != 'all') {
      items =
          items.where((product) => product.matchesCategory(_category)).toList();
    }

    switch (_priceRange) {
      case SearchPriceRange.any:
        break;
      case SearchPriceRange.under50:
        items = items.where((product) => product.price < 50).toList();
        break;
      case SearchPriceRange.from50to200:
        items =
            items
                .where((product) => product.price >= 50 && product.price <= 200)
                .toList();
        break;
      case SearchPriceRange.from200to500:
        items =
            items
                .where((product) => product.price > 200 && product.price <= 500)
                .toList();
        break;
      case SearchPriceRange.over500:
        items = items.where((product) => product.price > 500).toList();
        break;
    }

    switch (_ratingFilter) {
      case SearchRatingFilter.any:
        break;
      case SearchRatingFilter.from4:
        items = items.where((product) => product.rating >= 4.0).toList();
        break;
      case SearchRatingFilter.from45:
        items = items.where((product) => product.rating >= 4.5).toList();
        break;
    }

    switch (_sort) {
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
}
