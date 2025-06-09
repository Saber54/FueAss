class ValidationHelper {
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  static bool isValidPassword(String password) {
    return password.length >= 8;
  }

  static bool isValidUnNumber(String unNumber) {
    return RegExp(r'^[0-9]{4}$').hasMatch(unNumber);
  }

  static String? validateRequiredField(String? value) {
    if (value == null || value.isEmpty) {
      return 'Dieses Feld ist erforderlich';
    }
    return null;
  }
}