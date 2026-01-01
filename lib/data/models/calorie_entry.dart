/// Calorie entry data model
///
/// Represents a single food entry in the calorie tracker.
class CalorieEntry {
  final String id;
  final String userId;
  final String foodName;
  final int calories;
  final String? imageUrl;
  final DateTime timestamp;
  final String? mealType; // 'breakfast', 'lunch', 'dinner', 'snack'
  final Map<String, dynamic>? nutritionData;

  const CalorieEntry({
    required this.id,
    required this.userId,
    required this.foodName,
    required this.calories,
    this.imageUrl,
    required this.timestamp,
    this.mealType,
    this.nutritionData,
  });

  /// Create from Firestore document
  factory CalorieEntry.fromFirestore(Map<String, dynamic> data, String id) {
    return CalorieEntry(
      id: id,
      userId: data['userId'] ?? '',
      foodName: data['foodName'] ?? data['name'] ?? 'Unknown',
      calories: (data['calories'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'],
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'].toString())
          : DateTime.now(),
      mealType: data['mealType'],
      nutritionData: data['nutritionData'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'foodName': foodName,
      'calories': calories,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'mealType': mealType,
      'nutritionData': nutritionData,
    };
  }

  /// Create a copy with modified fields
  CalorieEntry copyWith({
    String? id,
    String? userId,
    String? foodName,
    int? calories,
    String? imageUrl,
    DateTime? timestamp,
    String? mealType,
    Map<String, dynamic>? nutritionData,
  }) {
    return CalorieEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      foodName: foodName ?? this.foodName,
      calories: calories ?? this.calories,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      mealType: mealType ?? this.mealType,
      nutritionData: nutritionData ?? this.nutritionData,
    );
  }

  /// Get formatted calorie string
  String get formattedCalories => '$calories kcal';

  /// Get date only (without time)
  DateTime get dateOnly => DateTime(timestamp.year, timestamp.month, timestamp.day);

  /// Check if entry is from today
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  @override
  String toString() => 'CalorieEntry(id: $id, food: $foodName, calories: $calories)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalorieEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Daily calorie summary
class DailyCalorieSummary {
  final DateTime date;
  final int totalCalories;
  final int limit;
  final List<CalorieEntry> entries;

  const DailyCalorieSummary({
    required this.date,
    required this.totalCalories,
    required this.limit,
    required this.entries,
  });

  /// Check if limit was exceeded
  bool get isOverLimit => totalCalories > limit;

  /// Get remaining calories
  int get remaining => limit - totalCalories;

  /// Get percentage of limit used
  double get percentageUsed => limit > 0 ? (totalCalories / limit) * 100 : 0;

  /// Get formatted remaining string
  String get formattedRemaining {
    if (remaining >= 0) {
      return '$remaining kcal remaining';
    }
    return '${-remaining} kcal over limit';
  }
}
