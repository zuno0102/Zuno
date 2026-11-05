class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _indianMobilePattern = RegExp(r'^[6-9]\d{9}$');

  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email or phone number.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    if (!_emailPattern.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? indianMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (!_indianMobilePattern.hasMatch(value.trim())) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    return null;
  }

  /// The 10 digits of an Indian mobile number however it was typed — "98765 43210",
  /// "+91 98765 43210", "09876543210" — or null when it is not one. The Rent server reads it the same
  /// way (RentalPhone.Normalize).
  static String? indianMobileDigits(String? value) {
    var digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return _indianMobilePattern.hasMatch(digits) ? digits : null;
  }

  /// A mobile number that must be given: [missing] when empty, a hint when it is not a mobile.
  static String? requiredIndianMobile(
    String? value, {
    required String missing,
  }) {
    if (value == null || value.trim().isEmpty) return missing;
    return indianMobileDigits(value) == null
        ? 'Enter a 10-digit mobile number, like 98765 43210.'
        : null;
  }

  static String? name(String? value, {required String fieldLabel}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required.';
    }
    if (value.trim().length > 100) {
      return '$fieldLabel must be 100 characters or fewer.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!RegExp('[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!RegExp('[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one digit.';
    }
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) {
      return 'Password must contain at least one special character.';
    }
    return null;
  }
}
