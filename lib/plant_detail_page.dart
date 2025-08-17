import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/plant_model.dart';
import '../models/plant_provider.dart';
import 'custom_drawer.dart';
import 'package:wefarm/history_page.dart';
import 'package:wefarm/experience_page.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PlantDetailPage extends StatefulWidget {
  final Plant plant;

  const PlantDetailPage({super.key, required this.plant});

  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  late Plant currentPlant;
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  final List<Map<String, dynamic>> _notesList = [];
  final TextEditingController _newNoteController = TextEditingController();
  DateTime? _selectedPlantingDate;
  late Map<int, bool> _completedTargets;
  late Map<int, String?> _targetProblems;
  bool get _isPlantCompleted => currentPlant.progress >= 1.0;

  @override
  void initState() {
    super.initState();

    // ✅ DON'T RESET TASK COMPLETION - USE AS IS
    currentPlant = widget.plant;

    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedPlantingDate = currentPlant.startDate;

    // Inisialisasi notes
    if (currentPlant.notes?.isNotEmpty ?? false) {
      try {
        _notesList.addAll(currentPlant.notes!.split('\n').map((note) {
          final parts = note.split('|');
          return {
            'date': DateTime.parse(parts[0]),
            'content': parts[1],
          };
        }).toList());
      } catch (e) {
        _notesList.add({
          'date': DateTime.now(),
          'content': currentPlant.notes!,
        });
      }
    }

    // ✅ PERBAIKAN: PRIORITASKAN DATA DARI DATABASE DARIPADA KALKULASI PROGRESS
    final targetCount = currentPlant.targets.isNotEmpty
        ? currentPlant.targets.length
        : 4; // fallback ke 4 target default

    // ✅ PERTAMA: LOAD DARI DATABASE DULU (YANG PENTING!)
    _completedTargets = currentPlant.completedTargets ?? {};
    _targetProblems = currentPlant.targetProblems ?? {};

    // ✅ KEDUA: BARU ISI YANG KOSONG BERDASARKAN PROGRESS (BACKUP SAJA)
    for (int i = 0; i < targetCount; i++) {
      // Hanya isi jika belum ada data dari database
      if (!_completedTargets.containsKey(i)) {
        _completedTargets[i] =
            currentPlant.progress >= ((i + 1) * (1.0 / targetCount));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlantDetails();
    });
  }

  Future<void> _loadPlantDetails() async {
    if (currentPlant.plantId != null) {
      debugPrint(
          '🔍 PlantDetail: Loading details for plantId: ${currentPlant.plantId}');

      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      final details =
          await plantProvider.getPlantDetails(currentPlant.plantId!);

      if (details != null && mounted) {
        debugPrint('📋 PlantDetail: Got plant details: ${details.keys}');

        final newTargets = plantProvider.generateTargetsFromPlantData(details);
        final newTasks = plantProvider.generateTasksFromPlantData(details);

        debugPrint('🎯 PlantDetail: Generated ${newTargets.length} targets');
        debugPrint(
            '📝 PlantDetail: Generated ${newTasks.length} tasks: ${newTasks.map((t) => t.name).toList()}');

        // ✅ PRESERVE EXISTING TASK COMPLETION STATUS
        List<PlantTask> preservedTasks = [];
        for (int i = 0; i < newTasks.length; i++) {
          final newTask = newTasks[i];

          // Cari task dengan nama yang sama di current tasks
          final existingTask = currentPlant.tasks.firstWhere(
            (task) => task.name == newTask.name,
            orElse: () => newTask,
          );

          preservedTasks.add(newTask.copyWith(
            completed: existingTask.completed,
            completionDate: existingTask.completionDate,
          ));
        }

        debugPrint(
            '💾 PlantDetail: Preserved ${preservedTasks.length} tasks with completion status');

        setState(() {
          currentPlant = currentPlant.copyWith(
            targets: newTargets,
            tasks: preservedTasks,
          );

          // ✅ JANGAN RESET _completedTargets! PRESERVE YANG SUDAH ADA
          // _completedTargets sudah di-set dari currentPlant.completedTargets di initState
          // Jadi tidak perlu di-reset lagi di sini

          debugPrint(
              '✅ PlantDetail: _completedTargets preserved: $_completedTargets');
        });

        debugPrint(
            '✅ PlantDetail: Updated plant with ${newTargets.length} targets and ${preservedTasks.length} tasks');
      } else {
        debugPrint('❌ PlantDetail: Plant details is null or widget unmounted');
      }
    } else {
      debugPrint('❌ PlantDetail: plantId is null');
    }
  }

  @override
  void dispose() {
    _newNoteController.dispose();
    super.dispose();
  }

  int _parseDuration(String duration) {
    try {
      final months = duration.split(' ').first.split('-').first;
      return int.parse(months) * 30;
    } catch (e) {
      return 90;
    }
  }

  CalendarStyle _calendarStyle(BuildContext context) {
    return CalendarStyle(
      selectedDecoration: BoxDecoration(
        color: const Color(0xFFf5bd52),
        shape: BoxShape.circle,
      ),
      todayDecoration: BoxDecoration(
        color: const Color(0xFFf5bd52).withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      markerDecoration: BoxDecoration(
        color: Colors.green.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      markersMaxCount: 1,
    );
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    if (_selectedPlantingDate == null) return [];

    final daysSincePlanting = day.difference(_selectedPlantingDate!).inDays;

    if (daysSincePlanting == 0 ||
        daysSincePlanting == 7 ||
        daysSincePlanting == 14 ||
        daysSincePlanting == 30) {
      return [day];
    }
    return [];
  }

  void _toggleTask(int index) {
    setState(() {
      final updatedTasks = List<PlantTask>.from(currentPlant.tasks);
      updatedTasks[index] = updatedTasks[index].copyWith(
        completed: !updatedTasks[index].completed,
        completionDate: !updatedTasks[index].completed ? DateTime.now() : null,
      );

      currentPlant = currentPlant.copyWith(tasks: updatedTasks);
      _updateProgressBasedOnTasks();
    });
  }

  void _updateProgressBasedOnTasks() {
    final targetCount = currentPlant.targets.isNotEmpty
        ? currentPlant.targets.length
        : 4; // fallback

    // Cari target tertinggi yang dicentang
    int highestCompleted = -1;
    for (int i = 0; i < targetCount; i++) {
      if (_completedTargets[i] ?? false) {
        highestCompleted = i;
      } else {
        break;
      }
    }

    // ✅ DYNAMIC PROGRESS CALCULATION BASED ON TARGET COUNT
    final targetProgress = highestCompleted >= 0
        ? (highestCompleted + 1) * (1.0 / targetCount)
        : 0.0;

    // Bonus progress dari task harian (maksimal 10%)
    final taskBonus = currentPlant.tasks.isEmpty
        ? 0.0
        : (currentPlant.tasks.where((t) => t.completed).length /
                currentPlant.tasks.length) *
            0.1;

    // Total progress
    final newProgress = (targetProgress + taskBonus).clamp(0.0, 1.0);

    setState(() {
      currentPlant = currentPlant.copyWith(
        progress: newProgress,
        targetProblems: _targetProblems,
        completedTargets: _completedTargets,
      );
    });

    // Simpan perubahan ke database
    _saveChanges();
  }

  Future<void> _saveChanges() async {
    final serializedNotes = _notesList
        .map((note) => '${note['date'].toIso8601String()}|${note['content']}')
        .join('\n');

    await Provider.of<PlantProvider>(context, listen: false).updatePlant(
      currentPlant.copyWith(
        notes: serializedNotes,
        targetProblems: _targetProblems,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  // Format tanggal yang lebih rapi untuk catatan
  String _formatDateOnly(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _showTargetStatusDialog(int milestoneIndex) async {
    final targetCount =
        currentPlant.targets.isNotEmpty ? currentPlant.targets.length : 4;
    final isCompleted = _completedTargets[milestoneIndex] ?? false;
    final hasProblem = _targetProblems[milestoneIndex] != null;
    final isLocked =
        milestoneIndex > 0 && !(_completedTargets[milestoneIndex - 1] ?? false);

    if (isLocked) return;

    // ✅ CASE 1: TARGET BERMASALAH (MERAH) - POPUP BATALKAN MASALAH
    if (hasProblem) {
      return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Batalkan Masalah?'),
            content: const Text('Reset target ini kembali ke status kosong?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Tidak'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Ya, Batalkan'),
                onPressed: () {
                  setState(() {
                    // Reset target ke kosong
                    _completedTargets[milestoneIndex] = false;
                    _targetProblems.remove(milestoneIndex);

                    // Update plant object
                    currentPlant = currentPlant.copyWith(
                      targetProblems: _targetProblems,
                      completedTargets: _completedTargets,
                    );

                    _updateProgressBasedOnTasks();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    // ✅ CASE 2: TARGET BERHASIL (IJO) - POPUP BATALKAN TARGET
    else if (isCompleted) {
      return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Batalkan Target?'),
            content: const Text(
                'Membatalkan target ini akan membatalkan semua target setelahnya.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Tidak'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Ya'),
                onPressed: () {
                  setState(() {
                    // Batalkan target ini dan semua target setelahnya
                    for (int i = milestoneIndex; i < targetCount; i++) {
                      _completedTargets[i] = false;
                      _targetProblems.remove(i);
                    }

                    // Update plant object
                    currentPlant = currentPlant.copyWith(
                      targetProblems: _targetProblems,
                      completedTargets: _completedTargets,
                    );

                    _updateProgressBasedOnTasks();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    // ✅ CASE 3: TARGET KOSONG - POPUP PILIHAN SEPERTI BIASA
    else {
      return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Status Target'),
            content: const Text('Apakah target ini sudah terpenuhi?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Ada Masalah'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showProblemOptionsDialog(milestoneIndex);
                },
              ),
              TextButton(
                child: const Text('Sudah Terpenuhi'),
                onPressed: () {
                  setState(() {
                    // Centang target ini dan semua target sebelumnya
                    for (int i = 0; i <= milestoneIndex; i++) {
                      _completedTargets[i] = true;
                      _targetProblems.remove(i);
                    }

                    // Update plant object
                    currentPlant = currentPlant.copyWith(
                      targetProblems: _targetProblems,
                      completedTargets: _completedTargets,
                    );

                    _updateProgressBasedOnTasks();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _loadAndOpenProblemLink() async {
    try {
      if (currentPlant.plantId == null) {
        debugPrint('❌ Plant ID is null');
        _showErrorDialog('Plant ID tidak ditemukan');
        return;
      }

      debugPrint('🔍 Looking for plant ID: ${currentPlant.plantId}');

      // ✅ FETCH LANGSUNG DARI API PLANTS.PHP
      final response = await http.get(
        Uri.parse(
            'http://192.168.56.1/wefarm/lib/plants.php?action=detail&id=${currentPlant.plantId}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
      ).timeout(Duration(seconds: 15));

      debugPrint('🌐 API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode != 200) {
        _showErrorDialog('Gagal mengambil data tanaman');
        return;
      }

      final data = json.decode(response.body);
      if (data['success'] != true || data['data'] == null) {
        _showErrorDialog('Data tanaman tidak ditemukan');
        return;
      }

      final plantData = data['data'];
      debugPrint('✅ Plant data found: ${plantData.keys}');

      if (!plantData.containsKey('problem_links') ||
          plantData['problem_links'] == null) {
        debugPrint('❌ No problem_links field found');
        _showErrorDialog(
            'Link artikel solusi tidak tersedia untuk tanaman ini');
        return;
      }

      dynamic problemLinksData = plantData['problem_links'];
      debugPrint('📝 Raw problem_links data: $problemLinksData');
      debugPrint('📝 Problem links type: ${problemLinksData.runtimeType}');

      // Handle JSON string
      if (problemLinksData is String) {
        try {
          problemLinksData = json.decode(problemLinksData);
          debugPrint('📝 Decoded problem_links: $problemLinksData');
        } catch (e) {
          debugPrint('❌ Error decoding problem_links JSON: $e');
          _showErrorDialog('Format link tidak valid');
          return;
        }
      }

      String? urlToOpen;

      // Handle Map structure (like tutorial_links)
      if (problemLinksData is Map<String, dynamic> &&
          problemLinksData.isNotEmpty) {
        urlToOpen = problemLinksData.values.first?.toString();
        debugPrint('🔗 Found URL from Map: $urlToOpen');
      }
      // Handle List structure (for backward compatibility)
      else if (problemLinksData is List && problemLinksData.isNotEmpty) {
        final firstLink = problemLinksData[0];
        if (firstLink is Map<String, dynamic> && firstLink['url'] != null) {
          urlToOpen = firstLink['url'].toString();
          debugPrint('🔗 Found URL from List: $urlToOpen');
        } else if (firstLink is String) {
          urlToOpen = firstLink;
          debugPrint('🔗 Found URL from List (string): $urlToOpen');
        }
      }

      if (urlToOpen == null || urlToOpen.isEmpty) {
        debugPrint('❌ No valid URL found');
        _showErrorDialog('Link artikel tidak valid');
        return;
      }

      debugPrint('🚀 Attempting to open URL: $urlToOpen');

      // Try to launch URL
      final uri = Uri.parse(urlToOpen);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('✅ URL opened successfully');
      } else {
        debugPrint('❌ Cannot launch URL: $urlToOpen');
        _showErrorDialog('Tidak dapat membuka link: $urlToOpen');
      }
    } catch (e) {
      debugPrint('❌ Error loading problem link: $e');
      _showErrorDialog('Gagal membuka artikel: $e');
    }
  }

// Add error dialog helper
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProblemOptionsDialog(int milestoneIndex) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ada Masalah?'),
          content: const Text('Pilih opsi untuk menangani masalah ini'),
          actions: <Widget>[
            TextButton(
              child: const Text('Tunggu Beberapa Hari'),
              onPressed: () {
                setState(() {
                  _targetProblems[milestoneIndex] = 'Menunggu perkembangan';
                  currentPlant = currentPlant.copyWith(
                    targetProblems: _targetProblems,
                    completedTargets: _completedTargets,
                  );
                });
                _saveChanges();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Baca Artikel Solusi'),
              onPressed: () async {
                // Set status
                setState(() {
                  _targetProblems[milestoneIndex] = 'Masalah dilaporkan';
                  currentPlant = currentPlant.copyWith(
                    targetProblems: _targetProblems,
                    completedTargets: _completedTargets,
                  );
                });
                _saveChanges();
                Navigator.of(context).pop();

                // Open problem link
                await _loadAndOpenProblemLink();
              },
            ),
          ],
        );
      },
    );
  }

  // Revisi: Modal bottom sheet untuk catatan dengan fitur hapus
  void _showPlantNotes() {
    final isHistoricalPlant = currentPlant.status != 'tracking';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Catatan ${currentPlant.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // List catatan yang sudah ada
              Expanded(
                child: _notesList.isEmpty
                    ? const Center(child: Text('Belum ada catatan'))
                    : ListView.builder(
                        itemCount: _notesList.length,
                        itemBuilder: (context, index) {
                          final note = _notesList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(note['content'].toString()),
                              subtitle: Text(_formatDateOnly(note['date'])),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  // Konfirmasi hapus
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Hapus Catatan'),
                                      content: const Text(
                                          'Yakin ingin menghapus catatan ini?'),
                                      actions: [
                                        TextButton(
                                          child: const Text('Batal'),
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                        ),
                                        TextButton(
                                          child: const Text('Hapus'),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldDelete == true) {
                                    setModalState(() {
                                      _notesList.removeAt(index);
                                    });
                                    setState(() {}); // Update main state juga
                                    await _saveChanges(); // Simpan ke database
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Form tambah catatan baru (hanya untuk plant yang masih tracking)
              if (!isHistoricalPlant) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _newNoteController,
                  decoration: const InputDecoration(
                    hintText: "Tambah catatan baru...",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_newNoteController.text.trim().isEmpty) return;

                      final note = {
                        'date': DateTime.now(),
                        'content': _newNoteController.text.trim(),
                      };

                      setModalState(() {
                        _notesList.add(note);
                        _newNoteController.clear();
                      });

                      setState(() {}); // Update main state juga
                      await _saveChanges(); // Simpan ke database
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFf5bd52),
                    ),
                    child: const Text("Simpan Catatan"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Revisi: Dialog untuk menyelesaikan penanaman dengan kondisi progress
  Future<void> _showCompletionDialog() async {
    List<Widget> actions = [
      TextButton(
        child: const Text('Batal'),
        onPressed: () => Navigator.pop(context),
      ),
    ];

    // Jika progress 100%, tampilkan semua opsi
    if (_isPlantCompleted) {
      actions.addAll([
        TextButton(
          child: const Text('Berhasil', style: TextStyle(color: Colors.green)),
          onPressed: () => Navigator.pop(context, 'completed'),
        ),
        TextButton(
          child:
              const Text('DiBatalkan', style: TextStyle(color: Colors.orange)),
          onPressed: () => Navigator.pop(context, 'canceled'),
        ),
        TextButton(
          child: const Text('Gagal', style: TextStyle(color: Colors.red)),
          onPressed: () => Navigator.pop(context, 'failed'),
        ),
      ]);
    } else {
      // Jika progress belum 100%, hanya tampilkan opsi gagal dan dihentikan
      actions.addAll([
        TextButton(
          child:
              const Text('Dibatalkan', style: TextStyle(color: Colors.orange)),
          onPressed: () => Navigator.pop(context, 'canceled'),
        ),
        TextButton(
          child: const Text('Gagal', style: TextStyle(color: Colors.red)),
          onPressed: () => Navigator.pop(context, 'failed'),
        ),
      ]);
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesai Menanam'),
        content: Text(_isPlantCompleted
            ? 'Pilih hasil penanaman:'
            : 'Progress belum 100%. Anda hanya bisa menghentikan atau menandai gagal:'),
        actions: actions,
      ),
    );

    if (result != null) {
      try {
        await Provider.of<PlantProvider>(context, listen: false)
            .completePlantingWithStatus(
          plantName: currentPlant.name,
          status: result,
          completedTargets: _completedTargets,
          targetProblems: _targetProblems,
        );

        // Navigasi ke halaman history
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HistoryPage()),
            (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tanaman telah dipindahkan ke riwayat ($result)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyelesaikan: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _navigateToShareExperience() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExperiencePage(
          initialPlant: widget.plant,
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(PlantDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plant != oldWidget.plant) {
      setState(() {
        currentPlant = widget.plant;

        // ✅ PERBAIKAN: PRIORITASKAN DATA DARI DATABASE
        final targetCount =
            currentPlant.targets.isNotEmpty ? currentPlant.targets.length : 4;

        // ✅ PERTAMA: LOAD DARI DATABASE DULU
        _completedTargets = currentPlant.completedTargets ?? {};
        _targetProblems = currentPlant.targetProblems ?? {};

        // ✅ KEDUA: BARU ISI YANG KOSONG BERDASARKAN PROGRESS
        for (int i = 0; i < targetCount; i++) {
          if (!_completedTargets.containsKey(i)) {
            _completedTargets[i] =
                currentPlant.progress >= ((i + 1) * (1.0 / targetCount));
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimatedEndDate = _selectedPlantingDate
        ?.add(Duration(days: _parseDuration(currentPlant.duration)));

    return WillPopScope(
      onWillPop: () async {
        // Kembalikan plant yang sudah diupdate saat back
        Navigator.pop(context, currentPlant);
        return false;
      },
      child: Scaffold(
        endDrawer: const CustomDrawer(currentIndex: -1),
        appBar: AppBar(
          title: Text(currentPlant.name),
          backgroundColor: const Color(0xFFf5bd52),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.note),
              onPressed: _showPlantNotes,
              tooltip: 'Catatan',
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TableCalendar(
                        firstDay: _selectedPlantingDate ?? DateTime.now(),
                        lastDay: (_selectedPlantingDate ?? DateTime.now())
                            .add(const Duration(days: 365)),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        calendarStyle: _calendarStyle(context),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false, // Disable format changing
                          titleCentered: true,
                        ),
                        eventLoader: _getEventsForDay,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedPlantingDate, day);
                        },
                        onDaySelected: null, // Disable date selection
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mulai: ${_formatDate(_selectedPlantingDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Estimasi Panen: ${_formatDate(estimatedEndDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildProgressSection(),
              const SizedBox(height: 16),
              _buildMilestonesSection(),
              const SizedBox(height: 16),
              _buildTasksSection(),
              const SizedBox(height: 16),
              // Revisi: Hapus section catatan dari body, sekarang hanya ada tombol selesai menanam
              _buildActionSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final completedTargets = _completedTargets.values.where((c) => c).length;
    final completedTasks = currentPlant.tasks.where((t) => t.completed).length;
    final totalTargets =
        currentPlant.targets.isNotEmpty ? currentPlant.targets.length : 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Progress: ${(currentPlant.progress * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Target: ${currentPlant.duration}",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: currentPlant.progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFFf5bd52),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Target: $completedTargets/$totalTargets", // ✅ DYNAMIC TARGET COUNT
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  "Task: $completedTasks/${currentPlant.tasks.length}",
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Target Perkembangan:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Dynamic targets from database
            if (currentPlant.targets.isNotEmpty)
              ...currentPlant.targets.asMap().entries.map((entry) {
                final index = entry.key;
                final target = entry.value;
                return _buildMilestoneItem(
                    target.period, target.description, index);
              })
            else
              // Fallback to default targets if none in database
              ...[
              _buildMilestoneItem("Hari 1-7", "Muncul akar kecil", 0),
              _buildMilestoneItem("Hari 7-14", "Daun pertama muncul", 1),
              _buildMilestoneItem(
                  "Hari 14-30", "Batang mengeras dan tumbuh", 2),
              _buildMilestoneItem("Hari 30+", "Siap panen", 3),
            ],

            if (currentPlant.tutorialLinks.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Tutorial & Panduan:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...currentPlant.tutorialLinks
                  .map(
                    (link) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () => _openTutorialLink(link.url),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_outline,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                link.title,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  ,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneItem(
      String period, String description, int milestoneIndex) {
    final isCompleted = _completedTargets[milestoneIndex] ?? false;
    final hasProblem = _targetProblems[milestoneIndex] != null;
    final isLocked =
        milestoneIndex > 0 && !(_completedTargets[milestoneIndex - 1] ?? false);
    final isHistoricalPlant = currentPlant.status != 'tracking';

    return InkWell(
      onTap: (isLocked || isHistoricalPlant)
          ? null
          : () => _showTargetStatusDialog(milestoneIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Opacity(
              opacity: isHistoricalPlant ? 0.6 : 1.0,
              child: isLocked
                  ? const Icon(Icons.lock_outline, color: Colors.grey)
                  : isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : hasProblem
                          ? const Icon(Icons.error, color: Colors.red)
                          : Icon(Icons.radio_button_unchecked,
                              color: isHistoricalPlant
                                  ? Colors.grey
                                  : Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: isHistoricalPlant ? 0.6 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasProblem
                            ? Colors.red
                            : isLocked || isHistoricalPlant
                                ? Colors.grey
                                : null,
                        // ✅ FIX: STRIKETHROUGH HANYA UNTUK COMPLETED TANPA PROBLEM
                        decoration: isCompleted && !hasProblem
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: hasProblem
                            ? Colors.red
                            : isLocked || isHistoricalPlant
                                ? Colors.grey
                                : null,
                        // ✅ FIX: STRIKETHROUGH HANYA UNTUK COMPLETED TANPA PROBLEM
                        decoration: isCompleted && !hasProblem
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (hasProblem)
                      Text(
                        _targetProblems[milestoneIndex]!,
                        style: TextStyle(
                          color: isHistoricalPlant ? Colors.grey : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tugas Harian:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Use tasks from the plant object (which now comes from database)
            if (currentPlant.tasks.isNotEmpty)
              ...currentPlant.tasks.asMap().entries.map((entry) {
                final index = entry.key;
                final task = entry.value;
                return CheckboxListTile(
                  title: Text(
                    task.name,
                    style: TextStyle(
                      decoration:
                          task.completed ? TextDecoration.lineThrough : null,
                      color: task.completed ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.completionDate != null)
                        Text(
                          "Terakhir: ${_formatDate(task.completionDate)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  value: task.completed,
                  onChanged: (value) => _toggleTask(index),
                  activeColor: const Color(0xFFf5bd52),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              })
            else
              // Fallback message if no tasks
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Belum ada tugas harian yang ditentukan untuk tanaman ini.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openTutorialLink(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tutorial Link'),
        content: Text('Akan membuka: $url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final isHistoricalPlant = currentPlant.status != 'tracking';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isHistoricalPlant) ...[
              ElevatedButton(
                onPressed: _showCompletionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Selesai Menanam',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
            if (isHistoricalPlant) ...[
              ElevatedButton(
                onPressed: _navigateToShareExperience,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf5bd52),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Bagikan Pengalaman',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
