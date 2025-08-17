import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'history_model.dart';
import '../auth_provider.dart';

class HistoryProvider extends ChangeNotifier {
  AuthProvider? _authProvider;
  List<History> _histories = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _filterStatus;

  static const String _baseUrl = 'http://192.168.56.1/wefarm/lib';

  // Getters
  List<History> get histories => _filterStatus == null
      ? _histories
      : _histories.where((h) => h.status == _filterStatus).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get filterStatus => _filterStatus;

  // Method untuk update auth provider
  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider?.isAuthenticated == true) {
      loadHistories();
    }
  }

  Future<void> loadHistories() async {
    if (_authProvider?.userId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/history.php?user_id=${_authProvider!.userId}'),
        headers: {
          'Authorization': 'Bearer ${_authProvider!.userId}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _histories = (data['data'] as List)
              .map((item) => History.fromJson(item))
              .toList();
        } else {
          _errorMessage = data['message'] ?? 'Failed to load histories';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      debugPrint('Error loading histories: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addToHistory({
    required String plantId,
    required String name,
    required String duration,
    required String imagePath,
    String? guide,
  }) async {
    if (_authProvider?.userId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/history.php'),
        headers: {
          'Authorization': 'Bearer ${_authProvider!.userId}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'user_id': _authProvider!.userId,
          'plant_id': plantId,
          'name': name,
          'duration': duration,
          'image_path': imagePath,
          'guide': guide,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await loadHistories();
          return true;
        } else {
          _errorMessage = data['message'] ?? 'Failed to add to history';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      debugPrint('Error adding to history: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateHistoryStatus({
    required String historyId,
    required String status,
    double? progress,
    String? notes,
  }) async {
    if (_authProvider?.userId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/history.php'),
        headers: {
          'Authorization': 'Bearer ${_authProvider!.userId}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': historyId,
          'status': status,
          'progress': progress,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await loadHistories();
          return true;
        } else {
          _errorMessage = data['message'] ?? 'Failed to update history';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      debugPrint('Error updating history: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteHistory(String historyId) async {
    if (_authProvider?.userId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/history.php'),
        headers: {
          'Authorization': 'Bearer ${_authProvider!.userId}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': historyId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await loadHistories();
          return true;
        } else {
          _errorMessage = data['message'] ?? 'Failed to delete history';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      debugPrint('Error deleting history: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void setFilterStatus(String? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Get history by ID
  History? getHistoryById(String id) {
    try {
      return _histories.firstWhere((h) => h.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get histories by status
  List<History> getHistoriesByStatus(String status) {
    return _histories.where((h) => h.status == status).toList();
  }
}
