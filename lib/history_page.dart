import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wefarm/experience_page.dart';
import '../models/plant_model.dart';
import '../models/plant_provider.dart';
import 'plant_detail_page.dart';
import 'custom_drawer.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    // Load data saat pertama kali dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlantProvider>(context, listen: false).loadHistoricalPlants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historicalPlants =
        Provider.of<PlantProvider>(context).historicalPlants;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
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
      endDrawer: const CustomDrawer(currentIndex: -1),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Filter Chips
            _buildFilterChips(context),
            const SizedBox(height: 8),

            // Plant List
            Expanded(
              child: historicalPlants.isEmpty
                  ? _buildEmptyHistory()
                  : ListView.builder(
                      itemCount: historicalPlants.length,
                      itemBuilder: (context, index) {
                        final plant = historicalPlants[index];
                        return _buildPlantCard(context, plant);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Consumer<PlantProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Semua'),
                selected: provider.historyFilter == null,
                onSelected: (_) => provider.setHistoryFilter(null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Berhasil'),
                selected: provider.historyFilter == 'completed',
                selectedColor: Colors.green[100],
                onSelected: (_) => provider.setHistoryFilter('completed'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Dibatalkan'),
                selected: provider.historyFilter == 'canceled',
                selectedColor: Colors.orange[100],
                onSelected: (_) => provider.setHistoryFilter('canceled'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Gagal'),
                selected: provider.historyFilter == 'failed',
                selectedColor: Colors.red[100],
                onSelected: (_) => provider.setHistoryFilter('failed'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Riwayat Tanaman',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tanaman yang sudah selesai akan muncul di sini',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(BuildContext context, Plant plant) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (plant.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Berhasil';
        break;
      case 'canceled':
        statusColor = Colors.orange;
        statusIcon = Icons.cancel;
        statusText = 'Dibatalkan';
        break;
      case 'failed':
      default:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Gagal';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlantDetailPage(
                  plant: plant.copyWith(
                status: plant.status,
              )),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      plant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Mulai: ${plant.startDate.day}/${plant.startDate.month}/${plant.startDate.year}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              if (plant.endDate != null)
                Text(
                  'Selesai: ${plant.endDate!.day}/${plant.endDate!.month}/${plant.endDate!.year}',
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: plant.progress,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFFf5bd52),
              ),
              const SizedBox(height: 4),
              Text(
                'Progress: ${(plant.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf5bd52),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ExperiencePage(initialPlant: plant),
                      ),
                    );
                  },
                  child: const Text('Bagikan Pengalaman'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
