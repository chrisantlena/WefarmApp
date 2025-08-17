import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  int? _userId;
  String? _username;
  String? _email;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  // Constructor
  AuthProvider(this._prefs) {
    _tryAutoLogin();
  }

  // Getters
  int? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;

  static const String _baseUrl = 'http://192.168.56.1/wefarm/lib';

  Future<void> _tryAutoLogin() async {
    debugPrint('=== TRYING AUTO LOGIN ===');
    final userId = _prefs.getInt('user_id');
    final username = _prefs.getString('username');
    final email = _prefs.getString('email');
    final isAuthenticated = _prefs.getBool('is_authenticated') ?? false;

    debugPrint('SharedPrefs - userId: $userId');
    debugPrint('SharedPrefs - username: $username');
    debugPrint('SharedPrefs - email: $email');
    debugPrint('SharedPrefs - isAuthenticated: $isAuthenticated');

    if (userId != null && username != null && isAuthenticated) {
      _userId = userId;
      _username = username;
      _email = email;
      _isAuthenticated = true;

      debugPrint(
          'AUTO LOGIN SUCCESS - userId: $_userId, authenticated: $_isAuthenticated');
      notifyListeners();
    } else {
      debugPrint('AUTO LOGIN FAILED - Missing data or not authenticated');
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Raw server response: ${response.body}');

        if (data['success'] == true && data['user'] != null) {
          // Pastikan data user ada dan valid
          final userData = data['user'];

          // Convert ID ke int jika dalam bentuk string
          _userId = userData['id'] is String
              ? int.parse(userData['id'])
              : userData['id'];
          _username = userData['username']?.toString();
          _email = userData['email']?.toString();
          _isAuthenticated = true;

          debugPrint(
              'Extracted data - ID: $_userId, Username: $_username, Email: $_email');

          // Save to SharedPreferences dengan validasi
          if (_userId != null) {
            await _prefs.setInt('user_id', _userId!);
          }
          if (_username != null) {
            await _prefs.setString('username', _username!);
          }
          if (_email != null) {
            await _prefs.setString('email', _email!);
          }
          await _prefs.setBool('is_authenticated', true);

          // Verify data was saved
          final savedUserId = _prefs.getInt('user_id');
          final savedUsername = _prefs.getString('username');
          final savedAuth = _prefs.getBool('is_authenticated');

          debugPrint('Verification - Saved userId: $savedUserId');
          debugPrint('Verification - Saved username: $savedUsername');
          debugPrint('Verification - Saved auth: $savedAuth');

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage =
              data['message'] ?? 'Login failed - Invalid response format';
          debugPrint('Login failed: $_errorMessage');
          debugPrint('Response data: $data');
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
        debugPrint('Server error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Tambahkan method untuk refresh status authentication
  Future<void> refreshAuth() async {
    debugPrint('=== REFRESHING AUTH STATUS ===');
    await _tryAutoLogin();
  }

  Future<void> loadUserData() async {
    _userId = _prefs.getInt('user_id');
    _username = _prefs.getString('username');
    _email = _prefs.getString('email');
    _isAuthenticated = _prefs.getBool('is_authenticated') ?? false;

    debugPrint(
        'Loaded user data - UserId: $_userId, Authenticated: $_isAuthenticated');
    notifyListeners();
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'action': 'register',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Auto login after register
        _isLoading = false;
        notifyListeners();
        return await login(username, password);
      } else {
        _errorMessage = data['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // Clear all stored data
    await _prefs.remove('user_id');
    await _prefs.remove('username');
    await _prefs.remove('email');
    await _prefs.remove('is_authenticated');

    _userId = null;
    _username = null;
    _email = null;
    _isAuthenticated = false;

    debugPrint('User logged out');
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
