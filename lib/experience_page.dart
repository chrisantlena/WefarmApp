import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:wefarm/models/plant_model.dart';
import 'package:wefarm/models/user_provider.dart';
import '../models/experience_model.dart';
import '../models/experience_provider.dart';
import '../models/plant_provider.dart';
import 'custom_drawer.dart';
import 'package:http/http.dart' as http;

class ExperiencePage extends StatefulWidget {
  final Plant? initialPlant;

  const ExperiencePage({super.key, this.initialPlant});

  @override
  State<ExperiencePage> createState() => _ExperiencePageState();
}

class _ExperiencePageState extends State<ExperiencePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = 0;

    // If initial plant is provided, directly open the add experience dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPlant != null) {
        _showAddExperienceDialog(context);
      }
      Provider.of<ExperienceProvider>(context, listen: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const CustomDrawer(currentIndex: -1),
      appBar: AppBar(
        title: const Text('Experience'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
        backgroundColor: const Color(0xFFf5bd52),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Community'),
            Tab(text: 'My Experiences'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OthersExperiencesTab(),
          _MyExperiencesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFf5bd52),
        child: const Icon(Icons.add),
        onPressed: () => _showAddExperienceDialog(context),
      ),
    );
  }

  void _showAddExperienceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bagikan Pengalaman'),
        content: const Text(
            'Apakah Anda ingin berbagi pengalaman menanam tanaman ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf5bd52),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _AddExperiencePage(
                    initialPlant: widget.initialPlant,
                  ),
                ),
              );
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }
}

// Tab for community experiences
class _OthersExperiencesTab extends StatefulWidget {
  const _OthersExperiencesTab();

  @override
  State<_OthersExperiencesTab> createState() => _OthersExperiencesTabState();
}

class _OthersExperiencesTabState extends State<_OthersExperiencesTab> {
  Future<List<Map<String, dynamic>>> _fetchCommunityExperiences() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.56.1/wefarm/lib/experience.php?community=1'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load experiences');
        }
      }
      throw Exception('Failed to load experiences');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCommunityExperiences(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final experiences = snapshot.data ?? [];

        if (experiences.isEmpty) {
          return const Center(child: Text('No community experiences yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: experiences.length,
          itemBuilder: (context, index) {
            final experience = experiences[index];
            return _buildExperienceCard(context, experience);
          },
        );
      },
    );
  }
}

// Tab for user's own experiences
class _MyExperiencesTab extends StatefulWidget {
  const _MyExperiencesTab();

  @override
  State<_MyExperiencesTab> createState() => _MyExperiencesTabState();
}

class _MyExperiencesTabState extends State<_MyExperiencesTab> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMyExperiences();
  }

  Future<void> _loadMyExperiences() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final experienceProvider =
          Provider.of<ExperienceProvider>(context, listen: false);

      print('User from provider: ${userProvider.user}');
      print('User type: ${userProvider.user.runtimeType}');

      if (userProvider.user != null) {
        // FIXED: Access the id property of the User object
        String userIdString = userProvider.user!.id;
        int userId = int.tryParse(userIdString) ?? 0;

        print('User ID string: $userIdString');
        print('Converted userId: $userId');

        if (userId > 0) {
          await experienceProvider.fetchMyExperiences(userId);
          print(
              'My experiences count: ${experienceProvider.myExperiences.length}');
        } else {
          setState(() {
            _errorMessage = 'Invalid user ID: $userIdString';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'User not logged in';
        });
      }
    } catch (e) {
      print('Error loading my experiences: $e');
      setState(() {
        _errorMessage = 'Error loading experiences: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMyExperiences,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Consumer<ExperienceProvider>(
      builder: (context, experienceProvider, child) {
        print(
            'Building with experiences count: ${experienceProvider.myExperiences.length}');

        if (experienceProvider.myExperiences.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have no experiences yet'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMyExperiences,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadMyExperiences,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: experienceProvider.myExperiences.length,
            itemBuilder: (context, index) {
              final experience = experienceProvider.myExperiences[index];
              return _buildExperienceCard(context, experience);
            },
          ),
        );
      },
    );
  }
}

// Widget to build experience card
Widget _buildExperienceCard(BuildContext context, dynamic experience) {
  Color statusColor;
  String statusText;

  // Handle both Experience object and Map
  String status;
  if (experience is Experience) {
    status = experience.status;
  } else if (experience is Map<String, dynamic>) {
    status = experience['status'] ?? '';
  } else {
    status = '';
  }

  // Map database status to display status
  switch (status.toLowerCase()) {
    case 'completed':
    case 'success':
      statusColor = Colors.green;
      statusText = 'Success';
      break;
    case 'failed':
      statusColor = Colors.red;
      statusText = 'Failed';
      break;
    case 'canceled':
    case 'cancelled':
    case 'terminated':
      statusColor = Colors.orange;
      statusText = 'Terminated';
      break;
    default:
      statusColor = Colors.grey;
      statusText = status;
  }

  String plantName, author, review, startDate, endDate;
  DateTime createdAt;

  if (experience is Experience) {
    plantName = experience.plantName;
    author = experience.author;
    review = experience.review;
    startDate = experience.formattedStartDate;
    endDate = experience.formattedEndDate;
    createdAt = experience.createdAt;
  } else {
    plantName = experience['plant_name'] ?? '';
    author = experience['author'] ?? 'Unknown';
    review = experience['experience'] ?? '';
    startDate = experience['start_date'] ?? '';
    endDate = experience['end_date'] ?? '';
    createdAt =
        DateTime.tryParse(experience['created_at'] ?? '') ?? DateTime.now();
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      onTap: () => _showExperienceDetails(context, experience),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plantName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$author • ${timeago.format(createdAt, locale: 'en_short')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '$startDate - $endDate',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Show full experience details
void _showExperienceDetails(BuildContext context, dynamic experience) {
  String plantName, author, review, startDate, endDate;
  DateTime createdAt;

  if (experience is Experience) {
    plantName = experience.plantName;
    author = experience.author;
    review = experience.review;
    startDate = experience.formattedStartDate;
    endDate = experience.formattedEndDate;
    createdAt = experience.createdAt;
  } else {
    plantName = experience['plant_name'] ?? '';
    author = experience['author'] ?? 'Unknown';
    review = experience['experience'] ?? '';
    startDate = experience['start_date'] ?? '';
    endDate = experience['end_date'] ?? '';
    createdAt =
        DateTime.tryParse(experience['created_at'] ?? '') ?? DateTime.now();
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plantName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$author • ${timeago.format(createdAt, locale: 'en_short')}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            review,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            'Period: $startDate - $endDate',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf5bd52),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    ),
  );
}

// Add experience page
class _AddExperiencePage extends StatefulWidget {
  final Plant? initialPlant;

  const _AddExperiencePage({this.initialPlant});
  @override
  State<_AddExperiencePage> createState() => _AddExperiencePageState();
}

class _AddExperiencePageState extends State<_AddExperiencePage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedPlant;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;
  final TextEditingController _reviewController = TextEditingController();

  final List<String> _statusOptions = ['Success', 'Failed', 'Terminated'];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Auto-fill data from initial plant if provided
    if (widget.initialPlant != null) {
      _selectedPlant = widget.initialPlant!.name;
      _startDate = widget.initialPlant!.startDate;
      _endDate = widget.initialPlant!.endDate ?? DateTime.now();

      // ✅ AUTO-FILL STATUS dari plant status
      if (widget.initialPlant!.status != null) {
        // Map status dari history ke dropdown
        switch (widget.initialPlant!.status) {
          case 'completed':
            _selectedStatus = 'Success';
            break;
          case 'failed':
            _selectedStatus = 'Failed';
            break;
          case 'canceled':
          case 'cancelled':
            _selectedStatus = 'Terminated';
            break;
          default:
            _selectedStatus = null;
        }

        debugPrint(
            '🎯 Auto-filled status: ${widget.initialPlant!.status} -> $_selectedStatus');
      }
    } else {
      _endDate = DateTime.now();
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (userProvider.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      // Validasi tambahan
      if (_startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start date')),
        );
        return;
      }

      if (_endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select end date')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm'),
          content: const Text('Save and share your experience?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf5bd52),
              ),
              onPressed: () async {
                Navigator.pop(context); // Close confirmation dialog

                // Show loading dialog
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('Saving experience...'),
                            ],
                          ),
                        ));

                try {
                  // FIXED: Get user ID from the User object
                  String userIdString = userProvider.user!.id;
                  int userId = int.tryParse(userIdString) ?? 0;

                  if (userId <= 0) {
                    Navigator.pop(context); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid user ID: $userIdString'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final requestData = {
                    'user_id': userId, // Now using the correct user ID
                    'plant_name': _selectedPlant,
                    'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
                    'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
                    'status': _selectedStatus,
                    'experience': _reviewController.text.trim(),
                  };

                  print('Sending request: ${json.encode(requestData)}');

                  final response = await http.post(
                    Uri.parse('http://192.168.56.1/wefarm/lib/experience.php'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                    },
                    body: json.encode(requestData),
                  );

                  print('Response status: ${response.statusCode}');
                  print('Response body: ${response.body}');

                  Navigator.pop(context); // Close loading dialog

                  if (response.statusCode == 201) {
                    final data = json.decode(response.body);
                    if (data['success'] == true) {
                      Navigator.pop(context); // Go back to previous screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Experience shared successfully!')),
                      );
                    } else {
                      String errorMessage =
                          data['message'] ?? 'Unknown error occurred';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $errorMessage'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );

                      print('API Error: $errorMessage');
                      if (data.containsKey('received_data')) {
                        print('Received data: ${data['received_data']}');
                      }
                    }
                  } else {
                    String errorMsg =
                        'HTTP ${response.statusCode}: Failed to share experience';
                    if (response.body.isNotEmpty) {
                      try {
                        final errorData = json.decode(response.body);
                        errorMsg = errorData['message'] ?? errorMsg;
                      } catch (e) {
                        errorMsg += '\nResponse: ${response.body}';
                      }
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMsg),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context); // Close loading dialog
                  print('Exception occurred: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Network Error: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const CustomDrawer(currentIndex: -1),
      appBar: AppBar(
        title: const Text('Add Experience'),
        backgroundColor: const Color(0xFFf5bd52),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plant Selection
              const Text(
                'Plant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Consumer<PlantProvider>(
                builder: (context, plantProvider, child) {
                  final plants = plantProvider.allPlants;

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      hintText: 'Select plant',
                    ),
                    value: _selectedPlant,
                    items: plants.map((plant) {
                      return DropdownMenuItem<String>(
                        value: plant['name'],
                        child: Text(plant['name']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedPlant = value);
                    },
                    validator: (value) =>
                        value == null ? 'Please select a plant' : null,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Start Date
              const Text(
                'Start Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectStartDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _startDate != null
                            ? DateFormat('dd/MM/yyyy').format(_startDate!)
                            : 'Select date',
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // End Date
              const Text(
                'End Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectEndDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _endDate != null
                            ? DateFormat('dd/MM/yyyy').format(_endDate!)
                            : 'Select date',
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Status
              const Text(
                'Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  hintText: 'Select status',
                ),
                value: _selectedStatus,
                items: _statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                },
                validator: (value) =>
                    value == null ? 'Please select a status' : null,
              ),
              const SizedBox(height: 24),

              // Review
              const Text(
                'Review',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reviewController,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Share your planting experience...',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your review'
                    : null,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf5bd52),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _submitForm,
                  child: const Text('Save Experience'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
