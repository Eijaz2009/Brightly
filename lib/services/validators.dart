class Validators {
  /// Validate email format
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Please enter a valid email';
    return null;
  }

  /// Validate password strength
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  /// Validate name
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  /// Validate URL format
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) return 'URL is required';
    final urlRegex = RegExp(
      r'^https?:\/\/([\w-]+\.)+[\w-]+(\/[\w\-\.~:\/\?#\[\]@!\$&\(\)\*\+,;=%]*)?$',
      caseSensitive: false,
    );
    if (!urlRegex.hasMatch(value.trim())) return 'Please enter a valid URL (starting with http:// or https://)';
    return null;
  }

  /// Validate confirm password matches
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  /// Validate required field
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  /// Validate date format (e.g., "Jan 2025", "Feb 2026")
  static String? deadline(String? value) {
    if (value == null || value.trim().isEmpty) return 'Deadline is required';
    if (value.trim().toLowerCase() == 'varies') return null;
    final dateRegex = RegExp(r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}$', caseSensitive: false);
    if (!dateRegex.hasMatch(value.trim())) return 'Use format: "Mon YYYY" (e.g., Jan 2026) or "Varies"';
    return null;
  }
}
