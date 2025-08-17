import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'plant_model.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'user_provider.dart';

class PlantProvider extends ChangeNotifier {
  static const String _baseUrl = 'http://192.168.56.1/wefarm/lib';

  UserProvider? _userProvider;
  List<Map<String, dynamic>> _apiPlants = [];
  bool _hasLoadedFromApi = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<Plant> _trackedPlants = [];
  List<Plant> _historicalPlants = [];
  String? _historyFilter;
  bool _isInitialized = false;

  final Map<int, Map<String, dynamic>> _plantDetailsCache = {};

  // GETTERS (tidak berubah)
  List<Map<String, dynamic>> get displayedPlants => _apiPlants;
  List<Map<String, dynamic>> get allPlants => _apiPlants;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoadedFromApi => _hasLoadedFromApi;
  List<Plant> get trackedPlants => _trackedPlants;
  String? get historyFilter => _historyFilter;

  List<Plant> get historicalPlants {
    if (_historyFilter == null) {
      return _historicalPlants;
    }
    return _historicalPlants
        .where((plant) => plant.status == _historyFilter)
        .toList();
  }

  List<Plant> get availablePlants {
    // ✅ KALAU _apiPlants KOSONG, RETURN EMPTY LIST
    if (_apiPlants.isEmpty) {
      return [];
    }

    List<Plant> plants = [];

    for (var plantData in _apiPlants) {
      try {
        // ✅ SAFE EXTRACTION DENGAN NULL CHECKS
        final name = plantData["name"]?.toString() ?? "Unknown Plant";
        final duration =
            plantData["duration"]?.toString() ?? "Unknown Duration";
        final imagePath = plantData["image_path"]?.toString() ??
            plantData["image"]?.toString() ??
            'assets/default_plant.png';
        final guide =
            plantData["guide"]?.toString() ?? "Panduan tidak tersedia";

        // ✅ SAFE PLANT ID EXTRACTION
        int? plantId;
        if (plantData["id"] != null) {
          if (plantData["id"] is int) {
            plantId = plantData["id"] as int;
          } else if (plantData["id"] is String) {
            plantId = int.tryParse(plantData["id"]);
          }
        }

        final plant = Plant(
          name: name,
          duration: duration,
          startDate: DateTime.now(),
          progress: 0.0,
          tasks: generateTasksFromPlantData(plantData),
          imagePath: imagePath,
          targets: generateTargetsFromPlantData(plantData),
          recommendedProducts: _generateProductsFromPlantData(plantData),
          tutorialLinks: _generateLinksFromPlantData(plantData),
          guide: guide,
          plantId: plantId,
        );

        plants.add(plant);
      } catch (e) {
        // ✅ SKIP PLANT YANG ERROR, LANJUT KE PLANT BERIKUTNYA
        print('Error creating plant from data: $plantData, error: $e');
        continue;
      }
    }

    return plants;
  }

  void updateUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    if (!_isInitialized) {
      initialize();
    }
  }

  List<PlantTask> generateTasksFromPlantData(Map<String, dynamic> plantData) {
    debugPrint('🔧 generateTasksFromPlantData called with: ${plantData.keys}');
    debugPrint('🔧 daily_tasks field: ${plantData['daily_tasks']}');
    debugPrint('🔧 daily_tasks type: ${plantData['daily_tasks']?.runtimeType}');

    try {
      var dailyTasksData = plantData['daily_tasks'];

      // Handle JSON string
      if (dailyTasksData is String) {
        debugPrint('🔧 daily_tasks is String, trying to decode JSON');
        try {
          dailyTasksData = json.decode(dailyTasksData);
          debugPrint('🔧 Decoded daily_tasks: $dailyTasksData');
        } catch (e) {
          debugPrint('❌ Error decoding daily_tasks JSON: $e');
          return _getDefaultTasks();
        }
      }

      if (dailyTasksData != null && dailyTasksData is List) {
        debugPrint(
            '🔧 Processing daily_tasks as List with ${dailyTasksData.length} items');

        final tasks = <PlantTask>[];
        for (var taskData in dailyTasksData) {
          try {
            debugPrint(
                '🔧 Processing task data: $taskData (${taskData.runtimeType})');

            // ✅ HANDLE BOTH MAP AND STRING FORMAT
            if (taskData is Map<String, dynamic>) {
              // Format: {"name": "Task name", "frequency": "daily"}
              final task = PlantTask(
                name: taskData['name']?.toString() ?? '',
                frequency: taskData['frequency']?.toString() ?? 'daily',
                completed: false,
              );
              tasks.add(task);
              debugPrint('✅ Created task from Map: ${task.name}');
            } else if (taskData is String) {
              // ✅ FORMAT: "Task description" (simple string)
              final task = PlantTask(
                name: taskData,
                frequency: 'daily', // Default frequency
                completed: false,
              );
              tasks.add(task);
              debugPrint('✅ Created task from String: ${task.name}');
            } else {
              debugPrint('❌ Task data is neither Map nor String: $taskData');
            }
          } catch (e) {
            debugPrint('❌ Error processing individual task: $e');
          }
        }

        if (tasks.isNotEmpty) {
          debugPrint('🔧 Generated ${tasks.length} tasks from database');
          return tasks;
        }
      }
    } catch (e) {
      debugPrint('❌ Error in generateTasksFromPlantData: $e');
    }

    debugPrint('🔧 Using fallback default tasks');
    return _getDefaultTasks();
  }

// ✅ ADD _getDefaultTasks() helper method
  List<PlantTask> _getDefaultTasks() {
    return [
      PlantTask(name: "Penyiraman", frequency: "daily", completed: false),
      PlantTask(name: "Pemupukan", frequency: "weekly", completed: false),
    ];
  }

// ✅ REPLACE generateTargetsFromPlantData() method
  List<PlantTarget> generateTargetsFromPlantData(
      Map<String, dynamic> plantData) {
    debugPrint('🎯 generateTargetsFromPlantData called');
    debugPrint('🎯 targets field: ${plantData['targets']}');
    debugPrint('🎯 targets type: ${plantData['targets']?.runtimeType}');

    try {
      var targetsData = plantData['targets'];

      // Handle JSON string
      if (targetsData is String) {
        debugPrint('🎯 targets is String, trying to decode JSON');
        try {
          targetsData = json.decode(targetsData);
          debugPrint('🎯 Decoded targets: $targetsData');
        } catch (e) {
          debugPrint('❌ Error decoding targets JSON: $e');
          return _getDefaultTargets();
        }
      }

      if (targetsData != null && targetsData is List) {
        debugPrint(
            '🎯 Processing targets as List with ${targetsData.length} items');

        final targets = <PlantTarget>[];
        for (var targetData in targetsData) {
          try {
            debugPrint(
                '🎯 Processing target data: $targetData (${targetData.runtimeType})');

            if (targetData is Map<String, dynamic>) {
              final target = PlantTarget(
                period: targetData['period']?.toString() ?? '',
                description: targetData['description']?.toString() ?? '',
              );
              targets.add(target);
              debugPrint('✅ Created target: ${target.period}');
            } else {
              debugPrint('❌ Target data is not a Map: $targetData');
            }
          } catch (e) {
            debugPrint('❌ Error processing individual target: $e');
          }
        }

        if (targets.isNotEmpty) {
          debugPrint('🎯 Generated ${targets.length} targets from database');
          return targets;
        }
      }
    } catch (e) {
      debugPrint('❌ Error in generateTargetsFromPlantData: $e');
    }

    return _getDefaultTargets();
  }

// ✅ ADD _getDefaultTargets() helper method
  List<PlantTarget> _getDefaultTargets() {
    return [
      PlantTarget(period: "Hari 1-7", description: "Perkecambahan awal"),
      PlantTarget(period: "Hari 7-14", description: "Daun pertama muncul"),
      PlantTarget(period: "Hari 14-30", description: "Pertumbuhan vegetatif"),
      PlantTarget(period: "Hari 30+", description: "Siap panen"),
    ];
  }

  List<RecommendedProduct> _generateProductsFromPlantData(
      Map<String, dynamic> plantData) {
    if (plantData['recommended_products'] != null &&
        plantData['recommended_products'] is List) {
      return (plantData['recommended_products'] as List).map((productData) {
        print('Individual product data: $productData'); // Debug print
        return RecommendedProduct.fromJson(productData);
      }).toList();
    }

    return [];
  }

  List<TutorialLink> _generateLinksFromPlantData(
      Map<String, dynamic> plantData) {
    if (plantData['tutorial_links'] != null &&
        plantData['tutorial_links'] is List) {
      return (plantData['tutorial_links'] as List)
          .map((linkData) => TutorialLink(
                title: linkData['title'] ?? '',
                url: linkData['url'] ?? '',
              ))
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>?> getPlantDetails(int plantId) async {
    // Check cache first
    if (_plantDetailsCache.containsKey(plantId)) {
      return _plantDetailsCache[plantId];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/plants.php?action=detail&id=$plantId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📋 Decoded response: $data');

        if (data['success'] == true && data['data'] != null) {
          final plantData = data['data'];
          debugPrint('🌱 Plant data keys: ${plantData.keys}');
          debugPrint('🎯 Targets field: ${plantData['targets']}');
          debugPrint('📝 Daily tasks field: ${plantData['daily_tasks']}');

          _plantDetailsCache[plantId] = plantData;
          return plantData;
        } else {
          debugPrint('❌ API returned success=false or data=null');
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Exception in getPlantDetails: $e');
      debugPrint('❌ Exception type: ${e.runtimeType}');
    }

    return null;
  }

  String _generateUniquePlantName(String baseName) {
    // Count existing plants with the same base name
    final existingPlants = _trackedPlants
        .where((plant) =>
            plant.name == baseName || plant.name.startsWith('$baseName '))
        .toList();

    if (existingPlants.isEmpty) {
      return baseName;
    }

    // Find the next available number
    int maxNumber = 0;
    for (final plant in existingPlants) {
      if (plant.name == baseName) {
        maxNumber = 1; // First plant without number counts as 1
      } else {
        final parts = plant.name.split(' ');
        if (parts.length > 1) {
          final lastPart = parts.last;
          final number = int.tryParse(lastPart);
          if (number != null && number > maxNumber) {
            maxNumber = number;
          }
        }
      }
    }

    return '$baseName ${maxNumber + 1}';
  }

  Future<bool> startPlanting({
    required int plantId,
    required String plantName,
    required String userId,
  }) async {
    try {
      final uniquePlantName = _generateUniquePlantName(plantName);

      // ✅ FIX: PASTIKAN JADI INT, JANGAN FALLBACK KE STRING
      final userIdInt = int.tryParse(userId) ?? 0;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/user_plants.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userId',
            },
            body: json.encode({
              'user_id': userIdInt, // ✅ PASTIKAN INT
              'plant_id': plantId,
              'name': uniquePlantName,
              'status': 'tracking',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _plantDetailsCache.clear();
          await loadTrackedPlants();
          notifyListeners();
          return true;
        }
      }

      final errorData = json.decode(response.body);
      _errorMessage = errorData['message'] ?? 'Failed to start planting';
      return false;
    } catch (e) {
      _errorMessage = 'Error: $e';
      return false;
    }
  }

  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    debugPrint('UserProvider manually set: ${userProvider.currentUser?['id']}');
    notifyListeners();
  }

  Future<void> loadTrackedPlants() async {
    if (_userProvider?.currentUser?['id'] == null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _userProvider!.currentUser!['id'];

      // ✅ CLEAR CACHE SEBELUM LOAD BARU
      _plantDetailsCache.clear();
      debugPrint('🔄 Cleared plant details cache');

      final response = await http.get(
        Uri.parse('$_baseUrl/user_plants.php?user_id=$userId&status=tracking'),
        headers: {
          'Authorization': 'Bearer $userId',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _trackedPlants = [];

          for (var plantData in (data['data'] as List)) {
            if (plantData['status'] != 'tracking') {
              continue;
            }

            debugPrint(
                '🌱 Processing plant: ${plantData['name']} (ID: ${plantData['plant_id']})');

            // ✅ FETCH TARGETS & TASKS FROM PLANTS TABLE
            List<PlantTarget> targets = [];
            List<PlantTask> tasks = [];

            if (plantData['plant_id'] != null) {
              try {
                debugPrint(
                    '🔍 Loading fresh plant details for ID: ${plantData['plant_id']}');
                final plantDetails =
                    await getPlantDetails(plantData['plant_id']);
                if (plantDetails != null) {
                  debugPrint(
                      '📋 Got plant details, generating targets and tasks...');
                  targets = generateTargetsFromPlantData(plantDetails);
                  tasks = generateTasksFromPlantData(plantDetails);
                  debugPrint(
                      '✅ Generated ${targets.length} targets and ${tasks.length} tasks');
                } else {
                  debugPrint('❌ Plant details is null');
                }
              } catch (e) {
                debugPrint('❌ Error loading plant details: $e');
              }
            }

            // ✅ FALLBACK KE DEFAULT JIKA GAGAL LOAD
            if (targets.isEmpty) {
              debugPrint('🔄 Using default targets');
              targets = [
                PlantTarget(
                    period: "Hari 7", description: "Perkecambahan awal"),
                PlantTarget(
                    period: "Hari 14", description: "Daun pertama muncul"),
                PlantTarget(
                    period: "Hari 30", description: "Pertumbuhan vegetatif"),
                PlantTarget(period: "Hari 60", description: "Siap panen"),
              ];
            }

            if (tasks.isEmpty) {
              debugPrint('🔄 Using default tasks');
              tasks = [
                PlantTask(
                    name: "Penyiraman", frequency: "daily", completed: false),
                PlantTask(
                    name: "Pemupukan", frequency: "weekly", completed: false),
              ];
            }

            Map<int, bool> completedTargets = {};
            Map<int, String?> targetProblems = {};

            if (plantData['completed_targets'] != null &&
                plantData['completed_targets'].toString().isNotEmpty) {
              try {
                debugPrint(
                    '🔍 RAW completed_targets: ${plantData['completed_targets']}');
                debugPrint(
                    '🔍 Type: ${plantData['completed_targets'].runtimeType}');

                final decoded = json.decode(plantData['completed_targets']);
                debugPrint('🔍 DECODED completed_targets: $decoded');

                // ✅ HANDLE BOTH ARRAY AND OBJECT FORMAT
                if (decoded is List) {
                  // Format: [true, false, false, ...]
                  debugPrint('🔧 Processing as Array format');
                  for (int i = 0; i < decoded.length; i++) {
                    completedTargets[i] = decoded[i] == true;
                  }
                } else if (decoded is Map) {
                  // Format: {"0": true, "1": false, ...}
                  debugPrint('🔧 Processing as Map format');
                  completedTargets = decoded.map((key, value) => MapEntry(
                      int.tryParse(key.toString()) ?? 0, value == true));
                }

                debugPrint('🔍 FINAL completedTargets: $completedTargets');
              } catch (e) {
                debugPrint('❌ Error parsing completed_targets: $e');
              }
            }

            if (plantData['target_problems'] != null &&
                plantData['target_problems'].toString().isNotEmpty) {
              try {
                debugPrint(
                    '🔍 RAW target_problems: ${plantData['target_problems']}');
                final decoded = json.decode(plantData['target_problems']);
                debugPrint('🔍 DECODED target_problems: $decoded');

                // ✅ HANDLE BOTH ARRAY AND OBJECT FORMAT
                if (decoded is List) {
                  // Format: ["problem1", null, "problem3", ...]
                  debugPrint('🔧 Processing target_problems as Array format');
                  for (int i = 0; i < decoded.length; i++) {
                    if (decoded[i] != null &&
                        decoded[i].toString().isNotEmpty) {
                      targetProblems[i] = decoded[i].toString();
                    }
                  }
                } else if (decoded is Map) {
                  // Format: {"0": "problem1", "2": "problem3", ...}
                  debugPrint('🔧 Processing target_problems as Map format');
                  targetProblems = decoded.map((key, value) => MapEntry(
                      int.tryParse(key.toString()) ?? 0, value?.toString()));
                }

                debugPrint('🔍 FINAL targetProblems: $targetProblems');
              } catch (e) {
                debugPrint('❌ Error parsing target_problems: $e');
              }
            }

            // Clean notes
            String cleanNotes = '';
            if (plantData['notes'] != null) {
              String rawNotes = plantData['notes'].toString();
              List<String> noteLines = rawNotes.split('\n');
              List<String> cleanLines = [];

              for (String line in noteLines) {
                if (!line.contains('[TARGET_DATA]') &&
                    !line.contains('completed_targets') &&
                    !line.contains('target_problems') &&
                    line.trim().isNotEmpty) {
                  cleanLines.add(line);
                }
              }
              cleanNotes = cleanLines.join('\n');
            }

            final plant = Plant(
              name: plantData['name'] ?? 'Unknown',
              duration: plantData['duration'] ?? '3-4 Bulan',
              startDate: DateTime.parse(plantData['start_date']),
              progress: (plantData['progress'] ?? 0.0).toDouble(),
              tasks: tasks,
              targets: targets, // ✅ FRESH TARGETS FROM DATABASE
              recommendedProducts: [],
              tutorialLinks: [],
              imagePath: plantData['image_path'] ?? 'assets/default_plant.png',
              status: 'tracking',
              trackerId: plantData['id'],
              plantId: plantData['plant_id'],
              notes: cleanNotes.isEmpty ? null : cleanNotes,
              guide: plantData['guide'],
              targetProblems: targetProblems,
              completedTargets: completedTargets,
            );
            debugPrint('🌱 CREATED PLANT: ${plant.name}');
            debugPrint('   completedTargets: ${plant.completedTargets}');
            debugPrint('   targetProblems: ${plant.targetProblems}');

            _trackedPlants.add(plant);
            debugPrint(
                '✅ Added plant: ${plant.name} with ${plant.targets.length} targets');
          }

          await _savePlants();
          debugPrint('🎉 Successfully loaded ${_trackedPlants.length} plants');
        }
      }
    } catch (e) {
      debugPrint('Error loading tracked plants: $e');
      await _loadPlants();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePlantProgressInDatabase(
      int trackerId, double progress) async {
    if (_userProvider?.currentUser?['id'] == null) {
      debugPrint('Cannot update progress: user not logged in');
      return false;
    }

    try {
      final userId = _userProvider!.currentUser!['id'];
      final response = await http
          .put(
            Uri.parse('$_baseUrl/user_plants.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userId',
            },
            body: json.encode({
              'action': 'update_progress',
              'tracker_id': trackerId,
              'progress': progress,
            }),
          )
          .timeout(Duration(seconds: 10));

      debugPrint(
          'Update progress response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
    return false;
  }

  Future<void> updatePlantProgress(String plantName, double progress) async {
    final index = _trackedPlants.indexWhere((p) => p.name == plantName);
    if (index != -1) {
      final plant = _trackedPlants[index];

      // Update local data
      _trackedPlants[index] =
          plant.copyWith(progress: progress.clamp(0.0, 1.0));

      // Update database if trackerId is available
      if (plant.trackerId != null) {
        final success = await updatePlantProgressInDatabase(
            plant.trackerId!, progress.clamp(0.0, 1.0));
        if (!success) {
          debugPrint(
              'Failed to update progress in database for plant: $plantName');
        }
      }

      await _savePlants();
      notifyListeners();
    }
  }

  Future<void> loadUserPlants() async {
    if (_userProvider?.currentUser?['id'] == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _userProvider!.currentUser!['id'];
      final response = await http.get(
        Uri.parse('$_baseUrl/user_plants.php?user_id=$userId'),
        headers: {
          'Authorization': 'Bearer $userId',
          'Content-Type': 'application/json'
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Pastikan parsing data sesuai dengan struktur response
          final allPlants = (data['data'] as List)
              .map<Plant>((p) => Plant.fromJson(p))
              .toList();

          _trackedPlants =
              allPlants.where((p) => p.status == 'tracking').toList();
          _historicalPlants =
              allPlants.where((p) => p.status != 'tracking').toList();

          debugPrint('Loaded ${_trackedPlants.length} tracked plants');
          debugPrint('Loaded ${_historicalPlants.length} historical plants');
        }
      }
    } catch (e) {
      debugPrint('Error loading user plants: $e');
      // Fallback ke SharedPreferences jika error
      await _loadPlants();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load plants dari API dengan error handling yang lebih baik
  Future<void> loadPlantsFromAPI() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('Loading plants from API...');
      final response = await http.get(
        Uri.parse('$_baseUrl/plants.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
      ).timeout(Duration(seconds: 15));

      debugPrint(
          'Plants API response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _apiPlants = List<Map<String, dynamic>>.from(data['data']);
          _hasLoadedFromApi = true;
          debugPrint('Loaded ${_apiPlants.length} plants from API');
        } else {
          _errorMessage = data['message'] ?? 'Failed to load plants';
          debugPrint('API returned success=false: $_errorMessage');
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
        debugPrint('HTTP error loading plants: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _errorMessage = 'Network error: Cannot connect to server';
      debugPrint('Socket exception loading plants: $e');
    } on TimeoutException catch (e) {
      _errorMessage = 'Connection timeout. Please try again.';
      debugPrint('Timeout exception loading plants: $e');
    } catch (e) {
      _errorMessage = 'Error: $e';
      debugPrint('Error loading plants: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('PlantProvider already initialized');
      return;
    }

    debugPrint('Initializing PlantProvider...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load plants dari API
      await loadPlantsFromAPI();

      // Load tracked plants dari database (dengan fallback ke SharedPreferences)
      await loadTrackedPlants();

      _isInitialized = true;
      debugPrint('PlantProvider initialization completed');
    } catch (e) {
      _errorMessage = 'Initialization failed: $e';
      debugPrint('Initialize error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> forceRefreshTrackedPlants() async {
    debugPrint('Force refreshing tracked plants...');
    await loadTrackedPlants();
  }

  // Method untuk refresh data (bisa dipanggil manual)
  Future<void> refreshPlants() async {
    debugPrint('Refreshing plants data...');
    await loadPlantsFromAPI();
  }

  // Method untuk menambah tanaman baru via API
  Future<bool> addNewPlantToDatabase({
    required String name,
    required String duration,
    required String imagePath,
    required String guide,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('Adding new plant: $name');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/plants.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
            body: json.encode({
              'action': 'add',
              'name': name,
              'duration': duration,
              'image_path': imagePath,
              'guide': guide,
            }),
          )
          .timeout(Duration(seconds: 30));

      debugPrint(
          'Add plant response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Refresh data setelah berhasil menambah
          await loadPlantsFromAPI();
          return true;
        } else {
          _errorMessage = data['message'] ?? 'Failed to add plant';
        }
      } else {
        _errorMessage =
            'Server error: ${response.statusCode} - ${response.body}';
      }
    } on SocketException catch (e) {
      _errorMessage = 'Network error: Cannot connect to server';
      debugPrint('Socket exception adding plant: $e');
    } catch (e) {
      _errorMessage = 'Error adding plant: $e';
      debugPrint('Error adding plant: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loadHistoricalPlants() async {
    if (_userProvider?.currentUser?['id'] == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _userProvider!.currentUser!['id'];
      final response = await http.get(
        Uri.parse('$_baseUrl/history.php?user_id=$userId'),
        headers: {
          'Authorization': 'Bearer $userId',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _historicalPlants = [];

          for (var historyData in (data['data'] as List)) {
            debugPrint(
                '🏛️ Processing historical plant: ${historyData['plant_name']}');

            // ✅ CARI plant_id BERDASARKAN plant_name DARI _apiPlants
            int? plantId;
            try {
              final plantName = historyData['plant_name'].toString();
              debugPrint('🔍 Looking for plant_id for name: $plantName');

              // Search in _apiPlants for matching name
              for (var apiPlant in _apiPlants) {
                if (apiPlant['name'].toString() == plantName) {
                  if (apiPlant['id'] is int) {
                    plantId = apiPlant['id'] as int;
                  } else if (apiPlant['id'] is String) {
                    plantId = int.tryParse(apiPlant['id']);
                  }
                  debugPrint('✅ Found plant_id: $plantId for $plantName');
                  break;
                }
              }

              if (plantId == null) {
                debugPrint(
                    '❌ plant_id not found for: $plantName in _apiPlants');
                debugPrint(
                    '📋 Available plants in _apiPlants: ${_apiPlants.map((p) => p['name']).toList()}');
              }
            } catch (e) {
              debugPrint('❌ Error finding plant_id: $e');
            }

            // ✅ FETCH TARGETS & TASKS DARI DATABASE JIKA plant_id DITEMUKAN
            List<PlantTarget> targets = [];
            List<PlantTask> tasks = [];

            if (plantId != null) {
              try {
                debugPrint(
                    '🔍 Loading plant details for historical plant ID: $plantId');
                final plantDetails = await getPlantDetails(plantId);
                if (plantDetails != null) {
                  debugPrint(
                      '📋 Got historical plant details, generating targets and tasks...');
                  targets = generateTargetsFromPlantData(plantDetails);
                  tasks = generateTasksFromPlantData(plantDetails);
                  debugPrint(
                      '✅ Generated ${targets.length} targets and ${tasks.length} tasks for historical plant');
                } else {
                  debugPrint('❌ Historical plant details is null');
                }
              } catch (e) {
                debugPrint('❌ Error loading historical plant details: $e');
              }
            }

            // ✅ FALLBACK KE DEFAULT JIKA GAGAL LOAD (SAME AS TRACKED PLANTS)
            if (targets.isEmpty) {
              debugPrint('🔄 Using default targets for historical plant');
              targets = [
                PlantTarget(
                    period: "Hari 7", description: "Perkecambahan awal"),
                PlantTarget(
                    period: "Hari 14", description: "Daun pertama muncul"),
                PlantTarget(
                    period: "Hari 30", description: "Pertumbuhan vegetatif"),
                PlantTarget(period: "Hari 60", description: "Siap panen"),
              ];
            }

            if (tasks.isEmpty) {
              debugPrint('🔄 Using default tasks for historical plant');
              tasks = [
                PlantTask(
                    name: "Penyiraman", frequency: "daily", completed: false),
                PlantTask(
                    name: "Pemupukan", frequency: "weekly", completed: false),
              ];
            }

            // ✅ PARSE TARGET DATA DARI NOTES (TETAP ADA KARENA HISTORICAL PLANTS PERLU COMPLETED STATUS)
            Map<int, bool> completedTargets = {};
            Map<int, String?> targetProblems = {};
            String cleanNotes = '';

            if (historyData['notes'] != null) {
              cleanNotes = historyData['notes'].toString();
            }

            final plant = Plant(
              name: historyData['plant_name'] ?? 'Unknown',
              duration: historyData['duration'] ?? 'Unknown duration',
              startDate: DateTime.parse(historyData['start_date']),
              endDate: historyData['end_date'] != null
                  ? DateTime.parse(historyData['end_date'])
                  : null,
              progress: historyData['progress'] ??
                  (historyData['status'] == 'completed' ? 1.0 : 0.0),
              tasks: tasks, // ✅ FRESH TASKS FROM DATABASE
              targets: targets, // ✅ FRESH TARGETS FROM DATABASE
              recommendedProducts: [],
              tutorialLinks: [],
              imagePath:
                  historyData['image_path'] ?? 'assets/default_plant.png',
              status: historyData['status'],
              notes: cleanNotes.isEmpty ? null : cleanNotes,
              trackerId: historyData['user_plant_id'],
              plantId: plantId, // ✅ PLANT_ID DARI PENCARIAN BERDASARKAN NAMA
              guide: historyData['guide'],
              targetProblems: targetProblems, // ✅ KOSONG UNTUK HISTORICAL
              completedTargets: completedTargets, // ✅ KOSONG UNTUK HISTORICAL
            );

            _historicalPlants.add(plant);
            debugPrint(
                '✅ Added historical plant: ${plant.name} with ${plant.targets.length} targets and plantId: $plantId');
          }

          await _savePlants();
          debugPrint(
              '🎉 Successfully loaded ${_historicalPlants.length} historical plants');
        }
      }
    } catch (e) {
      debugPrint('Error loading historical plants: $e');
      await _loadPlants();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addPlantWithCustomData({
    required String name,
    required String duration,
    required String imagePath,
    required String guide,
    required List<PlantTarget> targets,
    required List<PlantTask> dailyTasks,
    required List<RecommendedProduct> recommendedProducts,
    required List<TutorialLink> tutorialLinks,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('Adding new plant with custom data: $name');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/plants.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
            body: json.encode({
              'name': name,
              'duration': duration,
              'image_path': imagePath,
              'guide': guide,
              'targets': targets.map((t) => t.toJson()).toList(),
              'daily_tasks': dailyTasks.map((t) => t.toJson()).toList(),
              'recommended_products':
                  recommendedProducts.map((p) => p.toJson()).toList(),
              'tutorial_links': tutorialLinks.map((l) => l.toJson()).toList(),
            }),
          )
          .timeout(Duration(seconds: 30));

      debugPrint(
          'Add plant response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Clear cache and refresh data
          _plantDetailsCache.clear();
          await loadPlantsFromAPI();
          return true;
        } else {
          _errorMessage = data['message'] ?? 'Failed to add plant';
        }
      } else {
        _errorMessage =
            'Server error: ${response.statusCode} - ${response.body}';
      }
    } on SocketException catch (e) {
      _errorMessage = 'Network error: Cannot connect to server';
      debugPrint('Socket exception adding plant: $e');
    } catch (e) {
      _errorMessage = 'Error adding plant: $e';
      debugPrint('Error adding plant: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Memuat data dari SharedPreferences
  Future<void> _loadPlants() async {
    try {
      debugPrint('Loading plants from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();

      // Memuat tanaman yang sedang ditrack
      final trackedJson = prefs.getString('tracked_plants');
      if (trackedJson != null) {
        _trackedPlants = (json.decode(trackedJson) as List)
            .map((item) => Plant.fromJson(item))
            .toList();
        debugPrint('Loaded ${_trackedPlants.length} tracked plants from cache');
      }

      // Memuat riwayat tanaman
      final historicalJson = prefs.getString('historical_plants');
      if (historicalJson != null) {
        _historicalPlants = (json.decode(historicalJson) as List)
            .map((item) => Plant.fromJson(item))
            .toList();
        debugPrint(
            'Loaded ${_historicalPlants.length} historical plants from cache');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading plants from SharedPreferences: $e');
    }
  }

  // Menyimpan data ke SharedPreferences
  Future<void> _savePlants() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'tracked_plants',
        json.encode(_trackedPlants.map((plant) => plant.toJson()).toList()),
      );

      await prefs.setString(
        'historical_plants',
        json.encode(_historicalPlants.map((plant) => plant.toJson()).toList()),
      );

      debugPrint('Plants saved to SharedPreferences successfully');
    } catch (e) {
      debugPrint('Error saving plants to SharedPreferences: $e');
    }
  }

  // METHODS LAINNYA (tidak berubah)
  void setHistoryFilter(String? filter) {
    _historyFilter = filter;
    notifyListeners();
  }

  Future<void> addPlant(Plant plant) async {
    _trackedPlants.add(plant);
    await _savePlants();
    notifyListeners();
  }

  Future<void> updatePlant(Plant updatedPlant) async {
    final index = _trackedPlants.indexWhere((p) => p.name == updatedPlant.name);
    if (index != -1) {
      final originalStartDate = _trackedPlants[index].startDate;
      final originalTasks = _trackedPlants[index].tasks;

      // ✅ DEBUG: CEK DATA SEBELUM UPDATE
      debugPrint('🔄 BEFORE UPDATE:');
      debugPrint('   Plant: ${updatedPlant.name}');
      debugPrint('   completedTargets: ${updatedPlant.completedTargets}');
      debugPrint('   targetProblems: ${updatedPlant.targetProblems}');
      debugPrint('   progress: ${updatedPlant.progress}');

      // Update local data
      _trackedPlants[index] = updatedPlant.copyWith(
        startDate: originalStartDate,
        tasks: originalTasks,
      );

      // ✅ DEBUG: CEK DATA SETELAH LOCAL UPDATE
      debugPrint('🔄 AFTER LOCAL UPDATE:');
      debugPrint(
          '   completedTargets: ${_trackedPlants[index].completedTargets}');
      debugPrint('   targetProblems: ${_trackedPlants[index].targetProblems}');

      // Update database if trackerId available
      if (updatedPlant.trackerId != null) {
        try {
          final userId = _userProvider?.currentUser?['id'];
          if (userId != null) {
            // ✅ DEBUG: CHECK TRACKER INFO
            debugPrint('🔍 Updating database:');
            debugPrint('   tracker_id: ${updatedPlant.trackerId}');
            debugPrint('   user_id: $userId');
            debugPrint('   plant_name: ${updatedPlant.name}');

            // ✅ CONVERT TO ARRAY FORMAT (sesuai database)
            List<bool> completedTargetsArray = [];
            List<String?> targetProblemsArray = [];

            // Find max index
            int maxIndex = 0;
            if (updatedPlant.completedTargets?.isNotEmpty == true) {
              maxIndex = math.max(maxIndex,
                  updatedPlant.completedTargets!.keys.fold(0, math.max));
            }
            if (updatedPlant.targetProblems?.isNotEmpty == true) {
              maxIndex = math.max(maxIndex,
                  updatedPlant.targetProblems!.keys.fold(0, math.max));
            }

            // Build arrays
            for (int i = 0; i <= maxIndex; i++) {
              completedTargetsArray
                  .add(updatedPlant.completedTargets?[i] ?? false);
              targetProblemsArray.add(updatedPlant.targetProblems?[i]);
            }

            final requestBody = {
              'tracker_id': updatedPlant.trackerId,
              'progress': updatedPlant.progress,
              'notes': updatedPlant.notes,
              'completed_targets': completedTargetsArray, // ✅ ARRAY FORMAT
              'target_problems': targetProblemsArray, // ✅ ARRAY FORMAT
            };

            debugPrint('🔄 SENDING TO DATABASE (ARRAY FORMAT):');
            debugPrint('   completedTargets: $completedTargetsArray');
            debugPrint('   targetProblems: $targetProblemsArray');
            debugPrint('   Full request: $requestBody');

            final response = await http.put(
              Uri.parse('$_baseUrl/user_plants.php'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $userId',
              },
              body: json.encode(requestBody),
            );

            debugPrint(
                '🔄 DATABASE RESPONSE: ${response.statusCode} - ${response.body}');

            if (response.statusCode == 200) {
              final responseData = json.decode(response.body);
              if (responseData['success'] == true) {
                debugPrint('✅ Database update SUCCESS!');
              } else {
                debugPrint(
                    '❌ Database update failed: ${responseData['message']}');
                // Check if tracker_id exists
                debugPrint('🔍 Possible causes:');
                debugPrint(
                    '   - tracker_id ${updatedPlant.trackerId} not found');
                debugPrint('   - user_id $userId mismatch');
                debugPrint('   - plant status not "tracking"');
              }
            } else {
              debugPrint(
                  '❌ HTTP error: ${response.statusCode} - ${response.body}');
            }
          } else {
            debugPrint('❌ No user ID found');
          }
        } catch (e) {
          debugPrint('❌ Error updating plant in database: $e');
        }
      } else {
        debugPrint('⚠️ No trackerId found, skipping database update');
      }

      await _savePlants();
      notifyListeners();
      debugPrint('✅ updatePlant completed for ${updatedPlant.name}');
    } else {
      debugPrint('❌ Plant not found in tracked plants: ${updatedPlant.name}');
    }
  }

  Future<void> removePlant(String plantName) async {
    _trackedPlants.removeWhere((p) => p.name == plantName);
    await _savePlants();
    notifyListeners();
  }

  Future<void> endPlanting(String plantName, String status) async {
    final index = _trackedPlants.indexWhere((p) => p.name == plantName);
    if (index != -1) {
      final plant = _trackedPlants[index].copyWith(
        endDate: DateTime.now(),
        status: status,
      );

      _historicalPlants.add(plant);
      _trackedPlants.removeAt(index);

      await _savePlants();
      notifyListeners();
    }
  }

  Future<void> completePlantingWithStatus({
    required String plantName,
    required String status,
    required Map<int, bool> completedTargets,
    required Map<int, String?> targetProblems,
  }) async {
    try {
      final index = _trackedPlants.indexWhere((p) => p.name == plantName);
      if (index == -1) {
        throw Exception('Plant not found: $plantName');
      }

      // ✅ PRESERVE ALL ORIGINAL DATA INCLUDING plantId
      final originalPlant = _trackedPlants[index];
      final plant = originalPlant.copyWith(
        endDate: DateTime.now(),
        status: status,
        progress: status == 'completed' ? 1.0 : originalPlant.progress,
        // ✅ MAKE SURE plantId IS PRESERVED
        plantId: originalPlant.plantId,
        completedTargets: completedTargets,
        targetProblems: targetProblems,
      );

      final userId = _userProvider?.currentUser?['id'];
      if (userId == null) {
        throw Exception('User not logged in');
      }

      if (plant.trackerId == null) {
        throw Exception('Plant tracker ID is null');
      }

      debugPrint('Completing plant: $plantName with status: $status');
      debugPrint('🔍 Original plant data:');
      debugPrint('  - Plant ID: ${originalPlant.plantId}');
      debugPrint('  - Tracker ID: ${originalPlant.trackerId}');
      debugPrint('  - Name: ${originalPlant.name}');
      debugPrint('  - Duration: ${originalPlant.duration}');
      debugPrint('📋 Copied plant data:');
      debugPrint('  - Plant ID preserved: ${plant.plantId}');
      debugPrint('  - Status: ${plant.status}');
      debugPrint('  - Progress: ${plant.progress}');

      // 1. ✅ SUPER SIMPLE UPDATE - HANYA YANG PENTING!
      final updateResponse = await http
          .put(
            Uri.parse('$_baseUrl/user_plants.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userId',
            },
            body: json.encode({
              'tracker_id': plant.trackerId,
              'status': status,
              'progress': plant.progress,
            }),
          )
          .timeout(Duration(seconds: 15));

      debugPrint('Update response: ${updateResponse.statusCode}');

      if (updateResponse.statusCode != 200) {
        debugPrint('Update failed but continuing...');
      }

      // 2. ✅ HISTORY REQUEST SESUAI STRUKTUR TABEL (TANPA plant_id)
      final historyResponse = await http
          .post(
            Uri.parse('$_baseUrl/history.php'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'user_plant_id': plant.trackerId,
              'user_id': userId,
              'plant_name': plant.name,
              'start_date': plant.startDate.toIso8601String(),
              'end_date': plant.endDate?.toIso8601String(),
              'status': status,
              'notes': plant.notes,
            }),
          )
          .timeout(Duration(seconds: 15));

      debugPrint('History response: ${historyResponse.statusCode}');

      // 3. ✅ UPDATE LOCAL STATE - ALWAYS SUCCESS!
      _historicalPlants.add(plant);
      _trackedPlants.removeAt(index);
      await _savePlants();

      debugPrint(
          'Plant completed successfully with plantId: ${plant.plantId}!');
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing plant: $e');

      // ✅ BAHKAN KALAU ERROR, TETAP PINDAHKAN KE HISTORY LOCAL
      try {
        final index = _trackedPlants.indexWhere((p) => p.name == plantName);
        if (index != -1) {
          final originalPlant = _trackedPlants[index];
          final plant = originalPlant.copyWith(
            endDate: DateTime.now(),
            status: status,
            // ✅ PRESERVE plantId EVEN IN ERROR CASE
            plantId: originalPlant.plantId,
            completedTargets: completedTargets,
            targetProblems: targetProblems,
          );
          _historicalPlants.add(plant);
          _trackedPlants.removeAt(index);
          await _savePlants();
          notifyListeners();

          debugPrint(
              'Plant moved to history locally despite error, plantId preserved: ${plant.plantId}');
        }
      } catch (localError) {
        debugPrint('Local update also failed: $localError');
      }

      // ✅ JANGAN THROW ERROR - BIAR USER TIDAK KENA ERROR MESSAGE
      // rethrow;
    }
  }

  Future<void> addPlantNote(String plantName, String note) async {
    final index = _trackedPlants.indexWhere((p) => p.name == plantName);
    if (index != -1) {
      _trackedPlants[index] = _trackedPlants[index].copyWith(
        notes: note,
      );
      await _savePlants();
      notifyListeners();
    }
  }

  Plant? getPlantByName(String name) {
    try {
      return _trackedPlants.firstWhere((p) => p.name == name);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateTaskStatus(
      String plantName, int taskIndex, bool completed) async {
    final plantIndex = _trackedPlants.indexWhere((p) => p.name == plantName);
    if (plantIndex != -1) {
      final updatedTasks =
          List<PlantTask>.from(_trackedPlants[plantIndex].tasks);
      updatedTasks[taskIndex] = updatedTasks[taskIndex].copyWith(
        completed: completed,
        completionDate: completed ? DateTime.now() : null,
      );

      _trackedPlants[plantIndex] = _trackedPlants[plantIndex].copyWith(
        tasks: updatedTasks,
      );

      final completedCount =
          updatedTasks.where((task) => task.completed).length;
      final newProgress =
          updatedTasks.isEmpty ? 0.0 : completedCount / updatedTasks.length;

      _trackedPlants[plantIndex] = _trackedPlants[plantIndex].copyWith(
        progress: newProgress,
      );

      await _savePlants();
      notifyListeners();
    }
  }
}
