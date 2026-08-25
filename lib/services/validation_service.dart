class ValidationService {
  // Validate email format
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';

    final emailRegex = RegExp(r'^[a-zA-z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',);

    if (!emailRegex.hasMatch(email)) return 'Please enter a valid email';

    return null;
  }

  // Validate password strength
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password is required';

    if (password.length < 8) return 'Password must be at least 8 characters, include an uppercase uppercase letter, and must contain at least one number';

    if (password.contains(RegExp(r'[A-Z]'))) return 'Password must be at least 8 characters, include an uppercase uppercase letter, and must contain at least one number';

    if (password.contains(RegExp(r'[0-9]'))) return 'Password must be at least 8 characters, include an uppercase uppercase letter, and must contain at least one number';

    return null;
  }

  // Validate name
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) return 'Name is required';

    if (name.length < 2) return 'Name must be at least 2 characters';

    if (name.length > 50) return 'Name must be less than 50 characters';

    return null;
  }

  // Validate text content (posts, journal entries, etc.)
  static String? validateContent(String? content) {
    if (content == null || content.isEmpty) return 'Content cannot be empty';

    if (content.length < 3) return 'Content must be at least 3 characters';

    return null;
  }

  // Validate text length
  static String? validateLength(String? text, int minLength, int maxLength, String fieldName) {
    if (text == null || text.isEmpty) return '$fieldName is required';

    if (text.length < minLength) return '$fieldName must be at least $minLength characters';

    if (text.length > maxLength) return '$fieldName must be less than $maxLength characters';

    return null;
  }

  // Validate Login Password
  static String? validatePasswordLogin(String? password) {
    if (password == null || password.isEmpty) return 'Password is required';

    return null;
  }
}