import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'restaurant_detail_page.dart';
import 'google_places_service.dart';
import 'dart:async';
import 'history_helper.dart'; // ⭐️ IMPORT
import '../utils/distance_utils.dart'; // ⭐️ IMPORT DISTANCE UTILS
import '../widgets/halal_badge.dart'; // 🏆 HALAL BADGE

// 🔹 Unified Helper Class
class RestaurantWithDistance {
  final Map<String, dynamic> data;
  final String id;
  final double distance;
  final bool isGoogle;
  final bool hasMenuMatch;
  final String? matchedMenuItem;

  RestaurantWithDistance({
    required this.data,
    required this.id,
    required this.distance,
    this.isGoogle = false,
    this.hasMenuMatch = false,
    this.matchedMenuItem,
  });
}

class FindRestaurant extends StatefulWidget {
  const FindRestaurant({super.key});

  @override
  State<FindRestaurant> createState() => _FindRestaurantState();
}

class _FindRestaurantState extends State<FindRestaurant> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String searchQuery = "";
  String locationQuery = "";
  Timer? _debounce;

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _locationError;
  String? _selectedCuisine;

  List<RestaurantWithDistance> _googleResults = [];
  bool _isGoogleLoading = false;

  final List<String> _cuisineOptions = [
    'Malaysian Food',
    'Indo Food',
    'Thai Food',
    'Western (Burgers & Pizza)',
    'Japanese Cuisine',
    'Korean Cuisine',
    'Chinese Cuisine',
    'Indian Cuisine',
    'Middle Eastern',
    'Vegetarian',
    'Fast Food',
    'Desserts',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // 🔹 Location Logic
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _locationError = 'Permission denied';
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Failed to get location.';
        });
      }
    }
  }

  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return DistanceUtils.calculateHaversineDistance(lat1, lon1, lat2, lon2);
  }

  // 🔹 Google Search Logic
  void _performSearch() {
    String query = _searchController.text.toLowerCase().trim();
    String loc = _locationController.text.trim();

    setState(() {
      searchQuery = query;
      locationQuery = loc;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.length >= 2 && _currentPosition != null) {
      _debounce = Timer(const Duration(milliseconds: 800), () async {
        if (mounted) setState(() => _isGoogleLoading = true);

        try {
          String finalQuery = loc.isNotEmpty ? "$query near $loc" : query;

          final results = await GooglePlacesService().searchPlaces(
            finalQuery,
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );

          if (mounted) {
            List<RestaurantWithDistance> googleList =
                results.map((item) {
                  final GeoPoint gp = item['coordinate'];
                  double dist = _calculateHaversineDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    gp.latitude,
                    gp.longitude,
                  );

                  return RestaurantWithDistance(
                    data: item,
                    id: item['id'],
                    distance: dist,
                    isGoogle: true,
                    hasMenuMatch: false,
                  );
                }).toList();

            setState(() {
              _googleResults = googleList;
              _isGoogleLoading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isGoogleLoading = false;
              _googleResults = [];
            });
          }
        }
      });
    } else {
      setState(() => _googleResults = []);
    }
  }

  // 🔹 Match Logic
  bool _hasMenuMatch(Map<String, dynamic> data, String searchQuery) {
    try {
      if (searchQuery.isEmpty) return false;
      final dynamic menuData = data['menuItems'] ?? data['menu'];
      if (menuData is List) {
        for (var item in menuData) {
          if (item.toString().toLowerCase().contains(searchQuery)) return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String? _findMatchedMenuItem(Map<String, dynamic> data, String searchQuery) {
    try {
      if (searchQuery.isEmpty) return null;
      final dynamic menuData = data['menuItems'] ?? data['menu'];
      if (menuData is List) {
        for (var item in menuData) {
          final itemStr = item.toString().toLowerCase();
          if (itemStr.contains(searchQuery)) return item.toString();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  GeoPoint? _parseCoordinates(dynamic data) {
    if (data is GeoPoint) return data;
    return null;
  }

  void _clearSearch() {
    _searchController.clear();
    _locationController.clear();
    setState(() {
      searchQuery = "";
      locationQuery = "";
      _googleResults = [];
    });
  }

  String _normalizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        title: const Text(
          "Find Restaurant",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: "Poppins",
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFE3F9F4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (searchQuery.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Inputs Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Food Search
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _performSearch(),
                    decoration: InputDecoration(
                      hintText: "What are you craving? (e.g. KFC)",
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Location Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _locationController,
                    onChanged: (val) => _performSearch(),
                    decoration: InputDecoration(
                      hintText: "Location (Empty = Nearby)",
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: Colors.orange,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Loading Indicator
          if (_isGoogleLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: LinearProgressIndicator(
                color: Colors.teal,
                backgroundColor: Colors.white,
                minHeight: 2,
              ),
            ),

          // 3. Filters
          _buildCuisineChips(),

          // 4. Main Body
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoadingLocation) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_locationError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, color: Colors.red.shade300, size: 40),
            const SizedBox(height: 10),
            Text(_locationError!),
            TextButton(
              onPressed: _getCurrentLocation,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.teal, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationQuery.isEmpty
                      ? "Showing results within 25km of you"
                      : "Searching for '$searchQuery' in '$locationQuery'",
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('restaurants')
                    .where('status', isEqualTo: 'approved')
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<RestaurantWithDistance> allItems = [];
              List<RestaurantWithDistance> firebaseItems = [];

              // A. Process Firestore
              if (_currentPosition != null && snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  bool matchesCuisine =
                      _selectedCuisine == null ||
                      (data['cuisine']?.toString().toLowerCase() ==
                          _selectedCuisine!.toLowerCase());
                  bool matchesSearch = searchQuery.isEmpty;
                  bool menuMatch = false;
                  String? matchedItem;

                  if (searchQuery.isNotEmpty) {
                    bool nameMatch =
                        data['name']?.toString().toLowerCase().contains(
                          searchQuery,
                        ) ??
                        false;
                    bool cuisineMatch =
                        data['cuisine']?.toString().toLowerCase().contains(
                          searchQuery,
                        ) ??
                        false;
                    menuMatch = _hasMenuMatch(data, searchQuery);
                    if (menuMatch) {
                      matchedItem = _findMatchedMenuItem(data, searchQuery);
                    }
                    matchesSearch = nameMatch || cuisineMatch || menuMatch;
                  }

                  if (matchesCuisine && matchesSearch) {
                    final GeoPoint? gp = _parseCoordinates(data['coordinate']);
                    double dist = 9999.0;
                    if (gp != null) {
                      dist = _calculateHaversineDistance(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        gp.latitude,
                        gp.longitude,
                      );
                    }

                    bool isLocationMatch = true;
                    if (locationQuery.isNotEmpty) {
                      String addr =
                          (data['location'] ?? "").toString().toLowerCase();
                      String restaurantName =
                          (data['name'] ?? "").toString().toLowerCase();
                      String locLower = locationQuery.toLowerCase();
                      isLocationMatch =
                          addr.contains(locLower) ||
                          restaurantName.contains(locLower);
                    } else {
                      isLocationMatch = dist <= 25.0;
                    }

                    if (isLocationMatch) {
                      final item = RestaurantWithDistance(
                        data: data,
                        id: doc.id,
                        distance: dist,
                        isGoogle: false,
                        hasMenuMatch: menuMatch,
                        matchedMenuItem: matchedItem,
                      );
                      allItems.add(item);
                      firebaseItems.add(item);
                    }
                  }
                }
              }

              // B. Process Google + Deduplication
              if (searchQuery.isNotEmpty) {
                List<RestaurantWithDistance> sourceList =
                    _selectedCuisine != null
                        ? _googleResults
                            .where(
                              (g) =>
                                  g.data['cuisine']?.toString().toLowerCase() ==
                                  _selectedCuisine!.toLowerCase(),
                            )
                            .toList()
                        : _googleResults;

                for (var googleItem in sourceList) {
                  bool isDuplicate = false;
                  String gName = _normalizeName(googleItem.data['name'] ?? "");

                  for (var fItem in firebaseItems) {
                    String fName = _normalizeName(fItem.data['name'] ?? "");

                    if (fName.contains(gName) || gName.contains(fName)) {
                      double diff =
                          (fItem.distance - googleItem.distance).abs();
                      if (diff < 0.2) {
                        isDuplicate = true;
                        break;
                      }
                    }
                  }

                  if (!isDuplicate) {
                    allItems.add(googleItem);
                  }
                }
              }

              // Sort by: 1) Name matches location query first, 2) Then by distance
              allItems.sort((a, b) {
                if (locationQuery.isNotEmpty) {
                  String locLower = locationQuery.toLowerCase();
                  String aName =
                      (a.data['name'] ?? "").toString().toLowerCase();
                  String bName =
                      (b.data['name'] ?? "").toString().toLowerCase();
                  bool aMatchesLoc = aName.contains(locLower);
                  bool bMatchesLoc = bName.contains(locLower);

                  // Prioritize name matches with location query
                  if (aMatchesLoc && !bMatchesLoc) return -1;
                  if (!aMatchesLoc && bMatchesLoc) return 1;
                }
                // Within same priority, sort by distance
                return a.distance.compareTo(b.distance);
              });
              final seenIds = <String>{};
              allItems =
                  allItems.where((item) => seenIds.add(item.id)).toList();

              if (allItems.isEmpty) {
                return const Center(
                  child: Text(
                    "No restaurants found.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  return GestureDetector(
                    onTap: () async {
                      // ⭐️ LOG HISTORY
                      await addToViewHistory(context, item.id, item.data);

                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => RestaurantDetailPage(
                                restaurantId: item.id,
                                data: item.data,
                                initialDistance:
                                    "${item.distance.toStringAsFixed(1)} km",
                              ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: RestaurantCard(
                        restaurantId: item.id,
                        name: item.data['name'] ?? 'Unknown',
                        cuisine: item.data['cuisine'] ?? 'External Source',
                        distance: "${item.distance.toStringAsFixed(1)} km",
                        halalCert:
                            item.isGoogle
                                ? "Community Verified"
                                : (item.data['certificateStatus'] ?? 'Unknown'),
                        imageUrl: item.data['imageUrl'] ?? '',
                        hasMenuMatch: item.hasMenuMatch,
                        searchQuery: searchQuery,
                        matchedMenuItem: item.matchedMenuItem,
                        isGoogle: item.isGoogle,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCuisineChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _cuisineOptions.length + 1,
        itemBuilder: (context, index) {
          String label = index == 0 ? 'All' : _cuisineOptions[index - 1];
          bool isSelected =
              (_selectedCuisine == null && label == 'All') ||
              _selectedCuisine == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected:
                  (val) => setState(
                    () => _selectedCuisine = (label == 'All' ? null : label),
                  ),
              selectedColor: Colors.teal,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          );
        },
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  final String restaurantId;
  final String name;
  final String cuisine;
  final String distance;
  final String halalCert;
  final String imageUrl;
  final bool hasMenuMatch;
  final String searchQuery;
  final String? matchedMenuItem;
  final bool isGoogle;

  const RestaurantCard({
    super.key,
    required this.restaurantId,
    required this.name,
    required this.cuisine,
    required this.distance,
    required this.halalCert,
    required this.imageUrl,
    required this.hasMenuMatch,
    required this.searchQuery,
    this.matchedMenuItem,
    this.isGoogle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isGoogle ? Colors.blue.shade50 : const Color(0xFF93DCC9),
        borderRadius: BorderRadius.circular(20),
        border:
            hasMenuMatch
                ? Border.all(color: Colors.blue.shade700, width: 2)
                : Border.all(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
            child: SizedBox(
              width: 100,
              height: 140,
              child:
                  (isGoogle && (imageUrl.isEmpty))
                      ? _buildImagePlaceholder()
                      : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                _buildImagePlaceholder(),
                      ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasMenuMatch && matchedMenuItem != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Found: $matchedMenuItem",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // 🏆 Halal Badge - Certified vs Community
                  HalalBadge(
                    type: isGoogle ? HalalType.community : HalalType.certified,
                    compact: true,
                  ),
                  const SizedBox(height: 6),

                  _buildInfoRow(
                    icon: Icons.restaurant_menu,
                    label: cuisine,
                    color:
                        isGoogle ? Colors.blue.shade800 : Colors.teal.shade800,
                  ),
                  _buildInfoRow(
                    icon: Icons.location_on,
                    label: distance,
                    color: Colors.grey[700]!,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 100,
      height: 140,
      color: isGoogle ? Colors.blue.shade100 : Colors.teal.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGoogle ? Icons.public : Icons.restaurant,
            size: 32,
            color: isGoogle ? Colors.blue.shade600 : Colors.teal.shade600,
          ),
          const SizedBox(height: 4),
          Text(
            isGoogle ? "Google\nResult" : "No\nImage",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isGoogle ? Colors.blue.shade800 : Colors.teal.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
