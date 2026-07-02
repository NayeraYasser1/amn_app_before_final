class PasswordValidationResult {
  final bool isValid;
  final String message;

  const PasswordValidationResult._(this.isValid, this.message);

  const PasswordValidationResult.valid() : this._(true, 'Password is valid.');

  const PasswordValidationResult.invalid(String message)
    : this._(false, message);
}

class PasswordValidator {
  PasswordValidator._();

  static final RegExp _passwordPattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@#$%^&+=!])[A-Za-z\d@#$%^&+=!]{8,64}$',
  );

  static const Set<String> _weakPasswords = {
    '123456',
    '12345678',
    'password',
    'qwerty',
    'admin',
    'letmein',
  };

  static PasswordValidationResult validate(String? password) {
    if (password == null || password.isEmpty) {
      return const PasswordValidationResult.invalid('Password is required.');
    }

    if (password.length < 8 || password.length > 64) {
      return const PasswordValidationResult.invalid(
        'Password must be between 8 and 64 characters.',
      );
    }

    if (_weakPasswords.contains(password.toLowerCase())) {
      return const PasswordValidationResult.invalid(
        'Password is too weak. Choose a less common password.',
      );
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return const PasswordValidationResult.invalid(
        'Password must include at least one uppercase letter.',
      );
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return const PasswordValidationResult.invalid(
        'Password must include at least one lowercase letter.',
      );
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      return const PasswordValidationResult.invalid(
        'Password must include at least one number.',
      );
    }

    if (!RegExp(r'[@#$%^&+=!]').hasMatch(password)) {
      return const PasswordValidationResult.invalid(
        'Password must include at least one special character: @#\$%^&+=!',
      );
    }

    if (!_passwordPattern.hasMatch(password)) {
      return const PasswordValidationResult.invalid(
        'Password contains invalid characters.',
      );
    }

    return const PasswordValidationResult.valid();
  }

  static String regexPattern() => _passwordPattern.pattern;
}
