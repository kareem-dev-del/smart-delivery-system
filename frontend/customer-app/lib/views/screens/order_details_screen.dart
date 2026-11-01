import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/core/utils/date_formatter.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/cubits/order_details/order_details_cubit.dart';
import 'package:shopease_mobile/cubits/orders/orders_cubit.dart';
import 'package:shopease_mobile/models/order.dart';
import 'package:shopease_mobile/models/payment_method.dart';
import 'package:shopease_mobile/views/widgets/error_state.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';

// [جديد] — شاشة تفاصيل الأوردر المستقلة، بتستبدل الـbottom sheet المؤقت
// اللي كان في orders_screen.dart. الـOrderDetailsCubit بتاعتها cubit
// مستقل (شوف order_details_cubit.dart) بيعيد استخدام OrdersController
// الموجود أصلًا بدل ما يكرر نفس الـmodel/service/repository.
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderDetailsCubit>(
      create: (_) => OrderDetailsCubit(
        ordersController: AppBlocProviders.ordersController,
      )..loadOrder(orderId),
      child: _OrderDetailsView(orderId: orderId),
    );
  }
}

class _OrderDetailsView extends StatelessWidget {
  const _OrderDetailsView({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderDetailsCubit, OrderDetailsState>(
      builder: (context, state) {
        final order = state.order;
        return Scaffold(
          appBar: AppBar(
            title: Text(order != null ? 'Order #${order.id}' : 'Order Details'),
          ),
          body: _buildBody(context, state),
          bottomNavigationBar:
              order == null ? null : _BottomActions(order: order),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, OrderDetailsState state) {
    if (state.isLoading && state.order == null) {
      return const LoadingState(message: 'Loading order...');
    }

    if (state.error != null && state.order == null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => context.read<OrderDetailsCubit>().loadOrder(orderId),
      );
    }

    final order = state.order;
    if (order == null) {
      return const ErrorState(message: 'Order not found.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Status + progress ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatusBadge(status: order.status),
                  Text(
                    'Placed ${DateFormatter.date(order.date)}',
                    style: TextStyle(
                        color: context.colors.mutedForeground, fontSize: 12.5),
                  ),
                ],
              ),
              if (!{
                OrderStatus.cancelled,
                OrderStatus.expired,
                OrderStatus.returned,
              }.contains(order.status)) ...[
                const SizedBox(height: 16),
                _OrderProgress(status: order.status),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Items ───────────────────────────────────────────────────
        const _SectionHeader(title: 'ITEMS'),
        Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (int i = 0; i < order.items.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _OrderItemRow(item: order.items[i]),
              ],
              if (order.items.isEmpty)
                Text(
                  'No item details available for this order.',
                  style: TextStyle(color: context.colors.mutedForeground),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Delivery ────────────────────────────────────────────────
        const _SectionHeader(title: 'DELIVERY'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              _DetailRow(
                  label: 'Placed on', value: DateFormatter.date(order.date)),
              if (order.status == OrderStatus.collected)
                _DetailRow(
                  label: 'Delivered on',
                  value: DateFormatter.date(
                      order.deliveredDate ?? order.date),
                )
              else if (order.estimatedDelivery != null)
                _DetailRow(
                  label: 'Estimated delivery',
                  value: DateFormatter.date(order.estimatedDelivery),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Payment ─────────────────────────────────────────────────
        if (order.paymentMethod != null) ...[
          const _SectionHeader(title: 'PAYMENT'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(_paymentIcon(order.paymentMethod!.type),
                    color: context.colors.mutedForeground, size: 20),
                const SizedBox(width: 10),
                Text(
                  order.paymentMethod!.isCard &&
                          order.paymentMethod!.lastFour != null
                      ? '${order.paymentMethod!.displayName} •••• ${order.paymentMethod!.lastFour}'
                      : order.paymentMethod!.displayName,
                  style: TextStyle(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Total ───────────────────────────────────────────────────
        const _SectionHeader(title: 'SUMMARY'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: _DetailRow(
            label: 'Total',
            value: 'EGP ${order.total.toStringAsFixed(2)}',
            emphasize: true,
          ),
        ),

        if (state.error != null && state.order != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!,
            style: TextStyle(
                color: context.colors.destructive, fontSize: 12.5),
          ),
        ],
      ],
    );
  }

  IconData _paymentIcon(PaymentMethodType type) => switch (type) {
        PaymentMethodType.visa ||
        PaymentMethodType.mastercard ||
        PaymentMethodType.amex =>
          Icons.credit_card_rounded,
        PaymentMethodType.paypal => Icons.account_balance_wallet_outlined,
        PaymentMethodType.cashOnDelivery => Icons.payments_outlined,
      };
}

// [جديد] — بار تحت الشاشة فيه الأكشنز (Cancel/Track/Buy Again)، بنفس
// المنطق بتاع orders_screen.dart بالظبط عشان الاتنين يتصرفوا بنفس الطريقة
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final isCancelling =
        context.watch<OrderDetailsCubit>().state.isCancelling;

    final buttons = <Widget>[];

    if (order.isCancellable) {
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: isCancelling ? null : () => _confirmCancel(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.destructive,
              side: BorderSide(color: context.colors.destructive),
            ),
            child: isCancelling
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.colors.destructive),
                  )
                : const Text('Cancel Order'),
          ),
        ),
      );
    }

    if (order.status == OrderStatus.collected) {
      buttons.add(
        Expanded(
          child: ElevatedButton(
            onPressed: () => _buyAgain(context),
            child: const Text('Buy Again'),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Cancel Order',
            style: TextStyle(color: context.colors.foreground)),
        content: Text(
          'Are you sure you want to cancel order #${order.id}? This cannot be undone.',
          style: TextStyle(color: context.colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Cancel Order',
                style: TextStyle(color: context.colors.destructive)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final detailsCubit = context.read<OrderDetailsCubit>();
    final success = await detailsCubit.cancelOrder();

    if (!context.mounted) return;

    if (success) {
      // بنحدّث الليستة المشتركة في OrdersCubit (شوف الـcomment في di.dart)
      // عشان لو المستخدم رجع لشاشة My Orders يلاقي الأوردر محدث فورًا
      // من غير ما يحتاج pull-to-refresh يدوي
      context.read<OrdersCubit>().loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order #${order.id} has been cancelled.'),
      ));
    } else {
      final error = detailsCubit.state.error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Could not cancel the order.'),
      ));
    }
  }

  Future<void> _buyAgain(BuildContext context) async {
    final cartCubit = context.read<CartCubit>();
    for (final item in order.items) {
      for (int i = 0; i < item.quantity; i++) {
        await cartCubit.addToCart(item.toProduct());
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} added to cart.'),
      action: SnackBarAction(
        label: 'View Cart',
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.cart),
      ),
    ));
  }
}

// [جديد] — progress bar بسيط بين 3 مراحل (Processing/Shipped/Delivered)،
// منفصل عمدًا عن التفاصيل الزمنية الكاملة اللي هتبقى في TrackOrderScreen
class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final currentIndex = switch (status) {
      OrderStatus.pending || OrderStatus.awaitingLocker => 0,
      OrderStatus.assigned => 1,
      OrderStatus.readyForPickup => 2,
      OrderStatus.collected => 3,
      OrderStatus.expired || OrderStatus.cancelled || OrderStatus.returned => -1,
    };

    const labels = ['Placed', 'Locker', 'Ready', 'Collected'];

    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIndex
                    ? context.colors.primary
                    : context.colors.border,
              ),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= currentIndex
                      ? context.colors.primary
                      : context.colors.muted,
                ),
                alignment: Alignment.center,
                child: i < currentIndex
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i <= currentIndex
                              ? Colors.white
                              : context.colors.mutedForeground,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: i <= currentIndex
                      ? context.colors.foreground
                      : context.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.colors.muted,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: item.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 96,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                      color: context.colors.mutedForeground),
                  errorWidget: (_, __, ___) => Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                      color: context.colors.mutedForeground),
                )
              : Icon(Icons.image_not_supported_outlined,
                  size: 18, color: context.colors.mutedForeground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5)),
              const SizedBox(height: 2),
              Text('Qty ${item.quantity} • \$${item.price.toStringAsFixed(2)} each',
                  style: TextStyle(
                      color: context.colors.mutedForeground, fontSize: 12)),
            ],
          ),
        ),
        Text('\$${item.subtotal.toStringAsFixed(2)}',
            style: TextStyle(
                color: context.colors.foreground,
                fontWeight: FontWeight.w700,
                fontSize: 13.5)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.colors.mutedForeground, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: context.colors.foreground,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              fontSize: emphasize ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.mutedForeground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.pending || OrderStatus.awaitingLocker =>
        (status.label, context.colors.star),
      OrderStatus.assigned || OrderStatus.readyForPickup =>
        (status.label, context.colors.secondary),
      OrderStatus.collected => (status.label, context.colors.success),
      OrderStatus.expired || OrderStatus.cancelled =>
        (status.label, context.colors.destructive),
      OrderStatus.returned => (status.label, context.colors.mutedForeground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
