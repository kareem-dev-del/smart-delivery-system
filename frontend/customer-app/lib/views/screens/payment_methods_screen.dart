import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/cubits/payment_methods/payment_methods_cubit.dart';
import 'package:shopease_mobile/models/payment_method.dart';
import 'package:shopease_mobile/views/widgets/error_state.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentMethodsCubit, PaymentMethodsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            appBar: null,
            body: LoadingState(message: 'Loading payment methods...'),
          );
        }

        if (state.error != null && state.methods.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment Methods')),
            body: ErrorState(
              message: state.error!,
              onRetry: () => context.read<PaymentMethodsCubit>().loadMethods(),
            ),
          );
        }

        final cards = state.cards;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Payment Methods'),
            actions: [
              TextButton.icon(
                onPressed: () => _showAddCardSheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: context.colors.primary),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const _SectionHeader(title: 'SAVED CARDS'),
              if (cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No saved cards yet.',
                    style: TextStyle(color: context.colors.mutedForeground),
                  ),
                ),
              ...cards.map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CardTile(
                    card: card,
                    isMutating: state.isMutating,
                    onSetDefault: () =>
                        context.read<PaymentMethodsCubit>().setDefault(card.id),
                    onDelete: () async {
                      final removed =
                          await context.read<PaymentMethodsCubit>().removeMethod(card.id);
                      if (!context.mounted) return;
                      if (!removed) {
                        final message = context.read<PaymentMethodsCubit>().state.error ??
                            'Could not remove this card.';
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _SectionHeader(title: 'OTHER METHODS'),
              _OtherMethodTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'PayPal',
                subtitle: 'Connect your PayPal account',
                color: const Color(0xFF003087),
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _OtherMethodTile(
                icon: Icons.local_shipping_outlined,
                label: 'Cash on Delivery',
                subtitle: 'Pay when your order arrives',
                color: context.colors.success,
                onTap: () {},
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _showAddCardSheet(context),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Add a New Card'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCardSheet(BuildContext context) {
    final cubit = context.read<PaymentMethodsCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: const _AddCardSheet(),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.isMutating,
    required this.onSetDefault,
    required this.onDelete,
  });

  final PaymentMethod card;
  final bool isMutating;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isVisa = card.type == PaymentMethodType.visa;
    final brandColor =
        isVisa ? const Color(0xFF1A1F71) : const Color(0xFFEB001B);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 30,
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                card.displayName,
                style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•••• •••• •••• ${card.lastFour ?? '----'}',
                    style: TextStyle(
                        color: context.colors.foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Expires ${card.expiry ?? '--/--'}',
                    style: TextStyle(
                        color: context.colors.mutedForeground, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isMutating)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (card.isDefault)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Default',
                  style: TextStyle(
                      color: context.colors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (value) {
                  if (value == 'default') onSetDefault();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'default', child: Text('Set as default')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove',
                        style: TextStyle(color: context.colors.destructive)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OtherMethodTile extends StatelessWidget {
  const _OtherMethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: context.colors.foreground,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: context.colors.mutedForeground, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet();

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  PaymentMethodType _type = PaymentMethodType.visa;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final number = _numberController.text.trim();
    final lastFour = number.length >= 4 ? number.substring(number.length - 4) : number;

    final success = await context.read<PaymentMethodsCubit>().addCard(
          type: _type,
          lastFour: lastFour,
          expiry: _expiryController.text.trim(),
          holderName: _nameController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card added successfully.')),
      );
    } else {
      final message =
          context.read<PaymentMethodsCubit>().state.error ?? 'Could not add card.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add New Card',
                    style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<PaymentMethodType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Card Type'),
              items: const [
                DropdownMenuItem(value: PaymentMethodType.visa, child: Text('Visa')),
                DropdownMenuItem(
                    value: PaymentMethodType.mastercard, child: Text('Mastercard')),
                DropdownMenuItem(value: PaymentMethodType.amex, child: Text('Amex')),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Card Number',
                  prefixIcon: Icon(Icons.credit_card_rounded)),
              validator: (v) =>
                  (v == null || v.trim().length < 16) ? 'Enter a valid card number.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                  prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'MM/YY'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'CVV'),
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_card_rounded),
                label: const Text('Add Card'),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 10),
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
