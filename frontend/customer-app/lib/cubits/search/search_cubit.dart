import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/services/app_data_service.dart';

import 'search_state.dart';

export 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required this.dataService}) : super(const SearchState());

  final AppDataService dataService;

  Future<void> initialize({String initialQuery = ''}) async {
    if (state.sourceProducts.isNotEmpty) {
      emit(state.copyWith(query: initialQuery, clearError: true));
      return;
    }

    emit(state.copyWith(query: initialQuery, isLoading: true, clearError: true));
    try {
      final products = await dataService.fetchProducts();
      emit(state.copyWith(sourceProducts: products, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void setQuery(String value) => emit(state.copyWith(query: value));

  void setSort(SearchSort sort) => emit(state.copyWith(sort: sort));

  void setPriceRange(SearchPriceRange range) =>
      emit(state.copyWith(priceRange: range));

  void setRatingFilter(SearchRatingFilter filter) =>
      emit(state.copyWith(ratingFilter: filter));

  void setCategory(String category) => emit(state.copyWith(category: category));

  void resetFilters() => emit(state.copyWith(
        sort: SearchSort.featured,
        priceRange: SearchPriceRange.any,
        ratingFilter: SearchRatingFilter.any,
        category: 'all',
      ));
}
