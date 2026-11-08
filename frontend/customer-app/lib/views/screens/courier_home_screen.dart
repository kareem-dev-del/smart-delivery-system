import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/models/courier_order.dart';
import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/services/courier_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key, required this.service});

  final CourierService service;

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  List<CourierOrder> _assignments = const [];
  List<CourierOrder> _returns = const [];
  bool _isOnShift = false;
  bool _isLoading = true;
  bool _isUpdatingShift = false;
  String? _error;
  Timer? _refreshTimer;
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_loadInProgress) _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.service.getAssignments(),
        widget.service.getReturns(),
        widget.service.getIsOnShift(),
      ]);
      if (!mounted) return;
      setState(() {
        _assignments = results[0] as List<CourierOrder>;
        _returns = results[1] as List<CourierOrder>;
        _isOnShift = results[2] as bool;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_assignments.isEmpty && _returns.isEmpty) {
          _error = error.toString().replaceFirst('Exception: ', '');
        }
        if (!silent) _isLoading = false;
      });
    } finally {
      _loadInProgress = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _changeShift() async {
    if (_isOnShift && (_assignments.isNotEmpty || _returns.isNotEmpty)) {
      _showMessage(
        'Finish or reassign your active orders before ending your shift.',
      );
      return;
    }
    setState(() => _isUpdatingShift = true);
    try {
      final nextShift = await widget.service.setShift(!_isOnShift);
      if (!mounted) return;
      setState(() => _isOnShift = nextShift);
      _showMessage(
        nextShift ? 'Your shift has started.' : 'Your shift has ended.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUpdatingShift = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthCubit>().logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOrderDetails(CourierOrder order, {required bool isReturn}) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder:
          (context) => _CourierOrderDetailsSheet(
            order: order,
            isReturn: isReturn,
            onCopyAddress: _copyLockerAddress,
            onOpenDirections: _openDirections,
          ),
    );
  }

  Future<void> _copyLockerAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (mounted) _showMessage('Locker address copied.');
  }

  Future<void> _openDirections(CourierOrder order) async {
    final destination =
        order.lockerLatitude != null && order.lockerLongitude != null
            ? '${order.lockerLatitude},${order.lockerLongitude}'
            : [order.lockerAddress, order.lockerName, order.lockerCode]
                .whereType<String>()
                .where((part) => part.trim().isNotEmpty)
                .join(', ');
    if (destination.isEmpty) {
      _showMessage('No locker destination is available for this order.');
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Could not open directions on this device.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not open directions on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = context.select<AuthCubit, AppUser?>(
      (cubit) => cubit.state.user,
    );
    final displayName = user?.name.trim();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Courier hub'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed:
                () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.notifications, arguments: true),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Refresh assignments',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Text(
              'Hello${displayName == null || displayName.isEmpty ? '' : ', $displayName'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your deliveries and shift status, in one place.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
            ),
            const SizedBox(height: 18),
            _ShiftPanel(
              isOnShift: _isOnShift,
              isUpdating: _isUpdatingShift,
              activeOrderCount: _assignments.length + _returns.length,
              onPressed: _changeShift,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CountPanel(
                    label: 'Deliveries',
                    count: _assignments.length,
                    icon: Icons.local_shipping_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CountPanel(
                    label: 'Returns',
                    count: _returns.length,
                    icon: Icons.assignment_return_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeading(title: 'My deliveries', count: _assignments.length),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _load)
            else if (_assignments.isEmpty)
              const _EmptyPanel(
                icon: Icons.inbox_outlined,
                title: 'No deliveries assigned',
                subtitle: 'New assignments will appear here.',
              )
            else
              ..._assignments.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrderPanel(
                    order: order,
                    isReturn: false,
                    onTap: () => _showOrderDetails(order, isReturn: false),
                  ),
                ),
              ),
            if (!_isLoading && _error == null) ...[
              const SizedBox(height: 16),
              _SectionHeading(
                title: 'Returns to locker',
                count: _returns.length,
              ),
              const SizedBox(height: 10),
              if (_returns.isEmpty)
                const _EmptyPanel(
                  icon: Icons.assignment_return_outlined,
                  title: 'No returns assigned',
                  subtitle: 'Orders requiring return will show up here.',
                )
              else
                ..._returns.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OrderPanel(
                      order: order,
                      isReturn: true,
                      onTap: () => _showOrderDetails(order, isReturn: true),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftPanel extends StatelessWidget {
  const _ShiftPanel({
    required this.isOnShift,
    required this.isUpdating,
    required this.activeOrderCount,
    required this.onPressed,
  });

  final bool isOnShift;
  final bool isUpdating;
  final int activeOrderCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canEndShift = !isOnShift || activeOrderCount == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 11,
                color: isOnShift ? colors.success : colors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                isOnShift ? 'You are on shift' : 'You are off shift',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            isOnShift
                ? activeOrderCount == 0
                    ? 'You can receive delivery assignments.'
                    : 'You have $activeOrderCount active task${activeOrderCount == 1 ? '' : 's'}. Finish them before ending your shift.'
                : 'Start your shift when you are ready to receive work.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isUpdating || !canEndShift ? null : onPressed,
              icon: Icon(
                isOnShift
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              label: Text(
                isUpdating
                    ? 'Updating...'
                    : isOnShift
                    ? 'End shift'
                    : 'Start shift',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPanel extends StatelessWidget {
  const _CountPanel({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (count != null)
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.mutedForeground,
            ),
          ),
      ],
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.order,
    required this.isReturn,
    required this.onTap,
  });

  final CourierOrder order;
  final bool isReturn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.shortReference}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isReturn
                              ? colors.destructive.withValues(alpha: 0.1)
                              : colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isReturn ? 'Return' : _statusLabel(order.status),
                      style: TextStyle(
                        color: isReturn ? colors.destructive : colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: colors.mutedForeground),
                ],
              ),
              const SizedBox(height: 12),
              _OrderInfoRow(
                icon: Icons.storefront_outlined,
                title: order.lockerName ?? 'Locker station not assigned',
                detail:
                    order.lockerAddress ??
                    order.lockerCode ??
                    'Address unavailable',
              ),
              if (order.drawerNumber != null) ...[
                const SizedBox(height: 9),
                _OrderInfoRow(
                  icon: Icons.inventory_2_outlined,
                  title: 'Drawer ${order.drawerNumber}',
                  detail: 'Use the assigned drawer for this order.',
                ),
              ],
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 9),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '× ${item.quantity}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'awaiting_locker' => 'Awaiting locker',
    'assigned' => 'Assigned',
    'expired' => 'Return required',
    _ => status.replaceAll('_', ' '),
  };
}

class _CourierOrderDetailsSheet extends StatelessWidget {
  const _CourierOrderDetailsSheet({
    required this.order,
    required this.isReturn,
    required this.onCopyAddress,
    required this.onOpenDirections,
  });

  final CourierOrder order;
  final bool isReturn;
  final ValueChanged<String> onCopyAddress;
  final ValueChanged<CourierOrder> onOpenDirections;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final address = order.lockerAddress;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      builder:
          (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.shortReference}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusBadge(
                    label:
                        isReturn
                            ? 'Return required'
                            : _statusLabel(order.status),
                    isReturn: isReturn,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionHeading(title: 'Locker destination', count: null),
              const SizedBox(height: 10),
              _OrderInfoRow(
                icon: Icons.storefront_outlined,
                title: order.lockerName ?? 'Locker station not assigned',
                detail: order.lockerAddress ?? 'Address unavailable',
              ),
              if (order.lockerCode != null) ...[
                const SizedBox(height: 12),
                _OrderInfoRow(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Station code',
                  detail: order.lockerCode!,
                ),
              ],
              if (order.drawerNumber != null) ...[
                const SizedBox(height: 12),
                _OrderInfoRow(
                  icon: Icons.inventory_2_outlined,
                  title: 'Assigned drawer',
                  detail: 'Drawer ${order.drawerNumber}',
                ),
              ],
              if (order.lockerAddress != null ||
                  (order.lockerLatitude != null &&
                      order.lockerLongitude != null)) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => onOpenDirections(order),
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Open directions'),
                  ),
                ),
              ],
              if (address != null && address.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => onCopyAddress(address),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy locker address'),
                ),
              ],
              const SizedBox(height: 24),
              _SectionHeading(
                title: 'Package contents',
                count: order.items.length,
              ),
              const SizedBox(height: 10),
              if (order.items.isEmpty)
                const _EmptyPanel(
                  icon: Icons.inventory_2_outlined,
                  title: 'No item details available',
                  subtitle:
                      'Refresh the task list to load the latest order data.',
                )
              else
                ...order.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colors.primary.withValues(alpha: 0.1),
                      foregroundColor: colors.primary,
                      child: Text('${item.quantity}'),
                    ),
                    title: Text(item.name),
                    subtitle: Text('Parcel size: ${item.sizeLabel}'),
                    trailing: Text('× ${item.quantity}'),
                  ),
                ),
              const SizedBox(height: 22),
              _SectionHeading(title: 'Delivery steps', count: null),
              const SizedBox(height: 12),
              _WorkflowStep(
                title: 'Assigned to you',
                subtitle: 'This task is in your active delivery list.',
                isComplete: true,
              ),
              _WorkflowStep(
                title:
                    isReturn
                        ? 'Return package to the locker'
                        : 'Reach the locker station',
                subtitle:
                    isReturn
                        ? 'Show the return task to the locker device.'
                        : 'Bring the listed items to the assigned station and drawer.',
                isComplete: false,
              ),
              if (!isReturn)
                _WorkflowStep(
                  title: 'Locker confirmation',
                  subtitle:
                      'The locker device confirms deposit and updates the order.',
                  isComplete: false,
                  isLast: true,
                ),
            ],
          ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'awaiting_locker' => 'Awaiting locker',
    'assigned' => 'Assigned',
    'expired' => 'Return required',
    _ => status.replaceAll('_', ' '),
  };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.isReturn});

  final String label;
  final bool isReturn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isReturn ? colors.destructive : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool isComplete;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: isComplete ? colors.success : colors.mutedForeground,
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: colors.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: colors.secondary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 25, color: colors.mutedForeground),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.destructive.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: context.colors.destructive)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
