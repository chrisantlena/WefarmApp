class History {
  final String id;
  final String plantId;
  final String name;
  final String duration;
  final DateTime startDate;
  final DateTime? endDate;
  final double progress;
  final String status; // 'tracking', 'completed', 'canceled', 'failed'
  final String? imagePath;
  final String? guide;
  final String? notes;

  History({
    required this.id,
    required this.plantId,
    required this.name,
    required this.duration,
    required this.startDate,
    this.endDate,
    this.progress = 0.0,
    required this.status,
    this.imagePath,
    this.guide,
    this.notes,
  });

  factory History.fromJson(Map<String, dynamic> json) {
    return History(
      id: json['id'].toString(),
      plantId: json['plant_id'].toString(),
      name: json['name'],
      duration: json['duration'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      progress: json['progress']?.toDouble() ?? 0.0,
      status: json['status'],
      imagePath: json['image_path'],
      guide: json['guide'],
      notes: json['notes'],
    );
  }

  bool get isTracking => status == 'tracking';
}