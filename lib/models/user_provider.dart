import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class UserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  // URL server PHP
  final String serverUrl = "http://192.168.56.1/wefarm/lib";

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  // Method untuk set user setelah login
  Future<void> setUserFromLogin(Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('=== SET USER FROM LOGIN ===');
      debugPrint('Raw userData: $userData');

      String? photoUrl = userData['photoUrl'] ??
          userData['photo_url'] ??
          userData['profile_image'];

      debugPrint('Extracted photoUrl: $photoUrl');

      _user = User.fromJson(userData);

      // Simpan session status dan user_id
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_id', userData['id'].toString());

      // Simpan user data untuk cache
      await prefs.setString('user_data', json.encode(_user!.toJson()));

      debugPrint('User saved to cache: ${_user!.toJson()}');
      debugPrint('Final user photoUrl: ${_user!.photoUrl}');
    } catch (e) {
      debugPrint('Error setting user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureUserData() async {
    if (_user == null) {
      final userId = await getCurrentUserId();
      if (userId != null) {
        await loadUserFromServer(userId);
      }
    }
  }

  Future<void> loadUserFromServer(String userId) async {
    debugPrint('=== LOADING USER FROM SERVER ===');
    debugPrint('User ID: $userId');

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/get_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] && responseData['user'] != null) {
          final userData = responseData['user'];

          _user = User.fromJson(userData);

          // Save to cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', json.encode(_user!.toJson()));

          debugPrint('User loaded from server successfully');
        } else {
          debugPrint(
              'Server response error: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading user from server: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user data from cache first
  Future<void> loadUserFromCache() async {
    debugPrint('=== LOADING USER FROM CACHE ===');
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      debugPrint('Cached user data: $userData');

      if (userData != null) {
        final userMap = json.decode(userData);
        _user = User.fromJson(userMap);
        debugPrint('User loaded from cache: ${_user!.toJson()}');
        debugPrint('Cache photoUrl: ${_user!.photoUrl}');
        notifyListeners();
      } else {
        debugPrint('No cached user data found');
      }
    } catch (e) {
      debugPrint('Error loading user from cache: $e');
    }
  }

  // Auto load user on app start
  Future<void> autoLoadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        final userMap = json.decode(userData);
        _user = User.fromJson(userMap);
        notifyListeners();
        debugPrint('User loaded from cache: ${_user!.name}');
      }
    } catch (e) {
      debugPrint('Error loading user from cache: $e');
    }
  }

  // Cek status login
  Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  // Get current user ID
  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Map<String, dynamic>? get currentUser {
    if (_user != null) {
      return _user!.toJson();
    }
    return null;
  }

  Future<void> logout() async {
    debugPrint('=== LOGOUT ===');
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('user_id');
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      _user = null;
      debugPrint('All user data cleared');
    } catch (e) {
      debugPrint('Error during logout: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(User newUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Update in memory first
      _user = newUser;

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', json.encode(_user!.toJson()));

      notifyListeners();

      // Send to server
      final response = await http.post(
        Uri.parse("$serverUrl/update_profile.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(newUser.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to connect to server");
      }

      final responseData = json.decode(response.body);
      if (!responseData['success']) {
        throw Exception(responseData['message'] ?? "Update failed");
      }
    } catch (e) {
      debugPrint("Error updating user: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  set user(User? newUser) {
    _user = newUser;
    notifyListeners();
  }

// Simplified updateUserPhoto (kalo masih mau pake)
  Future<void> updateUserPhoto(String photoUrl) async {
    if (_user != null) {
      _user = _user!.copyWith(photoUrl: photoUrl);
      notifyListeners();

      // Save to cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', json.encode(_user!.toJson()));
      } catch (e) {
        debugPrint("Cache save error: $e");
      }
    }
  }

  Future<void> refreshUserFromServer() async {
    final userId = await getCurrentUserId();
    if (userId != null) {
      debugPrint('Refreshing user from server after update...');
      await loadUserFromServer(userId);
    }
  }

// ✅ UPDATE method updateUserLocal yang sudah ada
  void updateUserLocal(User updatedUser) {
    debugPrint('=== UPDATING USER LOCAL ===');
    debugPrint('Before update: ${_user?.toJson()}');
    debugPrint('New user data: ${updatedUser.toJson()}');

    _user = updatedUser;
    notifyListeners();

    // Update juga di SharedPreferences
    _saveUserToPrefs(updatedUser);

    debugPrint('After update: ${_user?.toJson()}');
  }

// Method untuk save user data ke SharedPreferences
  Future<void> _saveUserToPrefs(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'id': user.id,
        'name': user.name,
        'username': user.name, // For compatibility
        'email': user.email,
        'phone': user.phone,
        'address': user.address,
        'photo_url': user.photoUrl,
        'photoUrl': user.photoUrl,
        'profile_image': user.photoUrl,
      };

      await prefs.setString('user_data', json.encode(userData));
      debugPrint('User data saved to SharedPreferences: $userData');
    } catch (e) {
      debugPrint('Error saving user to preferences: $e');
    }
  }

  // ✅ TAMBAHKAN method ini ke UserProvider class

// Method untuk update profile langsung dari UserProvider
  Future<bool> updateUserProfile({
    required String name,
    required String email,
    required String phone,
    String? address,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('=== UPDATING USER PROFILE ===');
      debugPrint('URL: $serverUrl/update_profile.php');
      debugPrint(
          'Data: name=$name, email=$email, phone=$phone, address=$address');

      final response = await http.post(
        Uri.parse('$serverUrl/update_profile.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': _user!.id,
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          // ✅ UPDATE LOCAL USER DATA
          _user = User(
            id: _user!.id,
            name: name,
            email: email,
            phone: phone,
            address: address,
            photoUrl: _user!.photoUrl, // Keep existing photo
          );

          // ✅ SAVE TO CACHE
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', json.encode(_user!.toJson()));

          notifyListeners();
          debugPrint('Profile updated successfully!');
          return true;
        } else {
          debugPrint('Server error: ${responseData['message']}');
          return false;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception updating profile: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
