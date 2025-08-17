import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';
import 'tracker_page.dart';
import 'profile_page.dart';
import 'custom_drawer.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _currentIndex = 2; // For bottom navigation
  int _selectedCategory = 0; // 0=All, 1=Alat, 2=Bahan

  final List<Map<String, dynamic>> products = [
    {
      'name': 'Sprayer 2 Liter',
      'category': 1,
      'image': 'assets/Bottle Spray.png',
      'price': 'Rp50.000 - Rp150.000',
      'description':
          'Alat penyemprot cairan pestisida atau pupuk dengan kapasitas 2 liter...',
    },
    {
      'name': 'Cangkul Mini',
      'category': 1,
      'image': 'assets/Cangkul.png',
      'price': 'Rp75.000 - Rp200.000',
      'description':
          'Alat penggembur tanah praktis dengan ukuran mini yang ergonomis...',
    },
    {
      'name': 'Gunting Pangkas',
      'category': 1,
      'image': 'assets/gunting pangkas.jpg',
      'price': 'Rp60.000 - Rp180.000',
      'description':
          'Gunting pangkas tanaman profesional dengan bilah stainless steel tajam...',
    },
    {
      'name': 'Selang Air 10m',
      'category': 1,
      'image': 'assets/selang.jpg',
      'price': 'Rp80.000 - Rp250.000',
      'description':
          'Selang air spiral elastis panjang 10 meter dengan diameter 1/2 inci...',
    },
    {
      'name': 'Pot Tanaman 30cm',
      'category': 1,
      'image': 'assets/Pot Tanaman.png',
      'price': 'Rp40.000 - Rp120.000',
      'description':
          'Pot plastik tebal diameter 30cm dengan sistem drainase yang baik...',
    },
    {
      'name': 'Pupuk NPK 50 Kg',
      'category': 2,
      'image': 'assets/Pupuk NPK 50 Kg.png',
      'price': 'Rp300.000 - Rp800.000',
      'description':
          'Pupuk NPK lengkap dengan kandungan Nitrogen 16%, Fosfat 16%, dan Kalium 16%...',
    },
    {
      'name': 'Pupuk Kandang',
      'category': 2,
      'image': 'assets/puppuk kandang.jpg',
      'price': 'Rp20.000 - Rp50.000',
      'description': 'Pupuk kandang kambing yang sudah matang dan steril...',
    },
    {
      'name': 'Bibit Cabai Rawit',
      'category': 2,
      'image': 'assets/Bibit Cabai rawit.png',
      'price': 'Rp10.000 - Rp25.000',
      'description':
          'Bibit cabai rawit hibrida unggul dengan produktivitas tinggi...',
    },
    {
      'name': 'Bibit Tomat Ceri',
      'category': 2,
      'image': 'assets/bibit tomat.jpg',
      'price': 'Rp15.000 - Rp30.000',
      'description':
          'Bibit tomat ceri F1 dengan rasa manis dan produktivitas tinggi...',
    },
    {
      'name': 'Pupuk Organik Cair',
      'category': 2,
      'image': 'assets/pupuk cair.jpg',
      'price': 'Rp30.000 - Rp75.000',
      'description': 'Pupuk organik cair dari bahan alami yang kaya nutrisi...',
    },
  ];

  List<Map<String, dynamic>> get filteredProducts {
    return _selectedCategory == 0
        ? List.from(products)
        : products.where((p) => p['category'] == _selectedCategory).toList();
  }

  void _onNavItemTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    final page = switch (index) {
      0 => const HomeScreen(),
      1 => const TrackerPage(),
      3 => const ProfilePage(),
      _ => null,
    };

    if (page != null) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const CustomDrawer(isMainScreen: true, currentIndex: 0),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Shop"),
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
      body: Column(
        children: [
          // Category Tabs
          _buildCategoryTabs(),

          // Product Grid
          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(
                    child: Text('Tidak ada produk yang sesuai filter'))
                : _buildProductGrid(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildCategoryTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildCategoryTab(0, 'Semua'),
            _buildCategoryTab(1, 'Alat'),
            _buildCategoryTab(2, 'Bahan'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(int index, String text) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = index),
        child: Container(
          decoration: BoxDecoration(
            color: _selectedCategory == index
                ? const Color(0xFFf5bd52)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _selectedCategory == index ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.75,
      children: filteredProducts.map(_buildProductCard).toList(),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => _showProductDetail(context, product),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  product['image'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['price'],
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onNavItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFf5bd52),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.track_changes), label: 'Tracker'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Shop'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  void _showProductDetail(BuildContext context, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  product['image'],
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image, size: 60, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              product['name'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product['price'],
              style: TextStyle(
                fontSize: 18,
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deskripsi Produk:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  product['description'],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_bag, color: Colors.white),
                    label: const Text('Shopee',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _launchURL(
                        'https://shopee.co.id/search?keyword=${Uri.encodeComponent(product['name'])}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: const Text('Tokopedia',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _launchURL(
                        'https://www.tokopedia.com/search?q=${Uri.encodeComponent(product['name'])}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka link')),
      );
    }
  }
}
