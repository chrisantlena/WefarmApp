import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'plant_detail_page.dart';
import 'package:wefarm/models/plant_model.dart';
import 'package:wefarm/models/plant_provider.dart';
import 'package:wefarm/models/user_provider.dart';
import 'custom_drawer.dart';
import 'package:http/http.dart' as http;

class GuidePage extends StatefulWidget {
  final String plantName;
  final String imagePath;
  final String plantGuide;
  final String? plantId;

  const GuidePage({
    super.key,
    required this.plantName,
    required this.imagePath,
    required this.plantGuide,
    this.plantId,
  });

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  List<RecommendedProduct> _recommendedProducts = [];
  bool _isLoadingProducts = false;
  String? _completeSourceUrl;

  Future<void> _loadCompleteSourceUrl() async {
    try {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);

      final plantData = plantProvider.allPlants.firstWhere(
        (plant) => plant["name"] == widget.plantName,
        orElse: () => <String, dynamic>{},
      );

      if (plantData.isNotEmpty &&
          plantData.containsKey('tutorial_links') &&
          plantData['tutorial_links'] != null) {
        dynamic tutorialLinksData = plantData['tutorial_links'];

        // Handle JSON string
        if (tutorialLinksData is String) {
          try {
            tutorialLinksData = json.decode(tutorialLinksData);
          } catch (e) {
            return;
          }
        }

        // Handle Map structure
        if (tutorialLinksData is Map<String, dynamic> &&
            tutorialLinksData.isNotEmpty) {
          final firstUrl = tutorialLinksData.values.first;
          if (firstUrl != null && firstUrl.toString().isNotEmpty) {
            setState(() {
              _completeSourceUrl = firstUrl.toString();
            });
          }
        }
        // Handle List structure
        else if (tutorialLinksData is List && tutorialLinksData.isNotEmpty) {
          final firstLink = tutorialLinksData[0];
          if (firstLink is Map<String, dynamic> && firstLink['url'] != null) {
            setState(() {
              _completeSourceUrl = firstLink['url'];
            });
          }
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPlantProducts();
    _loadCompleteSourceUrl();
  }

  Future<void> _loadPlantProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);

      // Find plant data from API
      final plantData = plantProvider.allPlants.firstWhere(
        (plant) => plant["name"] == widget.plantName,
        orElse: () => <String, dynamic>{},
      );

      if (plantData.isNotEmpty) {
        // Get plant details with products
        final plantDetails =
            await plantProvider.getPlantDetails(plantData['id']);

        if (plantDetails != null &&
            plantDetails['recommended_products'] != null) {
          final products = (plantDetails['recommended_products'] as List)
              .map((productData) => RecommendedProduct.fromJson(productData))
              .toList();

          setState(() {
            _recommendedProducts = products;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading plant products: $e');
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  String _getStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return '✅';
      case 'failed':
        return '❌';
      case 'canceled':
      case 'cancelled':
      case 'terminated':
        return '⚠️';
      default:
        return '🌱';
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Success';
      case 'success':
        return 'Success';
      case 'failed':
        return 'Failed';
      case 'canceled':
      case 'cancelled':
      case 'terminated':
        return 'Terminated';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      endDrawer: const CustomDrawer(currentIndex: -1),
      appBar: AppBar(
        title: Text(widget.plantName),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plant Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  widget.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, size: 50),
                        Text('Image not found'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Guide Title
            const Text(
              'Guide',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Guide Content
            Text(
              widget.plantGuide,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Complete Source
            const Text(
              'Complete Source:',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
            ),
            InkWell(
              onTap: () => _completeSourceUrl != null
                  ? launchUrlString(_completeSourceUrl!)
                  : launchUrlString(
                      'https://www.kompas.com/homey/read/2024/03/26/184000276/teknik-budidaya-cabai-rawit-yang-benar?page=2'),
              child: Text(
                'Cara Menanam ${widget.plantName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Product Recommendations
            _buildProductRecommendations(),

            const Divider(),
            const SizedBox(height: 20),

            // Show current tracked plants info
            Consumer<PlantProvider>(
              builder: (context, provider, child) {
                final trackedCount = provider.trackedPlants
                    .where((plant) => plant.name == widget.plantName)
                    .length;

                if (trackedCount > 0) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anda sudah menanam $trackedCount ${widget.plantName}${trackedCount > 1 ? '' : ''}. Anda bisa menanam lagi!',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  'Others Experience',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchExperiences(widget.plantName),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return const Text(
                          'Belum ada pengalaman untuk tanaman ini');
                    }
                    return Column(
                      children: snapshot.data!
                          .map((exp) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildUserExperience(
                                  emoji: _getStatusEmoji(exp['status'] ?? ''),
                                  name: exp['author'] ?? 'Anonymous',
                                  review:
                                      exp['experience'] ?? 'No review provided',
                                  status: _formatStatus(exp['status'] ?? ''),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),

            // Start Planting Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _handleStartPlanting(
                      context, plantProvider, userProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf5bd52),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Start Planting',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Recommendation:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoadingProducts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_recommendedProducts.isEmpty)
          // Fallback ke link statis jika tidak ada data dari API
          Column(
            children: [
              _buildProductLink(
                  'Link Pot', 'https://tokopedia.com/pot-tanaman'),
              _buildProductLink(
                  'Link Media Tanam', 'https://tokopedia.com/media-tanam'),
              _buildProductLink(
                  'Link Bibit', 'https://tokopedia.com/bibit-tanaman'),
            ],
          )
        else
          // Dynamic products dari database
          Column(
            children: _recommendedProducts
                .map((product) => _buildDynamicProductLink(product))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildDynamicProductLink(RecommendedProduct product) {
    return InkWell(
      onTap: () => _handleProductLinkTap(product),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.shopping_bag, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (product.priceRange != null)
                    Text(
                      'Rp ${product.priceRange}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  if (product.hasMultipleLinks)
                    Text(
                      'Tersedia di ${product.availablePlatforms.join(" & ")}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (product.hasMultipleLinks || product.link != null)
              const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // New method to handle product link tap with platform selection
  void _handleProductLinkTap(RecommendedProduct product) {
    if (product.hasMultipleLinks) {
      // Show platform selection popup
      _showPlatformSelectionDialog(product);
    } else if (product.link != null) {
      // Direct link for backward compatibility
      _openProductLink(product.link!);
    }
  }

  // New method to show platform selection dialog
  void _showPlatformSelectionDialog(RecommendedProduct product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Platform'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih platform untuk membeli ${product.name}:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Platform buttons
              ...product.availablePlatforms.map((platform) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final url = product.getLinkForPlatform(platform);
                      if (url != null) {
                        _openProductLink(url);
                      }
                    },
                    icon: _getPlatformIcon(platform),
                    label: Text(_getPlatformDisplayName(platform)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPlatformColor(platform),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  // Helper methods for platform-specific styling
  Icon _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'shopee':
        return const Icon(Icons.shopping_cart, size: 20);
      case 'tokopedia':
        return const Icon(Icons.store, size: 20);
      default:
        return const Icon(Icons.open_in_new, size: 20);
    }
  }

  String _getPlatformDisplayName(String platform) {
    switch (platform.toLowerCase()) {
      case 'shopee':
        return 'Shopee';
      case 'tokopedia':
        return 'Tokopedia';
      default:
        return platform;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'shopee':
        return const Color(0xFFEE4D2D); // Shopee orange
      case 'tokopedia':
        return const Color(0xFF42B549); // Tokopedia green
      default:
        return Colors.blue;
    }
  }

  void _openProductLink(String url) {
    // Use url_launcher to open the link
    launchUrlString(url);
  }

  Widget _buildProductLink(String text, String url) {
    return InkWell(
      onTap: () => launchUrlString('https://www.tokopedia.com/'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.link, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Rest of the existing methods remain unchanged...
  Future<List<Map<String, dynamic>>> _fetchExperiences(String plantName) async {
    try {
      print('Fetching experiences for plant: $plantName');

      final response = await http.get(
        Uri.parse('http://192.168.56.1/wefarm/lib/experience.php?community=1'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          List<Map<String, dynamic>> allExperiences =
              List<Map<String, dynamic>>.from(data['data']);

          List<Map<String, dynamic>> plantExperiences = allExperiences
              .where((exp) =>
                  exp['plant_name']?.toString().toLowerCase() ==
                  plantName.toLowerCase())
              .toList();

          print('Found ${plantExperiences.length} experiences for $plantName');

          return plantExperiences;
        } else {
          print('API returned success: false or no data');
          return [];
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching experiences: $e');
      return [];
    }
  }

  Future<void> _handleStartPlanting(
    BuildContext context,
    PlantProvider plantProvider,
    UserProvider userProvider,
  ) async {
    try {
      if (!userProvider.isLoggedIn || userProvider.currentUser == null) {
        _showErrorSnackBar(context, 'Silakan login terlebih dahulu');
        return;
      }

      final shouldProceed = await _showConfirmationDialog(context);
      if (!shouldProceed) return;

      _showLoadingDialog(context);

      final plantData = _findPlantData(plantProvider);
      if (plantData == null) {
        Navigator.pop(context);
        _showErrorSnackBar(context, 'Data tanaman tidak ditemukan');
        return;
      }

      final plantIdInt = _validatePlantId(plantData);
      if (plantIdInt == null) {
        Navigator.pop(context);
        _showErrorSnackBar(context, 'ID tanaman tidak valid');
        return;
      }

      final userId = _getUserId(userProvider);
      if (userId == null) {
        Navigator.pop(context);
        _showErrorSnackBar(context, 'User ID tidak ditemukan');
        return;
      }

      debugPrint('=== STARTING PLANTING DEBUG ===');
      debugPrint('Plant Name: ${widget.plantName}');
      debugPrint('Plant ID: $plantIdInt');
      debugPrint('User ID: $userId');
      debugPrint('Plant Data: $plantData');
      debugPrint('================================');

      final success = await plantProvider
          .startPlanting(
        plantId: plantIdInt,
        plantName: widget.plantName,
        userId: userId.toString(),
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('Start planting operation timed out');
          throw TimeoutException(
              'Connection timeout', const Duration(seconds: 20));
        },
      );

      Navigator.pop(context);

      if (success) {
        await plantProvider.loadTrackedPlants();
        await _handleSuccessfulPlanting(
            context, plantProvider, plantData, plantIdInt);
      } else {
        await _handleFailedPlanting(context, plantProvider);
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout exception: $e');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar(context, 'Koneksi timeout. Silakan coba lagi.');
    } catch (e) {
      debugPrint('Unexpected error in _handleStartPlanting: $e');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar(context, 'Terjadi kesalahan: ${e.toString()}');
    }
    if (context.mounted) {
      final newPlant = plantProvider.trackedPlants.firstWhere(
        (p) => p.plantId == widget.plantId,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PlantDetailPage(plant: newPlant),
        ),
      );
    }
  }

  Map<String, dynamic>? _findPlantData(PlantProvider plantProvider) {
    try {
      return plantProvider.allPlants.firstWhere(
        (plant) => plant["name"] == widget.plantName,
      );
    } catch (e) {
      debugPrint('Plant data not found for: ${widget.plantName}');
      return null;
    }
  }

  int? _validatePlantId(Map<String, dynamic> plantData) {
    final plantIdValue = plantData["id"];

    if (plantIdValue == null) {
      debugPrint('Plant ID is null');
      return null;
    }

    if (plantIdValue is int) {
      return plantIdValue > 0 ? plantIdValue : null;
    } else if (plantIdValue is String) {
      final parsed = int.tryParse(plantIdValue);
      return (parsed != null && parsed > 0) ? parsed : null;
    } else {
      debugPrint('Plant ID has unexpected type: ${plantIdValue.runtimeType}');
      return null;
    }
  }

  dynamic _getUserId(UserProvider userProvider) {
    final userId = userProvider.currentUser?['id'];

    if (userId == null) {
      debugPrint('User ID is null');
      return null;
    }

    if (userId is String && userId.trim().isEmpty) {
      debugPrint('User ID is empty string');
      return null;
    }

    return userId;
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    final trackedCount = plantProvider.trackedPlants
        .where((plant) => plant.name == widget.plantName)
        .length;

    String confirmationMessage = "Mulai menanam ${widget.plantName}?";
    if (trackedCount > 0) {
      confirmationMessage = "Mulai menanam ${widget.plantName} lagi?\n\n"
          "Anda sudah menanam $trackedCount ${widget.plantName}${trackedCount > 1 ? '' : ''} sebelumnya.";
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: Text(confirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf5bd52),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Ya"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text("Memulai penanaman...")),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSuccessfulPlanting(
    BuildContext context,
    PlantProvider plantProvider,
    Map<String, dynamic> plantData,
    int plantIdInt,
  ) async {
    try {
      final addedPlant = plantProvider.trackedPlants
          .where((plant) =>
              plant.name.startsWith(widget.plantName) &&
              plant.plantId == plantIdInt)
          .toList()
          .last;

      debugPrint('Found newly added plant: ${addedPlant.name}');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PlantDetailPage(plant: addedPlant),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil memulai penanaman ${addedPlant.name}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error in _handleSuccessfulPlanting: $e');

      final uniquePlantName = _generateTempUniqueName(plantProvider);
      final tempPlant = Plant(
        name: uniquePlantName,
        duration: plantData["duration"]?.toString() ?? '3-4 Bulan',
        startDate: DateTime.now(),
        progress: 0.0,
        tasks: [
          PlantTask(name: "Penyiraman", completed: false),
          PlantTask(name: "Pemupukan", completed: false),
        ],
        imagePath: plantData["image_path"]?.toString() ??
            plantData["image"]?.toString() ??
            widget.imagePath,
        plantId: plantIdInt,
        status: 'tracking',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PlantDetailPage(plant: tempPlant),
        ),
      );

      _showErrorSnackBar(context, 'Penanaman berhasil dimulai!', Colors.green);
    }
  }

  String _generateTempUniqueName(PlantProvider plantProvider) {
    final existingCount = plantProvider.trackedPlants
        .where((plant) => plant.name.startsWith(widget.plantName))
        .length;

    if (existingCount == 0) {
      return widget.plantName;
    }

    return "${widget.plantName} $existingCount";
  }

  Future<void> _handleFailedPlanting(
    BuildContext context,
    PlantProvider plantProvider,
  ) async {
    final errorMessage =
        plantProvider.errorMessage ?? 'Gagal memulai penanaman';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Coba Lagi',
          textColor: Colors.white,
          onPressed: () {
            _handleStartPlanting(
              context,
              Provider.of<PlantProvider>(context, listen: false),
              Provider.of<UserProvider>(context, listen: false),
            );
          },
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message,
      [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildUserExperience({
    required String emoji,
    required String name,
    required String review,
    required String status,
  }) {
    Color statusColor;
    switch (status) {
      case 'Success':
        statusColor = Colors.green;
        break;
      case 'Failed':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
