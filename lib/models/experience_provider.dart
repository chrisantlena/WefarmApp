import 'package:flutter/material.dart';
import 'package:wefarm/models/user_provider.dart';
import 'experience_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ExperienceProvider extends ChangeNotifier {
  final List<Experience> _myExperiences = [];
  final List<Experience> _othersExperiences = [];

  List<Experience> get myExperiences => _myExperiences;
  List<Experience> get othersExperiences => _othersExperiences;

  Future<void> fetchMyExperiences(dynamic userId) async {
    try {
      // PERBAIKAN: Convert userId ke int jika berupa string
      int userIdInt;
      if (userId is String) {
        userIdInt = int.tryParse(userId) ?? 0;
      } else if (userId is int) {
        userIdInt = userId;
      } else {
        userIdInt = 0;
      }

      print(
          'Fetching my experiences for user ID: $userIdInt (original: $userId)');

      if (userIdInt <= 0) {
        print('Invalid user ID: $userIdInt');
        return;
      }

      final response = await http.get(
        Uri.parse(
            'http://192.168.56.1/wefarm/lib/experience.php?user_id=$userIdInt'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _myExperiences.clear();

          // PERBAIKAN: Tambahkan pengecekan apakah data adalah array
          if (data['data'] is List) {
            for (var item in data['data']) {
              try {
                _myExperiences.add(Experience.fromJson(item));
              } catch (e) {
                print('Error parsing experience item: $e');
                print('Item data: $item');
              }
            }
          }

          print('My experiences loaded: ${_myExperiences.length}');

          // Debug: print each experience
          for (var exp in _myExperiences) {
            print(
                'Experience: ${exp.plantName} by ${exp.author} (status: ${exp.status})');
          }

          notifyListeners(); // PASTIKAN ini dipanggil
        } else {
          print('API returned success: false - ${data['message']}');
          print('Full response: $data');
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching my experiences: $e');
      // Tetap notify listeners meski error untuk update UI
      notifyListeners();
    }
  }

  // PERBAIKAN: Fetch Community Experiences (semua experiences)
  Future<void> fetchCommunityExperiences() async {
    try {
      print('Fetching community experiences'); // Debug log

      final response = await http.get(
        Uri.parse('http://192.168.56.1/wefarm/lib/experience.php?community=1'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Community response status: ${response.statusCode}'); // Debug log
      print('Community response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _othersExperiences.clear();
          for (var item in data['data']) {
            _othersExperiences.add(Experience.fromJson(item));
          }
          print(
              'Community experiences loaded: ${_othersExperiences.length}'); // Debug log
          notifyListeners();
        } else {
          print('Community API returned success: false - ${data['message']}');
        }
      } else {
        print('Community HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching community experiences: $e');
    }
  }

  // PERBAIKAN: Add Experience dengan handling yang lebih baik
  Future<bool> addExperience({
    required String plantName,
    required DateTime startDate,
    required DateTime endDate,
    required String experience,
    required String status,
    required dynamic userId, // Ubah ke dynamic
  }) async {
    try {
      // PERBAIKAN: Convert userId ke int
      int userIdInt;
      if (userId is String) {
        userIdInt = int.tryParse(userId) ?? 0;
      } else if (userId is int) {
        userIdInt = userId;
      } else {
        userIdInt = 0;
      }

      if (userIdInt <= 0) {
        print('Invalid user ID for adding experience: $userId');
        return false;
      }

      final requestData = {
        'user_id': userIdInt, // Pastikan ini integer
        'plant_name': plantName,
        'start_date':
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        'end_date':
            '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        'status': status,
        'experience': experience,
      };

      print('Adding experience with data: $requestData'); // Debug log

      final response = await http.post(
        Uri.parse('http://192.168.56.1/wefarm/lib/experience.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );

      print(
          'Add experience response status: ${response.statusCode}'); // Debug log
      print('Add experience response body: ${response.body}'); // Debug log

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Experience added successfully!');
          // Refresh kedua list setelah berhasil menambah experience
          await fetchMyExperiences(userIdInt);
          await fetchCommunityExperiences();
          return true;
        } else {
          print('Failed to add experience: ${data['message']}');
        }
      } else {
        print('HTTP Error when adding experience: ${response.statusCode}');
      }
      return false;
    } catch (e) {
      print('Error adding experience: $e');
      return false;
    }
  }

  // PERBAIKAN: Method untuk fetch experiences dengan UserProvider
  Future<void> fetchMyExperiencesFromUserProvider(
      UserProvider userProvider) async {
    final userId = await userProvider.getCurrentUserId();
    print(
        'Got userId from UserProvider: $userId (type: ${userId.runtimeType})');

    if (userId != null) {
      await fetchMyExperiences(userId);
    } else {
      print('No userId found in UserProvider');
    }
  }
}
