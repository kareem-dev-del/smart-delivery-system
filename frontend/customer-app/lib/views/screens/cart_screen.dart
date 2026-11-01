import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.onContinueShopping,
    required this.onCheckout,
  });

  final VoidCallback onContinueShopping;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const LoadingState(message: 'Loading cart...');
        }

        if (state.items.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Your Cart')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                      color: context.colors.mutedForeground,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add products from Home or Categories.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.mutedForeground),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: onContinueShopping,
                      child: const Text('Start Shopping'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final subtotal = state.totalPrice;
        final shipping = subtotal > 100 ? 0.0 : 9.99;
        final tax = subtotal * 0.08;
        final total = subtotal + shipping + tax;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Your Cart'),
            actions: [
              TextButton(
                onPressed: () => context.read<CartCubit>().clearCart(),
                child: Text(
                  'Clear',
                  style: TextStyle(color: context.colors.primary),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: item.product.imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                memCacheWidth: 160,
                                fadeInDuration:
                                    const Duration(milliseconds: 200),
                                placeholder: (_, __) => SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: ColoredBox(color: context.colors.muted),
                                ),
                                errorWidget: (_, __, ___) => SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: ColoredBox(color: context.colors.muted),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.foreground,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${item.product.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: context.colors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _QtyButton(
                                        icon: Icons.remove,
                                        onTap: () => context
                                            .read<CartCubit>()
                                            .decrementQuantity(
                                                item.product.id),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      _QtyButton(
                                        icon: Icons.add,
                                        onTap: () => context
                                            .read<CartCubit>()
                                            .incrementQuantity(
                                                item.product.id),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => context
                                            .read<CartCubit>()
                                            .removeFromCart(item.product.id),
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: context.colors.destructive,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Order summary
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  border: Border(top: BorderSide(color: context.colors.border)),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                        label: 'Subtotal',
                        value: '\$${subtotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Shipping',
                      value: shipping == 0
                          ? 'Free'
                          : '\$${shipping.toStringAsFixed(2)}',
                      valueColor:
                          shipping == 0 ? context.colors.success : null,
                    ),
                    const SizedBox(height: 6),
                    _SummaryRow(
                        label: 'Tax (8%)',
                        value: '\$${tax.toStringAsFixed(2)}'),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Total',
                      value: '\$${total.toStringAsFixed(2)}',
                      labelStyle: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      valueStyle: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onCheckout,
                        child: const Text('Proceed to Checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: context.colors.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: context.colors.foreground),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: labelStyle ??
              TextStyle(
                  color: context.colors.mutedForeground, fontSize: 14),
        ),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                color: valueColor ?? context.colors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
