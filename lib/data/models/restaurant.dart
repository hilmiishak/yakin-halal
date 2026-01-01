/// Restaurant data model
///
/// Represents a restaurant with all its properties.
/// Supports both Firebase Firestore and Google Places data sources.
class Restaurant {
  final String id;
  final String name;
  final String? address;
  final String? coordinate;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? imageUrl;
  final double? rating;
  final int? userRatingsTotal;
  final String? category;
  final String? priceLevel;
  final bool? isOpenNow;
  final String? halalStatus; // 'certified', 'community_verified', 'unknown'
  final String? certificationBody;
  final bool isGooglePlace;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Restaurant({
    required this.id,
    required this.name,
    this.address,
    this.coordinate,
    this.latitude,
    this.longitude,
    this.phone,
    this.imageUrl,
    this.rating,
    this.userRatingsTotal,
    this.category,
    this.priceLevel,
    this.isOpenNow,
    this.halalStatus,
    this.certificationBody,
    this.isGooglePlace = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore document
  factory Restaurant.fromFirestore(Map<String, dynamic> data, String id) {
    // Parse coordinates
    double? lat;
    double? lng;
    final coord = data['coordinate'];
    if (coord != null && coord is String && coord.contains(',')) {
      final parts = coord.split(',');
      if (parts.length == 2) {
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      }
    }

    return Restaurant(
      id: id,
      name: data['name'] ?? 'Unknown',
      address: data['address'],
      coordinate: data['coordinate'],
      latitude: lat,
      longitude: lng,
      phone: data['phone'],
      imageUrl: data['imageUrl'] ?? data['image_url'],
      rating: (data['rating'] as num?)?.toDouble(),
      userRatingsTotal: data['user_ratings_total'] as int?,
      category: data['category'],
      priceLevel: data['price_level']?.toString(),
      isOpenNow: data['is_open_now'] as bool?,
      halalStatus: data['halal_status'] ?? 'community_verified',
      certificationBody: data['certification_body'],
      isGooglePlace: data['is_google_place'] ?? false,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
    );
  }

  /// Create from Google Places API response
  factory Restaurant.fromGooglePlaces(Map<String, dynamic> data) {
    final location = data['geometry']?['location'];
    final lat = location?['lat'] as double?;
    final lng = location?['lng'] as double?;

    return Restaurant(
      id: data['place_id'] ?? '',
      name: data['name'] ?? 'Unknown',
      address: data['vicinity'] ?? data['formatted_address'],
      coordinate: lat != null && lng != null ? '$lat, $lng' : null,
      latitude: lat,
      longitude: lng,
      imageUrl: _buildPhotoUrl(data['photos']),
      rating: (data['rating'] as num?)?.toDouble(),
      userRatingsTotal: data['user_ratings_total'] as int?,
      priceLevel: data['price_level']?.toString(),
      isOpenNow: data['opening_hours']?['open_now'] as bool?,
      halalStatus: 'unknown',
      isGooglePlace: true,
    );
  }

  static String? _buildPhotoUrl(List<dynamic>? photos) {
    if (photos == null || photos.isEmpty) return null;
    final photoRef = photos[0]['photo_reference'];
    if (photoRef == null) return null;
    // Note: API key should be added when using this URL
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=400&photo_reference=$photoRef';
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'coordinate': coordinate,
      'phone': phone,
      'imageUrl': imageUrl,
      'rating': rating,
      'user_ratings_total': userRatingsTotal,
      'category': category,
      'price_level': priceLevel,
      'is_open_now': isOpenNow,
      'halal_status': halalStatus,
      'certification_body': certificationBody,
      'is_google_place': isGooglePlace,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  Restaurant copyWith({
    String? id,
    String? name,
    String? address,
    String? coordinate,
    double? latitude,
    double? longitude,
    String? phone,
    String? imageUrl,
    double? rating,
    int? userRatingsTotal,
    String? category,
    String? priceLevel,
    bool? isOpenNow,
    String? halalStatus,
    String? certificationBody,
    bool? isGooglePlace,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      coordinate: coordinate ?? this.coordinate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      category: category ?? this.category,
      priceLevel: priceLevel ?? this.priceLevel,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      halalStatus: halalStatus ?? this.halalStatus,
      certificationBody: certificationBody ?? this.certificationBody,
      isGooglePlace: isGooglePlace ?? this.isGooglePlace,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if restaurant is halal certified
  bool get isCertified => halalStatus == 'certified';

  /// Check if restaurant is community verified
  bool get isCommunityVerified => halalStatus == 'community_verified';

  /// Get formatted rating string
  String get formattedRating => rating?.toStringAsFixed(1) ?? 'N/A';

  /// Get formatted review count
  String get formattedReviewCount {
    if (userRatingsTotal == null) return 'No reviews';
    if (userRatingsTotal! >= 1000) {
      return '${(userRatingsTotal! / 1000).toStringAsFixed(1)}k reviews';
    }
    return '$userRatingsTotal reviews';
  }

  @override
  String toString() => 'Restaurant(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Restaurant && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
