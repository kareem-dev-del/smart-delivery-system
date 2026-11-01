import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/cubits/address/shipping_address_cubit.dart';
import 'package:shopease_mobile/models/shipping_address.dart';

class ShippingAddressScreen extends StatelessWidget {
  const ShippingAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShippingAddressCubit>(
      create: (_) => ShippingAddressCubit(
        shippingAddressController: AppBlocProviders.shippingAddressController,
      )..loadAddress(),
      child: const _ShippingAddressForm(),
    );
  }
}

class _ShippingAddressForm extends StatefulWidget {
  const _ShippingAddressForm();

  @override
  State<_ShippingAddressForm> createState() => _ShippingAddressFormState();
}

class _ShippingAddressFormState extends State<_ShippingAddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'United States');

  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().state.user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  // [تعديل] — بتعمل prefill لاسم المستلم كمان (كان ناقص خالص قبل كده)
  void _prefillFrom(ShippingAddress address) {
    if (_prefilled) return;
    _prefilled = true;
    if (address.name.isNotEmpty) _nameCtrl.text = address.name;
    _addressCtrl.text = address.street;
    _cityCtrl.text = address.city;
    _stateCtrl.text = address.state;
    _zipCtrl.text = address.zip;
    _countryCtrl.text = address.country;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final address = ShippingAddress(
      // [تعديل] — الاسم كان بيتكتب ويتـvalidate بس مبيتبعتش خالص؛ دلوقتي
      // بقى فعليًا جزء من الـobject اللي بيتحفظ
      name: _nameCtrl.text.trim(),
      street: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      zip: _zipCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
    );

    final success = await context.read<ShippingAddressCubit>().saveAddress(address);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved')),
      );
    }
    // لو فشلت، رسالة الخطأ هتظهر تلقائي جوه الـbanner تحت — مفيش داعي لـSnackBar هنا.
  }

  @override
  Widget build(BuildContext context) {
    // [تعديل] — الـprefill بقى في BlocListener بدل ما يتنادى جوه build()
    // مباشرة؛ نفس النتيجة بس ده أنضف ومش side effect جوه method لازم تفضل pure
    return BlocConsumer<ShippingAddressCubit, ShippingAddressState>(
      listener: (context, state) {
        if (state.address != null) {
          _prefillFrom(state.address!);
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Shipping Address')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Shipping Address')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (state.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // [تعديل] — نفس ألوان الـerror banner المستخدمة في
                        // edit_profile_screen.dart بدل Colors.red hardcoded
                        color: context.colors.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.colors.destructive.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: context.colors.destructive,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _Field(controller: _nameCtrl, label: 'Full Name'),
                  const SizedBox(height: 14),
                  _Field(controller: _addressCtrl, label: 'Street Address'),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _Field(controller: _cityCtrl, label: 'City')),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(controller: _stateCtrl, label: 'State')),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: _Field(
                            controller: _zipCtrl,
                            label: 'ZIP',
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(controller: _countryCtrl, label: 'Country')),
                  ]),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.isSaving ? null : _save,
                      child: state.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Address'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? '$label is required' : null,
    );
  }
}
