import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/core/utils/date_formatter.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/cubits/orders/orders_cubit.dart';
import 'package:shopease_mobile/models/order.dart';
import 'package:shopease_mobile/models/payment_method.dart';

// [تعديل] — كانت الشاشة دي كلها UI hardcoded (5 أوردرات وهمية مكتوبة يدوي)
// من غير أي اتصال بأي cubit أو controller. دلوقتي بتحمّل الأوردرات الحقيقية
// من OrdersCubit اللي بينادي على /orders فعليًا، وفيها loading/error/empty
// states زي باقي الشاشات في المشروع (شوف wishlist/cart screens).
//
// [تعديل] — OrdersCubit بقت global provider دلوقتي (شوف di.dart)، بدل ما
// كانت بتتعمل هنا محليًا؛ عشان OrderDetailsScreen (اللي بتتفتح فوقها بـ
// Navigator.push) تقدر توصل لنفس الـinstance وتحدّث الليستة بعد أي تعديل
// (زي إلغاء أوردر) من غير reload يدوي أو pop-result hacks.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        unawaited(context.read<OrdersCubit>().loadOrders(silent: true));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const _OrdersView();
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('My Orders')),
          body: RefreshIndicator(
            color: context.colors.primary,
            onRefresh: () => context.read<OrdersCubit>().loadOrders(),
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, OrdersState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline_rounded,
              size: 48, color: context.colors.destructive),
          const SizedBox(height: 12),
          Text(
            state.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.mutedForeground),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () => context.read<OrdersCubit>().loadOrders(),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (state.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: 80),
          Icon(Icons.receipt_long_outlined,
              size: 48, color: context.colors.mutedForeground),
          SizedBox(height: 12),
          Text(
            'No orders yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.foreground,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your placed orders will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.mutedForeground),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: state.orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _OrderCard(order: state.orders[index]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    // بنسمع للـcancellingOrderId بس عشان نعرف الكارت ده لوحده هيعرض
    // loading ولا لأ، من غير ما نحتاج StatefulWidget أو state محلي
    final isCancelling =
        context.watch<OrdersCubit>().state.cancellingOrderId == order.id;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .pushNamed(AppRoutes.orderDetails, arguments: order.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.id}',
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Product thumbnails ─────────────────────────────────
              Row(
                children: [
                  _ItemThumbnails(items: order.items),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order.items.isEmpty
                          ? '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}'
                          : order.items.map((i) => i.name).join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Delivery status line ────────────────────────────────
              Row(
                children: [
                  Icon(_deliveryIcon(order.status),
                      size: 14, color: _deliveryColor(context, order.status)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _deliveryLabel(order),
                      style: TextStyle(
                        color: _deliveryColor(context, order.status),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: context.colors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    'Placed ${DateFormatter.date(order.date)}',
                    style: TextStyle(
                        color: context.colors.mutedForeground, fontSize: 12.5),
                  ),
                  const Spacer(),
                  Icon(Icons.shopping_bag_outlined,
                      size: 14, color: context.colors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: context.colors.mutedForeground, fontSize: 12.5),
                  ),
                ],
              ),

              // ── Payment method ──────────────────────────────────────
              if (order.paymentMethod != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(_paymentIcon(order.paymentMethod!.type),
                        size: 14, color: context.colors.mutedForeground),
                    const SizedBox(width: 6),
                    Text(
                      order.paymentMethod!.isCard &&
                              order.paymentMethod!.lastFour != null
                          ? '${order.paymentMethod!.displayName} •••• ${order.paymentMethod!.lastFour}'
                          : order.paymentMethod!.displayName,
                      style: TextStyle(
                          color: context.colors.mutedForeground, fontSize: 12.5),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                  'Total: EGP ${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (order.isCancellable)
                        OutlinedButton(
                          onPressed: isCancelling
                              ? null
                              : () => _confirmCancel(context, order),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.destructive,
                            side: BorderSide(
                                color: context.colors.destructive),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: isCancelling
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.destructive,
                                  ),
                                )
                              : const Text('Cancel Order',
                                  style: TextStyle(fontSize: 12)),
                        ),
                      if (order.status == OrderStatus.collected)
                        OutlinedButton(
                          onPressed: () => _buyAgain(context, order),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Buy Again',
                              style: TextStyle(fontSize: 12)),
                        )
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _deliveryIcon(OrderStatus status) => switch (status) {
        OrderStatus.pending || OrderStatus.awaitingLocker =>
          Icons.hourglass_top_rounded,
        OrderStatus.assigned || OrderStatus.readyForPickup =>
          Icons.inventory_2_outlined,
        OrderStatus.collected => Icons.check_circle_outline_rounded,
        OrderStatus.expired || OrderStatus.cancelled => Icons.cancel_outlined,
        OrderStatus.returned => Icons.keyboard_return_rounded,
      };

  Color _deliveryColor(BuildContext context, OrderStatus status) =>
      switch (status) {
        OrderStatus.pending || OrderStatus.awaitingLocker => context.colors.star,
        OrderStatus.assigned || OrderStatus.readyForPickup =>
          context.colors.secondary,
        OrderStatus.collected => context.colors.success,
        OrderStatus.expired || OrderStatus.cancelled =>
          context.colors.destructive,
        OrderStatus.returned => context.colors.mutedForeground,
      };

  String _deliveryLabel(Order order) => switch (order.status) {
        OrderStatus.pending => 'Order received',
        OrderStatus.awaitingLocker => 'Waiting for locker assignment',
        OrderStatus.assigned => order.lockerName == null
            ? 'Locker assigned'
            : 'Assigned to ${order.lockerName}',
        OrderStatus.readyForPickup => order.lockerName == null
            ? 'Ready for pickup'
            : 'Ready at ${order.lockerName}',
        OrderStatus.collected =>
          'Collected on ${DateFormatter.date(order.deliveredDate ?? order.date)}',
        OrderStatus.expired => 'Pickup window expired',
        OrderStatus.cancelled => 'Order cancelled',
        OrderStatus.returned => 'Order returned',
      };

  IconData _paymentIcon(PaymentMethodType type) => switch (type) {
        PaymentMethodType.visa ||
        PaymentMethodType.mastercard ||
        PaymentMethodType.amex =>
          Icons.credit_card_rounded,
        PaymentMethodType.paypal => Icons.account_balance_wallet_outlined,
        PaymentMethodType.cashOnDelivery => Icons.payments_outlined,
      };

  // [جديد] — بيتأكد قبل الإلغاء زي نفس pattern الحذف في all_reviews_screen
  Future<void> _confirmCancel(BuildContext context, Order order) async {
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

    final cubit = context.read<OrdersCubit>();
    await cubit.cancelOrder(order.id);

    if (!context.mounted) return;
    final error = cubit.state.error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Order #${order.id} has been cancelled.'),
    ));
  }

  // [جديد] — بيضيف كل عناصر الأوردر للسلة بنفس الكمية اللي كانت متطلوبة،
  // عن طريق CartCubit الموجود أصلًا في الـDI (مفيش حاجة جديدة محتاجة هنا)
  Future<void> _buyAgain(BuildContext context, Order order) async {
    final cartCubit = context.read<CartCubit>();
    for (final item in order.items) {
      for (int i = 0; i < item.quantity; i++) {
        await cartCubit.addToCart(item.toProduct());
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${order.itemCount} item${order.itemCount == 1 ? '' : 's'} added to cart.'),
      action: SnackBarAction(
        label: 'View Cart',
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.cart),
      ),
    ));
  }
}

// [جديد] — عرض صور أول 3 منتجات جوه الأوردر متكدسة فوق بعض زي أمازون/نون،
// وبادج "+N" لو فيه عناصر زيادة
class _ItemThumbnails extends StatelessWidget {
  const _ItemThumbnails({required this.items});

  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.colors.muted,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.shopping_bag_outlined,
            size: 18, color: context.colors.mutedForeground),
      );
    }

    final visible = items.take(3).toList();
    final extra = items.length - visible.length;

    return SizedBox(
      width: (40 + (visible.length - 1) * 14 + (extra > 0 ? 14 : 0)).toDouble(),
      height: 40,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: (i * 14).toDouble(),
              child: _Thumbnail(imageUrl: visible[i].imageUrl),
            ),
          if (extra > 0)
            Positioned(
              left: (visible.length * 14).toDouble(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.foreground.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.card, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.colors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.card, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 80,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => Icon(
                  Icons.image_not_supported_outlined,
                  size: 16,
                  color: context.colors.mutedForeground),
              errorWidget: (_, __, ___) => Icon(
                  Icons.image_not_supported_outlined,
                  size: 16,
                  color: context.colors.mutedForeground),
            )
          : Icon(Icons.image_not_supported_outlined,
              size: 16, color: context.colors.mutedForeground),
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
