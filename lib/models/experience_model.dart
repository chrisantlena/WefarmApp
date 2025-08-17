class Experience {
  final int id;
  final int userId;
  final String plantName;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String review;
  final String author;
  final DateTime createdAt;

  Experience({
    required this.id,
    required this.userId,
    required this.plantName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.review,
    required this.author,
    required this.createdAt,
  });

  // PERBAIKAN: Sesuaikan dengan struktur response dari experience.php
  factory Experience.fromJson(Map<String, dynamic> json) {
    return Experience(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      plantName: json['plant_name'] ?? '',
      startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? '',
      review: json['experience'] ?? '', // Field 'experience' dari API
      author: json['author'] ?? 'Anonymous',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // PERBAIKAN: Fix bug di formattedEndDate (typo year)
  String get formattedStartDate =>
      '${startDate.day}/${startDate.month}/${startDate.year}';
  String get formattedEndDate =>
      '${endDate.day}/${endDate.month}/${endDate.year}'; // Fix: endDate.year bukan startDate.year
  String get formattedCreatedAt =>
      '${createdAt.day}/${createdAt.month}/${createdAt.year}';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plant_name': plantName,
      'start_date':
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      'end_date':
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'status': status,
      'experience': review,
      'author': author,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
