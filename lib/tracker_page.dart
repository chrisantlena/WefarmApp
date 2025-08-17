import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'shop_page.dart';
import 'profile_page.dart';
import 'package:wefarm/models/plant_model.dart';
import 'package:wefarm/models/plant_provider.dart';
import 'package:wefarm/plant_detail_page.dart';
import 'guide_page.dart';
import 'custom_drawer.dart';

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  int _currentIndex = 1; // Index untuk Tracker

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      plantProvider.loadTrackedPlants();
    });
  }

  void _onNavItemTapped(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0: // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 2: // Shop
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ShopPage()),
        );
        break;
      case 3: // Profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
    }
  }

  // Method untuk refresh data
  Future<void> _refreshData() async {
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    await plantProvider.loadTrackedPlants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const CustomDrawer(isMainScreen: true, currentIndex: 0),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Tracker"),
        actions: [
          // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
        backgroundColor: const Color(0xFFf5bd52),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Add Plant Button
              _buildAddPlantButton(context),
              const SizedBox(height: 20),

              // Plant List
              Expanded(
                child: Consumer<PlantProvider>(
                  builder: (context, plantProvider, child) {
                    if (plantProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (plantProvider.trackedPlants.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.eco,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Belum ada tanaman yang dilacak",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Mulai lacak tanaman pertama Anda!",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: plantProvider.trackedPlants.length,
                      itemBuilder: (context, index) {
                        final plant = plantProvider.trackedPlants[index];
                        return _buildPlantCard(context, plant);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFf5bd52),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.track_changes), label: 'Tracker'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildAddPlantButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFf5bd52)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFf5bd52).withOpacity(0.1),
      ),
      child: InkWell(
        onTap: () => _showAddPlantDialog(context),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFFf5bd52)),
            SizedBox(width: 12),
            Text(
              "Tambah Tanaman",
              style: TextStyle(
                color: Color(0xFFf5bd52),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

// REPLACE ENTIRE _showAddPlantDialog method di TrackerPage

  void _showAddPlantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pilih Tanaman"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Consumer<PlantProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              // ✅ LANGSUNG PAKAI allPlants (sama seperti HomeScreen)
              if (provider.allPlants.isEmpty) {
                return const Center(child: Text("Tidak ada tanaman tersedia"));
              }

              return ListView.builder(
                itemCount: provider.allPlants.length,
                itemBuilder: (context, index) {
                  final plantData = provider.allPlants[index];

                  final plantName =
                      plantData["name"]?.toString() ?? "Unknown Plant";
                  final plantDuration =
                      plantData["duration"]?.toString() ?? "Unknown Duration";
                  final plantImagePath = plantData["image_path"]?.toString() ??
                      plantData["image"]?.toString() ??
                      'assets/default_plant.png';

                  return ListTile(
                    leading: plantImagePath.isNotEmpty
                        ? Image.asset(
                            plantImagePath,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.eco);
                            },
                          )
                        : const Icon(Icons.eco),
                    title: Text(plantName),
                    subtitle: Text(plantDuration),
                    onTap: () {
                      Navigator.pop(context);
                      // ✅ LANGSUNG PASS DATA, GA USAH CARI LAGI
                      _navigateToGuidePage(context, plantData);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
        ],
      ),
    );
  }

// ✅ REPLACE ENTIRE _navigateToGuidePage method
  void _navigateToGuidePage(
      BuildContext context, Map<String, dynamic> plantData) async {
    // ✅ LANGSUNG EXTRACT DATA YANG SUDAH ADA
    final plantName = plantData["name"]?.toString() ?? "Unknown Plant";
    final plantImagePath = plantData["image_path"]?.toString() ??
        plantData["image"]?.toString() ??
        'assets/default_plant.png';
    final plantGuide =
        plantData["guide"]?.toString() ?? "Panduan tidak tersedia";

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuidePage(
          plantName: plantName,
          imagePath: plantImagePath,
          plantGuide: plantGuide,
        ),
      ),
    );

    if (result == true) {
      await _refreshData();
    }
  }

  void _navigateToDetail(Plant plant) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailPage(plant: plant),
      ),
    );

    // Refresh data jika ada perubahan
    if (result == true) {
      await _refreshData();
    }
  }

  Widget _buildPlantCard(BuildContext context, Plant plant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        leading: plant.imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  plant.imagePath!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.eco, color: Colors.grey),
                    );
                  },
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.eco, color: Colors.grey),
              ),
        title: Text(
          plant.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mulai: ${_formatDate(plant.startDate)}'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: plant.progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFFf5bd52),
            ),
            const SizedBox(height: 4),
            Text('${(plant.progress * 100).round()}%'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _navigateToDetail(plant),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
