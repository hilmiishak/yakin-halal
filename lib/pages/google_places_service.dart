import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GooglePlacesService {
  // API key loaded from .env file (using getter to ensure dotenv is loaded)
  String get _apiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';

  // ⭐️ FIXED: Added underscore '_' to match the call below
  String _categorizeRestaurant(String restaurantName) {
    final name = restaurantName.toLowerCase();

    // 📌 Helper: quick keyword check
    bool has(List<String> words) => words.any((w) => name.contains(w));

    // 🇲🇾 MALAYSIAN
    if (has([
      'mamak',
      'nasi lemak',
      'satay',
      'roti',
      'mee',
      'curry',
      'rendang',
      'restoran',
      'warung',
      'kedai',
      'gerai',
      'dapur',
      'selera',
      'kampung',
      'maju',
      'bistro',
      'corner',
    ])) {
      return 'Malaysian Food';
    }

    // 🇮🇩 INDONESIAN
    if (has([
      'indo',
      'indonesian',
      'padang',
      'penyet',
      'bakso',
      'soto',
      'jawa',
      'sate',
    ])) {
      return 'Indo Food'; // Matches user preference
    }

    // 🇹🇭 THAI
    if (has(['thai', 'tomyam', 'tom yam', 'tom yum', 'siam', 'bangkok'])) {
      return 'Thai Food';
    }

    // 🇨🇳 CHINESE
    if (has([
      'chinese',
      'dim sum',
      'dimsum',
      'wok',
      'dragon',
      'mandarin',
      'szechuan',
      'hk',
      'hong kong',
      'char siew',
      'wantan',
      'wan tan',
    ])) {
      return 'Chinese Food';
    }

    // 🇯🇵 JAPANESE
    if (has([
      'japan',
      'japanese',
      'ramen',
      'sushi',
      'udon',
      'don',
      'bento',
      'izakaya',
    ])) {
      return 'Japanese Cuisine'; // Matches user preference
    }

    // 🇰🇷 KOREAN
    if (has([
      'korean',
      'korea',
      'kimchi',
      'kbbq',
      'bulgogi',
      'bibimbap',
      'tteokbokki',
    ])) {
      return 'Korean Cuisine'; // Matches user preference
    }

    // 🇮🇳 INDIAN
    if (has([
      'indian',
      'banana leaf',
      'masala',
      'tandoor',
      'biryani',
      'naan',
      'Punjabi',
      'curry house',
    ])) {
      return 'Indian Food';
    }

    // 🇹🇷 TURKISH / MIDDLE EASTERN
    if (has([
      'arab',
      'middle east',
      'yemen',
      'turkish',
      'kebab',
      'shawarma',
      'mandy',
      'mandi',
      'kabsa',
      'hadramawt',
      'damascus',
      'tarbush',
    ])) {
      return 'Middle Eastern'; // Matches user preference
    }

    // 🇦🇿 PAKISTANI
    if (has(['paki', 'lahore', 'karachi', 'biryani', 'chapli', 'haleem'])) {
      return 'Pakistani Food';
    }

    // 🍔 WESTERN
    if (has([
      'western',
      'bbq',
      'steak',
      'grill',
      'burger',
      'fries',
      'pasta',
      'italian',
      'pizza',
    ])) {
      return 'Western (Burgers & Pizza)'; // Matches user preference
    }

    // 🎯 FAST FOOD BRANDS
    if (has([
      'mcd',
      'donald',
      'kfc',
      'subway',
      'burger king',
      'texas',
      'a&w',
      'wendy',
      'shake shack',
    ])) {
      return 'Western (Burgers & Pizza)'; // Matches user preference (Fast Food = Western)
    }

    // ☕️ CAFES / DESSERT
    if (has([
      'coffee',
      'cafe',
      'kopi',
      'latte',
      'espresso',
      'dessert',
      'bakery',
      'bread',
      'pastry',
      'kopitiam',
    ])) {
      return 'Cafe / Bakery';
    }

    // 🌯 MEXICAN
    if (has(['mexican', 'taco', 'burrito', 'quesa', 'chipotle'])) {
      return 'Mexican Food';
    }

    // 🇮🇹 ITALIAN
    if (has(['italian', 'pasta', 'spaghetti', 'risotto'])) {
      return 'Italian Food';
    }

    // ⭐ DEFAULT (for Malaysia-focused app)
    return 'Malaysian Food';
  }

  // 🔹 Shared Fetch Function
  Future<List<Map<String, dynamic>>> _fetchFromGoogle(
    double lat,
    double lng,
    String queryText,
    double radius,
  ) async {
    if (_apiKey.isEmpty) return [];

    const String url = 'https://places.googleapis.com/v1/places:searchText';

    final Map<String, dynamic> requestBody = {
      "textQuery": queryText,
      "locationBias": {
        "circle": {
          "center": {"latitude": lat, "longitude": lng},
          "radius": radius,
        },
      },
      "maxResultCount": 10,
    };

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount,places.location,places.photos',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> places = data['places'] ?? [];

        return places.map((place) {
          // Photo Logic
          List<String> photoGallery = [];
          String mainPhotoUrl = '';
          if (place['photos'] != null && (place['photos'] as List).isNotEmpty) {
            String firstRef = place['photos'][0]['name'];
            mainPhotoUrl =
                'https://places.googleapis.com/v1/$firstRef/media?key=$_apiKey&maxHeightPx=400&maxWidthPx=400';
            for (var photo in (place['photos'] as List).take(5)) {
              String ref = photo['name'];
              photoGallery.add(
                'https://places.googleapis.com/v1/$ref/media?key=$_apiKey&maxHeightPx=400&maxWidthPx=400',
              );
            }
          }

          // ⭐️ APPLY CATEGORIZATION
          String restaurantName = place['displayName']['text'];
          // ⭐️ Use Google's Place ID for unique identifier (clean alphanumeric)
          String placeId = place['id'] ?? restaurantName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          // ⭐️ NOW THIS CALL WORKS
          String categorizedCuisine = _categorizeRestaurant(restaurantName);

          return {
            'id': 'google_$placeId',
            'name': restaurantName,
            'location': place['formattedAddress'],
            'cuisine': categorizedCuisine, // ⭐️ Now uses the smarter category
            'rating': (place['rating'] ?? 0.0).toDouble(),
            'ratingCount': (place['userRatingCount'] ?? 0).toInt(),
            'imageUrl': mainPhotoUrl,
            'gallery': photoGallery,
            'coordinate': GeoPoint(
              place['location']['latitude'],
              place['location']['longitude'],
            ),
            'is_google': true,
          };
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchNearbyHalalPlaces(
    double lat,
    double lng,
  ) async {
    return _fetchFromGoogle(lat, lng, "Halal food", 5000.0);
  }

  Future<List<Map<String, dynamic>>> searchPlaces(
    String query,
    double lat,
    double lng,
  ) async {
    return _fetchFromGoogle(lat, lng, "$query Halal", 10000.0);
  }
}
