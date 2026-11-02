import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/cubits/search/search_cubit.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';
import 'package:shopease_mobile/views/widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    context
        .read<SearchCubit>()
        .initialize(initialQuery: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, searchState) {
        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            final width = MediaQuery.of(context).size.width;
            final cardWidth = (width - 48) / 2;

            return Scaffold(
              appBar: AppBar(
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        context.read<SearchCubit>().setQuery(v),
                    autofocus: true,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                context
                                    .read<SearchCubit>()
                                    .setQuery('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.tune_rounded),
                        if (searchState.activeFilterCount > 0)
                          Positioned(
                            right: -7,
                            top: -5,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${searchState.activeFilterCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              body: Column(
                children: [
                  // Filters panel
                  if (_filtersExpanded) ...[
                    _FiltersPanel(
                      state: searchState,
                      onSortChanged: (v) =>
                          context.read<SearchCubit>().setSort(v),
                      onPriceChanged: (v) =>
                          context.read<SearchCubit>().setPriceRange(v),
                      onRatingChanged: (v) =>
                          context.read<SearchCubit>().setRatingFilter(v),
                      onCategoryChanged: (v) =>
                          context.read<SearchCubit>().setCategory(v),
                      onReset: () =>
                          context.read<SearchCubit>().resetFilters(),
                    ),
                    const Divider(height: 1),
                  ],

                  Expanded(
                    child: searchState.isLoading
                        ? const LoadingState(message: 'Searching...')
                        : searchState.results.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 64,
                                        color: context.colors.mutedForeground,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        searchState.query.trim().isEmpty
                                            ? 'Start typing to search'
                                            : 'No results for "${searchState.query}"',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: context.colors.mutedForeground,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: searchState.results
                                      .map(
                                        (product) => ProductCard(
                                          product: product,
                                          width: cardWidth,
                                          inCart: cartState
                                              .isInCart(product.id),
                                          onOpen: () => Navigator.of(context)
                                              .pushNamed(
                                            AppRoutes.product,
                                            arguments: product.id,
                                          ),
                                          onAddToCart: () => context
                                              .read<CartCubit>()
                                              .addToCart(product),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.state,
    required this.onSortChanged,
    required this.onPriceChanged,
    required this.onRatingChanged,
    required this.onCategoryChanged,
    required this.onReset,
  });

  final SearchState state;
  final ValueChanged<SearchSort> onSortChanged;
  final ValueChanged<SearchPriceRange> onPriceChanged;
  final ValueChanged<SearchRatingFilter> onRatingChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Sort
          _FilterDropdown<SearchSort>(
            label: 'Sort',
            value: state.sort,
            items: const {
              SearchSort.featured: 'Featured',
              SearchSort.priceAsc: 'Price: Low',
              SearchSort.priceDesc: 'Price: High',
              SearchSort.rating: 'Rating',
            },
            onChanged: onSortChanged,
          ),
          const SizedBox(width: 8),

          // Price
          _FilterDropdown<SearchPriceRange>(
            label: 'Price',
            value: state.priceRange,
            items: const {
              SearchPriceRange.any: 'Any Price',
              SearchPriceRange.under50: 'Under \$50',
              SearchPriceRange.from50to200: '\$50–\$200',
              SearchPriceRange.from200to500: '\$200–\$500',
              SearchPriceRange.over500: 'Over \$500',
            },
            onChanged: onPriceChanged,
          ),
          const SizedBox(width: 8),

          // Rating
          _FilterDropdown<SearchRatingFilter>(
            label: 'Rating',
            value: state.ratingFilter,
            items: const {
              SearchRatingFilter.any: 'Any Rating',
              SearchRatingFilter.from4: '4+ Stars',
              SearchRatingFilter.from45: '4.5+ Stars',
            },
            onChanged: onRatingChanged,
          ),
          const SizedBox(width: 8),

          // Category
          _FilterDropdown<String>(
            label: 'Category',
            value: state.category,
            items: {
              for (final cat in state.categoryOptions) cat: cat,
            },
            onChanged: onCategoryChanged,
          ),
          const SizedBox(width: 12),

          if (state.activeFilterCount > 0)
            TextButton(
              onPressed: onReset,
              child: const Text('Reset'),
            ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.muted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
