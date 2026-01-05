/// User data model
///
/// Represents a user profile with preferences and settings.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;
  final UserPreferences preferences;
  final CalorieSettings calorieSettings;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.preferences = const UserPreferences(),
    this.calorieSettings = const CalorieSettings(),
  });

  /// Create from Firestore document
  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'],
      displayName: data['name'] ?? data['displayName'],
      photoUrl: data['photoUrl'],
      createdAt:
          data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'].toString())
              : null,
      preferences:
          data['preferences'] != null
              ? UserPreferences.fromMap(
                data['preferences'] as Map<String, dynamic>,
              )
              : const UserPreferences(),
      calorieSettings:
          data['calorieSettings'] != null
              ? CalorieSettings.fromMap(
                data['calorieSettings'] as Map<String, dynamic>,
              )
              : const CalorieSettings(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt?.toIso8601String(),
      'preferences': preferences.toMap(),
      'calorieSettings': calorieSettings.toMap(),
    };
  }

  /// Create a copy with modified fields
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    UserPreferences? preferences,
    CalorieSettings? calorieSettings,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
      calorieSettings: calorieSettings ?? this.calorieSettings,
    );
  }

  /// Get greeting name (first name or email prefix)
  String get greetingName {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!.split(' ').first;
    }
    if (email != null && email!.contains('@')) {
      return email!.split('@').first;
    }
    return 'User';
  }

  @override
  String toString() => 'AppUser(uid: $uid, name: $displayName)';
}

/// User food preferences
class UserPreferences {
  final List<String> favoriteCuisines;
  final List<String> dietaryRestrictions;
  final bool halalCertifiedOnly;
  final double maxDistanceKm;
  final String? preferredPriceLevel;

  const UserPreferences({
    this.favoriteCuisines = const [],
    this.dietaryRestrictions = const [],
    this.halalCertifiedOnly = false,
    this.maxDistanceKm = 10.0,
    this.preferredPriceLevel,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> data) {
    return UserPreferences(
      favoriteCuisines: List<String>.from(data['favoriteCuisines'] ?? []),
      dietaryRestrictions: List<String>.from(data['dietaryRestrictions'] ?? []),
      halalCertifiedOnly: data['halalCertifiedOnly'] ?? false,
      maxDistanceKm: (data['maxDistanceKm'] as num?)?.toDouble() ?? 10.0,
      preferredPriceLevel: data['preferredPriceLevel'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'favoriteCuisines': favoriteCuisines,
      'dietaryRestrictions': dietaryRestrictions,
      'halalCertifiedOnly': halalCertifiedOnly,
      'maxDistanceKm': maxDistanceKm,
      'preferredPriceLevel': preferredPriceLevel,
    };
  }

  UserPreferences copyWith({
    List<String>? favoriteCuisines,
    List<String>? dietaryRestrictions,
    bool? halalCertifiedOnly,
    double? maxDistanceKm,
    String? preferredPriceLevel,
  }) {
    return UserPreferences(
      favoriteCuisines: favoriteCuisines ?? this.favoriteCuisines,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      halalCertifiedOnly: halalCertifiedOnly ?? this.halalCertifiedOnly,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      preferredPriceLevel: preferredPriceLevel ?? this.preferredPriceLevel,
    );
  }
}

/// Calorie tracking settings
class CalorieSettings {
  final int dailyLimit;
  final int? tdee;
  final String? goal; // 'lose', 'maintain', 'gain'
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final String? gender;
  final String? activityLevel;

  const CalorieSettings({
    this.dailyLimit = 2000,
    this.tdee,
    this.goal,
    this.age,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.activityLevel,
  });

  factory CalorieSettings.fromMap(Map<String, dynamic> data) {
    return CalorieSettings(
      dailyLimit: (data['dailyLimit'] as num?)?.toInt() ?? 2000,
      tdee: (data['tdee'] as num?)?.toInt(),
      goal: data['goal'],
      age: (data['age'] as num?)?.toInt(),
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      gender: data['gender'],
      activityLevel: data['activityLevel'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyLimit': dailyLimit,
      'tdee': tdee,
      'goal': goal,
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'gender': gender,
      'activityLevel': activityLevel,
    };
  }

  CalorieSettings copyWith({
    int? dailyLimit,
    int? tdee,
    String? goal,
    int? age,
    double? heightCm,
    double? weightKg,
    String? gender,
    String? activityLevel,
  }) {
    return CalorieSettings(
      dailyLimit: dailyLimit ?? this.dailyLimit,
      tdee: tdee ?? this.tdee,
      goal: goal ?? this.goal,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }
}
