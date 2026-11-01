import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/cubits/checkout/checkout_cubit.dart';
import 'package:shopease_mobile/cubits/orders/orders_cubit.dart';
import 'package:shopease_mobile/models/cart_item.dart';
import 'package:shopease_mobile/models/locker_station.dart';
import 'package:shopease_mobile/services/locker_station_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.lockerStationService,
  });

  final LockerStationService lockerStationService;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<LockerStation> _stations = const [];
  LockerStation? _selectedStation;
  bool _loadingStations = false;
  bool _searchedStations = false;
  bool _usedDeviceLocation = false;
  String? _stationError;

  Future<void> _findStations(List<CartItem> cartItems) async {
    setState(() {
      _loadingStations = true;
      _stationError = null;
      _searchedStations = true;
    });
    try {
      final result = await widget.lockerStationService.findEligibleStations(
        productIds: cartItems.map((item) => item.product.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _stations = result.stations;
        _usedDeviceLocation = result.usedDeviceLocation;
        if (!_stations.any((station) => station.id == _selectedStation?.id)) {
          _selectedStation = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _stationError =
          error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingStations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, checkoutState) {
        if (checkoutState.orderPlaced) {
          return _OrderSuccessView(
            orderId: checkoutState.placedOrder?.id,
            orderTotal: checkoutState.placedOrder?.total,
            lockerName: checkoutState.placedOrder?.lockerName,
            onContinue: () {
              context.read<CartCubit>().clearCart();
              context.read<OrdersCubit>().loadOrders();
              context.read<CheckoutCubit>().reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          );
        }

        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            final total = cartState.totalPrice;
            return Scaffold(
              appBar: AppBar(title: const Text('Review order')),
              body: cartState.items.isEmpty
                  ? const Center(child: Text('Your cart is empty.'))
                  : SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (checkoutState.error != null) ...[
                                  _ErrorBanner(message: checkoutState.error!),
                                  const SizedBox(height: 16),
                                ],
                                Text(
                                  'Pickup locker',
                                  style: TextStyle(
                                    color: context.colors.foreground,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _usedDeviceLocation
                                      ? 'Available lockers are sorted by distance from your current location.'
                                      : 'Choose an eligible locker. Allow location access to sort the list by distance.',
                                  style: TextStyle(
                                      color: context.colors.mutedForeground),
                                ),
                                const SizedBox(height: 10),
                                if (_stations.isEmpty || _stationError != null)
                                  OutlinedButton.icon(
                                    onPressed: _loadingStations
                                        ? null
                                        : () => _findStations(cartState.items),
                                    icon: _loadingStations
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.near_me_outlined),
                                    label: Text(_loadingStations
                                        ? 'Finding lockers...'
                                        : _searchedStations
                                            ? 'Try again'
                                            : 'Find nearby lockers'),
                                  ),
                                if (_stationError != null) ...[
                                  const SizedBox(height: 8),
                                  _ErrorBanner(message: _stationError!),
                                ],
                                if (_stations.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _loadingStations
                                          ? null
                                          : () =>
                                              _findStations(cartState.items),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Refresh availability'),
                                    ),
                                  ),
                                if (_searchedStations &&
                                    !_loadingStations &&
                                    _stations.isEmpty &&
                                    _stationError == null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(
                                      'No online locker has an available drawer large enough for this order.',
                                      style: TextStyle(
                                          color: context.colors.mutedForeground),
                                    ),
                                  ),
                                for (final station in _stations)
                                  Card(
                                    margin: const EdgeInsets.only(top: 8),
                                    child: RadioListTile<int>(
                                      value: station.id,
                                      groupValue: _selectedStation?.id,
                                      onChanged: (value) => setState(() {
                                        _selectedStation = station;
                                      }),
                                      title: Text(station.name),
                                      subtitle: Text(
                                        '${station.address}\n${station.distanceKm == null ? 'Distance unavailable' : '${station.distanceKm!.toStringAsFixed(1)} km away'} · ${station.availableDrawersCount} compatible drawer${station.availableDrawersCount == 1 ? '' : 's'} available',
                                        maxLines: 3,
                                      ),
                                      isThreeLine: true,
                                    ),
                                  ),
                                const SizedBox(height: 22),
                                Text(
                                  'Order summary',
                                  style: TextStyle(
                                    color: context.colors.foreground,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Review the products and quantities. The server confirms current prices and stock when you place the order.',
                                  style: TextStyle(
                                      color: context.colors.mutedForeground),
                                ),
                                const SizedBox(height: 16),
                                Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      for (var i = 0;
                                          i < cartState.items.length;
                                          i++) ...[
                                        if (i > 0)
                                          Divider(
                                              height: 1,
                                              color: context.colors.border),
                                        Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      cartState.items[i].product
                                                          .name,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: context
                                                            .colors.foreground,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Qty ${cartState.items[i].quantity} × EGP ${cartState.items[i].product.price.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: context.colors
                                                            .mutedForeground,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'EGP ${(cartState.items[i].product.price * cartState.items[i].quantity).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color:
                                                      context.colors.foreground,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Estimated total',
                                          style: TextStyle(
                                            color: context.colors.foreground,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'EGP ${total.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: context.colors.primary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary
                                        .withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          color: context.colors.primary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'The server will reserve a compatible drawer at your chosen locker when the order is confirmed. Payment is not processed in this checkout.',
                                          style: TextStyle(
                                            color: context.colors.foreground,
                                            height: 1.4,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: checkoutState.isSubmitting ||
                                        _selectedStation == null
                                    ? null
                                    : () => context
                                        .read<CheckoutCubit>()
                                        .placeOrder(
                                          cartItems: cartState.items,
                                          lockerStationId:
                                              _selectedStation!.id,
                                        ),
                                child: checkoutState.isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Place order'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.destructive.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message,
            style: TextStyle(color: context.colors.destructive)),
      );
}

class _OrderSuccessView extends StatelessWidget {
  const _OrderSuccessView({
    required this.onContinue,
    this.orderId,
    this.orderTotal,
    this.lockerName,
  });

  final VoidCallback onContinue;
  final String? orderId;
  final double? orderTotal;
  final String? lockerName;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: context.colors.success, size: 76),
                const SizedBox(height: 20),
                Text(
                  'Order placed',
                  style: TextStyle(
                    color: context.colors.foreground,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lockerName == null
                      ? 'Your pickup locker has been reserved.'
                      : 'Pickup locker: $lockerName',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.mutedForeground),
                ),
                if (orderId != null) ...[
                  const SizedBox(height: 12),
                  SelectableText('Order #$orderId'),
                ],
                if (orderTotal != null) ...[
                  const SizedBox(height: 6),
                  Text('Confirmed total: EGP ${orderTotal!.toStringAsFixed(2)}'),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    child: const Text('Continue shopping'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
