class PlantTask {
  final String name;
  final bool completed;
  final DateTime? completionDate;
  final String? frequency; // 'daily', 'weekly', 'biweekly', 'as_needed'

  PlantTask({
    required this.name,
    this.completed = false,
    this.completionDate,
    this.frequency,
  });

  PlantTask copyWith({
    String? name,
    bool? completed,
    DateTime? completionDate,
    String? frequency,
  }) {
    return PlantTask(
      name: name ?? this.name,
      completed: completed ?? this.completed,
      completionDate: completionDate ?? this.completionDate,
      frequency: frequency ?? this.frequency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'completed': completed,
      'completionDate': completionDate?.toIso8601String(),
      'frequency': frequency,
    };
  }

  factory PlantTask.fromJson(Map<String, dynamic> json) {
    return PlantTask(
      name: json['name'] ?? '',
      completed: json['completed'] ?? false,
      completionDate: json['completionDate'] != null
          ? DateTime.parse(json['completionDate'])
          : null,
      frequency: json['frequency'],
    );
  }
}

class PlantTarget {
  final String period;
  final String description;

  PlantTarget({
    required this.period,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'description': description,
    };
  }

  factory PlantTarget.fromJson(Map<String, dynamic> json) {
    return PlantTarget(
      period: json['period'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class RecommendedProduct {
  final String name;
  final Map<String, String>? links;
  final String? priceRange;
  final String? link;

  RecommendedProduct({
    required this.name,
    this.links,
    this.link,
    this.priceRange,
  });

  bool get hasMultipleLinks => links != null && links!.isNotEmpty;

  // Helper method to get available platforms
  List<String> get availablePlatforms =>
      hasMultipleLinks ? links!.keys.toList() : [];

  // Helper method to get link for specific platform
  String? getLinkForPlatform(String platform) =>
      hasMultipleLinks ? links![platform.toLowerCase()] : link;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'links': links,
      'link': link,
      'price_range': priceRange,
    };
  }

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    return RecommendedProduct(
      name: json['name'] ?? '',
      links: json['links'] != null
          ? Map<String, String>.from(json['links'])
          : null,
      priceRange: json['price_range'],
    );
  }
}

class TutorialLink {
  final String title;
  final String url;

  TutorialLink({
    required this.title,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }

  factory TutorialLink.fromJson(Map<String, dynamic> json) {
    return TutorialLink(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class Plant {
  final String name;
  final String duration;
  final DateTime startDate;
  final DateTime? endDate;
  final double progress;
  final List<PlantTask> tasks;
  final String? imagePath;
  final String? status;
  final String? notes;
  final int? trackerId;
  final int? plantId;
  final Map<int, bool>? completedTargets;
  final Map<int, String?>? targetProblems;

  // New attributes from database
  final List<PlantTarget> targets;
  final List<RecommendedProduct> recommendedProducts;
  final List<TutorialLink> tutorialLinks;
  final String? guide;

  Plant({
    required this.name,
    required this.duration,
    required this.startDate,
    this.endDate,
    this.progress = 0.0,
    this.tasks = const [],
    this.imagePath,
    this.status = 'tracking',
    this.notes,
    this.trackerId,
    this.plantId,
    this.completedTargets,
    this.targetProblems,
    this.targets = const [],
    this.recommendedProducts = const [],
    this.tutorialLinks = const [],
    this.guide,
  });

  Plant copyWith({
    String? name,
    String? duration,
    DateTime? startDate,
    DateTime? endDate,
    double? progress,
    List<PlantTask>? tasks,
    String? imagePath,
    String? status,
    String? notes,
    int? trackerId,
    int? plantId,
    Map<int, bool>? completedTargets,
    Map<int, String?>? targetProblems,
    List<PlantTarget>? targets,
    List<RecommendedProduct>? recommendedProducts,
    List<TutorialLink>? tutorialLinks,
    String? guide,
  }) {
    return Plant(
      name: name ?? this.name,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      progress: progress ?? this.progress,
      tasks: tasks ?? this.tasks,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      trackerId: trackerId ?? this.trackerId,
      plantId: plantId ?? this.plantId,
      completedTargets: completedTargets ?? this.completedTargets,
      targetProblems: targetProblems ?? this.targetProblems,
      targets: targets ?? this.targets,
      recommendedProducts: recommendedProducts ?? this.recommendedProducts,
      tutorialLinks: tutorialLinks ?? this.tutorialLinks,
      guide: guide ?? this.guide,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'duration': duration,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'progress': progress,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'imagePath': imagePath,
      'status': status,
      'notes': notes,
      'trackerId': trackerId,
      'plantId': plantId,
      'completedTargets':
          completedTargets?.map((k, v) => MapEntry(k.toString(), v)),
      'targetProblems':
          targetProblems?.map((k, v) => MapEntry(k.toString(), v)),
      'targets': targets.map((target) => target.toJson()).toList(),
      'recommendedProducts':
          recommendedProducts.map((product) => product.toJson()).toList(),
      'tutorialLinks': tutorialLinks.map((link) => link.toJson()).toList(),
      'guide': guide,
    };
  }

  factory Plant.fromJson(Map<String, dynamic> json) {
    // Parse tasks
    List<PlantTask> tasksList = [];
    if (json['tasks'] != null) {
      if (json['tasks'] is List) {
        tasksList = (json['tasks'] as List)
            .map((task) => PlantTask.fromJson(task))
            .toList();
      }
    }

    // Parse targets
    List<PlantTarget> targetsList = [];
    if (json['targets'] != null) {
      if (json['targets'] is List) {
        targetsList = (json['targets'] as List)
            .map((target) => PlantTarget.fromJson(target))
            .toList();
      }
    }

    // Parse recommended products
    List<RecommendedProduct> productsList = [];
    if (json['recommended_products'] != null) {
      if (json['recommended_products'] is List) {
        productsList = (json['recommended_products'] as List)
            .map((product) => RecommendedProduct.fromJson(product))
            .toList();
      }
    }

    // Parse tutorial links
    List<TutorialLink> linksList = [];
    if (json['tutorial_links'] != null) {
      if (json['tutorial_links'] is List) {
        linksList = (json['tutorial_links'] as List)
            .map((link) => TutorialLink.fromJson(link))
            .toList();
      }
    }

    // Parse completed targets
    Map<int, bool>? completedTargetsMap;
    if (json['completedTargets'] != null) {
      completedTargetsMap = {};
      if (json['completedTargets'] is Map) {
        (json['completedTargets'] as Map).forEach((k, v) {
          completedTargetsMap![int.parse(k.toString())] = v as bool;
        });
      }
    }

    // Parse target problems
    Map<int, String?>? targetProblemsMap;
    if (json['targetProblems'] != null) {
      targetProblemsMap = {};
      if (json['targetProblems'] is Map) {
        (json['targetProblems'] as Map).forEach((k, v) {
          targetProblemsMap![int.parse(k.toString())] = v as String?;
        });
      }
    }

    return Plant(
      name: json['name'] ?? '',
      duration: json['duration'] ?? '',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      progress: (json['progress'] ?? 0.0).toDouble(),
      tasks: tasksList,
      imagePath: json['imagePath'] ?? json['image_path'],
      status: json['status'] ?? 'tracking',
      notes: json['notes'],
      trackerId: json['trackerId'] ?? json['id'],
      plantId: json['plantId'] ?? json['plant_id'],
      completedTargets: completedTargetsMap,
      targetProblems: targetProblemsMap,
      targets: targetsList,
      recommendedProducts: productsList,
      tutorialLinks: linksList,
      guide: json['guide'],
    );
  }

  List<PlantTask> generateDailyTasks() {
    if (targets.isEmpty) {
      // Fallback to default tasks if no targets defined
      return [
        PlantTask(name: "Penyiraman", frequency: "daily"),
        PlantTask(name: "Pemupukan", frequency: "weekly"),
      ];
    }

    return tasks;
  }
}
