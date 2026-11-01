import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/cubits/wishlist/wishlist_cubit.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';
import 'package:shopease_mobile/views/widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WishlistCubit, WishlistState>(
      builder: (context, wishlistState) {
        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            if (wishlistState.isLoading) {
              return const Scaffold(
                body: LoadingState(message: 'Loading your wishlist...'),
              );
            }

            final items = wishlistState.items;
            final width = MediaQuery.of(context).size.width;
            final cardWidth = (width - 48) / 2;

            if (items.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('Wishlist')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border_rounded,
                            size: 72, color: context.colors.mutedForeground),
                        const SizedBox(height: 12),
                        Text(
                          'Your wishlist is empty',
                          style: TextStyle(
                              color: context.colors.foreground,
                              fontSize: 22,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save items you love and find them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.mutedForeground),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Start Shopping'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: Text('Wishlist (${items.length})'),
                actions: [
                  TextButton(
                    onPressed: () => context.read<WishlistCubit>().clearAll(),
                    style: TextButton.styleFrom(
                        foregroundColor: context.colors.destructive),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items.map((product) {
                    return Stack(
                      children: [
                        ProductCard(
                          product: product,
                          width: cardWidth,
                          inCart: cartState.isInCart(product.id),
                          onOpen: () => Navigator.of(context).pushNamed(
                              AppRoutes.product,
                              arguments: product.id),
                          onAddToCart: () =>
                              context.read<CartCubit>().addToCart(product),
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: GestureDetector(
                            onTap: () => context
                                .read<WishlistCubit>()
                                .removeProduct(product.id),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                  color: context.colors.primary,
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.favorite_rounded,
                                  color: Colors.white, size: 15),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}