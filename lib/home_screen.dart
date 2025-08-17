import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wefarm/guide_page.dart';
import '../models/plant_provider.dart';
import 'tracker_page.dart';
import 'shop_page.dart';
import 'profile_page.dart';
import 'custom_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Map<String, dynamic>> displayedPlants;
  final TextEditingController _searchController = TextEditingController();
  late PlantProvider _plantProvider;
  int _currentNavIndex = 0;

  void _onNavItemTapped(int index) {
    if (index == _currentNavIndex) return;

    setState(() {
      _currentNavIndex = index;
    });

    switch (index) {
      case 1: // Tracker
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TrackerPage(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 2: // Shop
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ShopPage(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 3: // Profile
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ProfilePage(),
            transitionDuration: Duration.zero,
          ),
        );
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterPlants);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _plantProvider = Provider.of<PlantProvider>(context, listen: false);
    displayedPlants = List.from(_plantProvider.displayedPlants);
  }

  void _filterPlants() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        displayedPlants = _plantProvider.displayedPlants.where((plant) {
          return plant["name"].toString().toLowerCase().contains(query);
        }).toList();
      });
    });
  }

  Future<void> _refreshPlants() async {
    await _plantProvider.refreshPlants();
    if (mounted) {
      setState(() {
        displayedPlants = List.from(_plantProvider.displayedPlants);
      });
      _filterPlants(); // Re-apply search filter
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterPlants);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const CustomDrawer(isMainScreen: true, currentIndex: 0),
      body: Builder(
        builder: (context) {
          return Consumer<PlantProvider>(
            builder: (context, plantProvider, child) {
              return RefreshIndicator(
                onRefresh: _refreshPlants,
                child: Column(
                  children: [
                    // Header Section dengan menu button
                    Container(
                      padding: const EdgeInsets.only(
                        top: 32.0,
                        left: 32.0,
                        right: 32.0,
                        bottom: 32.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf5bd52),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20.0),
                          bottomRight: Radius.circular(20.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Menu Button dan Refresh Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Refresh Button
                              GestureDetector(
                                onTap: _refreshPlants,
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: plantProvider.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh,
                                          color: Colors.white,
                                          size: 24.0,
                                        ),
                                ),
                              ),
                              // Menu Button
                              GestureDetector(
                                onTap: () =>
                                    Scaffold.of(context).openEndDrawer(),
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 28.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            "Hi, User!",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            "Start your growing journey with us!",
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                          const SizedBox(height: 16.0),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search plants",
                              hintStyle: const TextStyle(color: Colors.black),
                              prefixIcon:
                                  const Icon(Icons.search, color: Colors.black),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Status dan Error Message
                    if (plantProvider.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                plantProvider.errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                            TextButton(
                              onPressed: _refreshPlants,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),

                    // Plant Grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: displayedPlants.isEmpty &&
                                !plantProvider.isLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_florist,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      plantProvider.errorMessage != null
                                          ? 'Failed to load plants'
                                          : 'No plants found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Pull down to refresh',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16.0,
                                mainAxisSpacing: 16.0,
                                children: displayedPlants.map((plant) {
                                  return _buildPlantCard(
                                    context,
                                    plant['name'].toString(),
                                    plant['duration'].toString(),
                                    plant['image']?.toString() ??
                                        plant['image_path']?.toString() ??
                                        '',
                                    plant['guide'].toString(),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFf5bd52),
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
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

  Widget _buildPlantCard(
    BuildContext context,
    String name,
    String duration,
    String imagePath,
    String guide,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GuidePage(
              plantName: name,
              imagePath: imagePath,
              plantGuide: guide,
            ),
          ),
        );
      },
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10.0)),
                child: Image.asset(
                  imagePath,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.image_not_supported)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    duration,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
