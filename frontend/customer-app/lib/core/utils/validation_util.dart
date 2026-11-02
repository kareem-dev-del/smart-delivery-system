/// Centralized, reusable form validators for the entire app.
///
/// Every method returns `null` when the value is valid, or a
/// user-facing error message when it isn't — matching Flutter's
/// `FormFieldValidator<String>` signature directly.
class Validators {
  const Validators._();

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------

  static final RegExp _emailRegex =
      RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');

  static String? name(String? value, {String fieldLabel = 'Name'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$fieldLabel is required';
    if (trimmed.length < 2) return '$fieldLabel must be at least 2 characters';
    if (trimmed.length > 50) return '$fieldLabel must be under 50 characters';
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(trimmed)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// Stricter password rule for registration flows — requires at least
  /// one letter and one number in addition to the base length check.
  static String? strongPassword(String? value, {int minLength = 8}) {
    final base = password(value, minLength: minLength);
    if (base != null) return base;

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value!);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return 'Password must include both letters and numbers';
    }
    return null;
  }

  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != originalPassword) return 'Passwords do not match';
    return null;
  }

  // ---------------------------------------------------------------------
  // Contact / Shipping
  // ---------------------------------------------------------------------

  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');

  static String? phone(String? value, {bool required = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? 'Phone number is required' : null;
    final digitsOnly = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!_phoneRegex.hasMatch(digitsOnly)) return 'Enter a valid phone number';
    return null;
  }

  static String? addressLine(String? value, {String fieldLabel = 'Address'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$fieldLabel is required';
    if (trimmed.length < 5) return '$fieldLabel is too short';
    return null;
  }

  static String? city(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'City is required';
    return null;
  }

  static String? country(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Country is required';
    return null;
  }

  static String? postalCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Postal code is required';
    if (!RegExp(r'^[A-Za-z0-9\- ]{3,10}$').hasMatch(trimmed)) {
      return 'Enter a valid postal code';
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Payment
  // ---------------------------------------------------------------------

  static String? cardholderName(String? value) =>
      name(value, fieldLabel: 'Cardholder name');

  static String? cardNumber(String? value) {
    final digitsOnly = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (digitsOnly.isEmpty) return 'Card number is required';
    if (!RegExp(r'^\d{13,19}$').hasMatch(digitsOnly)) {
      return 'Enter a valid card number';
    }
    if (!_passesLuhnCheck(digitsOnly)) return 'Card number is invalid';
    return null;
  }

  static String? cardExpiry(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Expiry date is required';

    final match = RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').firstMatch(trimmed);
    if (match == null) return 'Use MM/YY format';

    final month = int.parse(match.group(1)!);
    final year = int.parse('20${match.group(2)}');
    final now = DateTime.now();
    final expiry = DateTime(year, month + 1); // first day after expiry month

    if (expiry.isBefore(now)) return 'Card has expired';
    return null;
  }

  static String? cvv(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'CVV is required';
    if (!RegExp(r'^\d{3,4}$').hasMatch(trimmed)) return 'Enter a valid CVV';
    return null;
  }

  static bool _passesLuhnCheck(String digitsOnly) {
    var sum = 0;
    var alternate = false;
    for (var i = digitsOnly.length - 1; i >= 0; i--) {
      var digit = int.parse(digitsOnly[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  // ---------------------------------------------------------------------
  // Shopping (cart / checkout / promotions)
  // ---------------------------------------------------------------------

  static String? quantity(String? value, {int max = 99}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Quantity is required';
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid quantity';
    if (parsed <= 0) return 'Quantity must be at least 1';
    if (parsed > max) return 'Quantity can\'t exceed $max';
    return null;
  }

  static String? couponCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a coupon code';
    if (!RegExp(r'^[A-Za-z0-9\-]{3,20}$').hasMatch(trimmed)) {
      return 'Enter a valid coupon code';
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Generic helpers
  // ---------------------------------------------------------------------

  static String? required(String? value, {String fieldLabel = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldLabel is required';
    return null;
  }

  static String? minLength(String? value, int min, {String fieldLabel = 'This field'}) {
    if ((value ?? '').trim().length < min) {
      return '$fieldLabel must be at least $min characters';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String fieldLabel = 'This field'}) {
    if ((value ?? '').trim().length > max) {
      return '$fieldLabel must be under $max characters';
    }
    return null;
  }
}