import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/core/utils/date_formatter.dart';
import 'package:shopease_mobile/cubits/track_order/track_order_cubit.dart';
import 'package:shopease_mobile/models/order_tracking.dart';
import 'package:shopease_mobile/views/widgets/error_state.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';

class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TrackOrderCubit>(
      create:
          (_) => TrackOrderCubit(
            trackOrderController: AppBlocProviders.trackOrderController,
          )..loadTracking(orderId),
      child: _TrackOrderView(orderId: orderId),
    );
  }
}

class _TrackOrderView extends StatefulWidget {
  const _TrackOrderView({required this.orderId});

  final String orderId;

  @override
  State<_TrackOrderView> createState() => _TrackOrderViewState();
}

class _TrackOrderViewState extends State<_TrackOrderView> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        unawaited(context
            .read<TrackOrderCubit>()
            .loadTracking(widget.orderId, silent: true));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Track Order')),
      body: BlocBuilder<TrackOrderCubit, TrackOrderState>(
        builder: (context, state) {
          if (state.isLoading && state.tracking == null) {
            return const LoadingState(message: 'Fetching tracking info...');
          }

          if (state.error != null && state.tracking == null) {
            return ErrorState(
              message: state.error!,
              onRetry:
                  () => context.read<TrackOrderCubit>().loadTracking(widget.orderId),
            );
          }

          final tracking = state.tracking;
          if (tracking == null) {
            return const ErrorState(message: 'Tracking info not available.');
          }

          return RefreshIndicator(
            color: context.colors.primary,
            onRefresh:
                () => context.read<TrackOrderCubit>().loadTracking(widget.orderId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ── Summary card ────────────────────────────────────
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
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: context.colors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusLabel(tracking.status),
                              style: TextStyle(
                                color: context.colors.foreground,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _statusDescription(tracking.status),
                        style: TextStyle(
                          color: context.colors.mutedForeground,
                          fontSize: 12.5,
                        ),
                      ),
                      if (tracking.lockerName != null) ...[
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.storefront_outlined,
                          label: 'Pickup station',
                          value: tracking.lockerName!,
                        ),
                      ],
                      if (tracking.lockerAddress != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          value: tracking.lockerAddress!,
                        ),
                      ],
                      if (tracking.lockerCode != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Station code',
                          value: tracking.lockerCode!,
                        ),
                      ],
                      if (tracking.drawerNumber != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Reserved drawer',
                          value: 'Drawer ${tracking.drawerNumber}',
                        ),
                      ],
                      if (tracking.estimatedDelivery != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.schedule_outlined,
                          label: 'Pickup deadline',
                          value: DateFormatter.dateTime(
                            tracking.estimatedDelivery,
                          ),
                        ),
                      ],
                      if (tracking.currentLocation != null) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Current location',
                          value: tracking.currentLocation!,
                        ),
                      ],
                      if (tracking.courier != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.local_shipping_outlined,
                          label: 'Courier',
                          value: tracking.courier!,
                        ),
                      ],
                      if (tracking.trackingNumber != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Tracking number',
                          value: tracking.trackingNumber!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Timeline ─────────────────────────────────────────
                if (tracking.steps.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < tracking.steps.length; i++)
                          _TimelineStep(
                            step: tracking.steps[i],
                            isLast: i == tracking.steps.length - 1,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'awaiting_locker' => 'Waiting for locker assignment',
    'assigned' => 'Courier assigned',
    'ready_for_pickup' => 'Ready for pickup',
    'collected' => 'Collected',
    'expired' => 'Pickup window expired',
    'cancelled' => 'Cancelled',
    'returned' => 'Returned to locker',
    _ => status.replaceAll('_', ' '),
  };

  String _statusDescription(String status) => switch (status) {
    'awaiting_locker' => 'We are preparing your order for a locker station.',
    'assigned' =>
      'Your order is assigned and awaiting delivery to the station.',
    'ready_for_pickup' => 'Your order is waiting at the station shown below.',
    'collected' => 'Your order has been picked up successfully.',
    'expired' => 'The pickup period ended. The order is being returned.',
    'cancelled' => 'This order was cancelled.',
    'returned' => 'The order was returned to the locker station.',
    _ => 'Here are the latest updates for your order.',
  };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.mutedForeground),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: context.colors.mutedForeground,
            fontSize: 12.5,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// [جديد] — كل خطوة زمنية في تايم لاين التتبع (Order Placed → Confirmed →
// Shipped → Out for Delivery → Delivered) بنقطة ملونة وخط واصل بينهم
class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.step, required this.isLast});

  final TrackingStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color =
        step.isCompleted || step.isCurrent
            ? context.colors.primary
            : context.colors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.isCompleted ? color : context.colors.card,
                  border: Border.all(color: color, width: 2),
                ),
                child:
                    step.isCurrent
                        ? Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.primary,
                          ),
                        )
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        step.isCompleted
                            ? context.colors.primary
                            : context.colors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color:
                          step.isCompleted || step.isCurrent
                              ? context.colors.foreground
                              : context.colors.mutedForeground,
                      fontWeight:
                          step.isCurrent ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  if (step.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.description!,
                      style: TextStyle(
                        color: context.colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (step.timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.dateTime(step.timestamp),
                      style: TextStyle(
                        color: context.colors.mutedForeground,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
