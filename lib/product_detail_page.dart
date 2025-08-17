import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_drawer.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const CustomDrawer(currentIndex: -1),
      appBar: AppBar(
        title: Text(product['name']),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(product['image'], height: 200),
            ),
            const SizedBox(height: 20),
            Text(product['name'],
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(product['price'],
                style: const TextStyle(fontSize: 20, color: Colors.green)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                Text(' ${product['rating']}'),
                const SizedBox(width: 16),
                Text(product['seller']),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Deskripsi Produk:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(product['description']),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _launchURL(
                      'https://shopee.co.id/search?keyword=${product['name']}'),
                  child: const Text('Beli di Shopee'),
                ),
                ElevatedButton(
                  onPressed: () => _launchURL(
                      'https://www.tokopedia.com/search?q=${product['name']}'),
                  child: const Text('Beli di Tokopedia'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
