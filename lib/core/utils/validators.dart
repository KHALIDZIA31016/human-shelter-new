class Validators {
  Validators._();

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? name(String? v, [String field = 'Name']) {
    final r = required(v, field);
    if (r != null) return r;
    return v!.trim().length < 2 ? '$field is too short' : null;
  }

  static String? phone(String? v) {
    final r = required(v, 'Phone number');
    if (r != null) return r;
    final digits = v!.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
    if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Email is optional; validated only when filled in.
  static String? optionalEmail(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
        ? null
        : 'Enter a valid email';
  }

  static String? positiveInt(String? v, [String field = 'Value']) {
    final r = required(v, field);
    if (r != null) return r;
    final n = int.tryParse(v!.trim());
    return (n == null || n < 1) ? '$field must be at least 1' : null;
  }

  static String? reason(String? v) => (v == null || v.trim().length < 5)
      ? 'Please give a reason (min 5 characters)'
      : null;
}
