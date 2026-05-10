import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyLoggedIn = 'is_logged_in';
  static const String _keyApproved = 'is_approved';
  static const String _keyUserPin = 'user_pin';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyUserCity = 'user_city';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserAddr = 'user_address';
  static const String _keyUserRole = 'user_role';

  // Auth state

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, value);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<void> setApproved(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyApproved, value);
  }

  static Future<bool> isApproved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyApproved) ?? false;
  }

  // PIN

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserPin, pin);
  }

  static Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPin);
  }

  // User profile

  static Future<void> saveUserProfile({
    required String email,
    required String name,
    required String city,
    required String phone,
    required String address,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserCity, city);
    await prefs.setString(_keyUserPhone, phone);
    await prefs.setString(_keyUserAddr, address);
    await prefs.setString(_keyUserRole, role);
  }

  static Future<Map<String, String>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_keyUserEmail) ?? '',
      'name': prefs.getString(_keyUserName) ?? 'User',
      'city': prefs.getString(_keyUserCity) ?? '',
      'phone': prefs.getString(_keyUserPhone) ?? '',
      'address': prefs.getString(_keyUserAddr) ?? '',
      'role': prefs.getString(_keyUserRole) ?? 'Normal User',
    };
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
