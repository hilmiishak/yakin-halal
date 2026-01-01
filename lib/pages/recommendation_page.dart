import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'restaurant_detail_page.dart';
import 'preference.dart';
import 'google_places_service.dart';
import 'history_helper.dart'; // ⭐️ IMPORT
import '../utils/distance_utils.dart'; // ⭐️ IMPORT DISTANCE UTILS
import '../widgets/halal_badge.dart'; // 🏆 HALAL BADGE

class RecommendedPage extends StatefulWidget {
  const RecommendedPage({super.key});

  @override
  State<RecommendedPage> createState() => _RecommendedPageState();
}

class _RecommendedPageState extends State<RecommendedPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  final int _dataLimit = 10;
  List<String> _userPreferences = [];
  List<String> _userFavorites = [];

  // Google Data State (Still needed for "For You" tab!)
  List<Map<String, dynamic>> _googleRecommendations = [];
  bool _isGoogleLoading = true;

  User? _currentUser;
  Position? _currentPosition;

  Future<List<DocumentSnapshot>>? _collaborativeRecommendationsFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // ⭐️ CHANGE: 3 Tabs -> 2 Tabs
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🔹======== Location & Math Functions ========🔹
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _fetchGoogleRecommendations();
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _fetchGoogleRecommendations() async {
    if (_currentPosition == null) return;
    try {
      final results = await GooglePlacesService().fetchNearbyHalalPlaces(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (mounted) {
        setState(() {
          _googleRecommendations = results;
          _isGoogleLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Google Fetch Error: $e");
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  GeoPoint? _parseCoordinates(dynamic coordinatesData) {
    if (coordinatesData is GeoPoint) return coordinatesData;
    return null;
  }

  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return DistanceUtils.calculateHaversineDistance(lat1, lon1, lat2, lon2);
  }

  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .get();
      final data = doc.data();

      if (data != null) {
        final newPreferences = List<String>.from(data['preferences'] ?? []);
        final newFavorites = List<String>.from(data['favorites'] ?? []);

        setState(() {
          _userPreferences = newPreferences;
          _userFavorites = newFavorites;
          _collaborativeRecommendationsFuture =
              _getCollaborativeRecommendations();
          _isLoading = false;
        });
      } else {
        setState(() {
          _collaborativeRecommendationsFuture = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _collaborativeRecommendationsFuture = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _trackRestaurantView(String restaurantId) async {
    if (_currentUser == null) return;
    final restaurantRef = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId);
    await restaurantRef
        .update({'viewCount': FieldValue.increment(1)})
        .catchError((e) {});
    if (!restaurantId.startsWith('google_')) {
      final userHistoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('viewHistory')
          .doc(restaurantId);
      await userHistoryRef.set({
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<List<DocumentSnapshot>> _getCollaborativeRecommendations() async {
    if (_currentUser == null || _userPreferences.isEmpty) return [];
    
    // First try: Find users with similar preferences
    final similarUsersSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('preferences', arrayContainsAny: _userPreferences)
            .where('uid', isNotEqualTo: _currentUser!.uid)
            .limit(10)
            .get();
    
    Set<String> recommendedIds = {};
    
    if (similarUsersSnapshot.docs.isNotEmpty) {
      for (var userDoc in similarUsersSnapshot.docs) {
        List<String> favorites = List<String>.from(
          userDoc.data()['favorites'] ?? [],
        );
        recommendedIds.addAll(favorites);
      }
      recommendedIds.removeAll(_userFavorites);
    }
    
    // Fallback: If no community favorites, show popular restaurants
    if (recommendedIds.isEmpty) {
      final popularSnapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .orderBy('viewCount', descending: true)
          .limit(10)
          .get();
      return popularSnapshot.docs;
    }
    
    List<String> finalIdList = recommendedIds.toList();
    if (finalIdList.length > 30) finalIdList = finalIdList.sublist(0, 30);
    final recommendationsSnapshot =
        await FirebaseFirestore.instance
            .collection('restaurants')
            .where(FieldPath.documentId, whereIn: finalIdList)
            .get();
    return recommendationsSnapshot.docs;
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Settings",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(LucideIcons.utensils, color: Colors.teal),
                title: const Text("Edit Food Preferences"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PreferencePage(
                            userId: _currentUser!.uid,
                            isEditing: true,
                          ),
                    ),
                  ).then((_) => _loadUserData());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "RECOMMENDATION",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFamily: "Poppins",
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _loadUserData();
              _fetchGoogleRecommendations();
            },
          ),
          IconButton(
            icon: const Icon(
              LucideIcons.slidersHorizontal,
              color: Colors.black,
            ),
            onPressed: _showFilterModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: "For You"), // ⭐️ Tab 1
            Tab(
              text: "Community",
            ), // ⭐️ Tab 2 (Renamed from Popular for clarity)
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_currentUser == null) {
      return const Center(child: Text("Please log in to see recommendations."));
    }

    if (_userPreferences.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => PreferencePage(
                      userId: _currentUser!.uid,
                      isEditing: true,
                    ),
              ),
            ).then((_) => _loadUserData());
          },
          child: const Text("Set Preferences"),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // Slide 1: HYBRID Content Based (For You)
        _buildPageLayout(
          headerIcon: LucideIcons.sparkles,
          headerColor: Colors.purple.shade400,
          headerTitle: "Matched Your Taste",
          child: _buildPreferenceList(), // ⭐️ Hybrid & Deduplicated
        ),

        // Slide 2: Collaborative (Community)
        _buildPageLayout(
          headerIcon: Icons.favorite,
          headerColor: Colors.pink.shade400,
          headerTitle: "Community Favorites",
          child: _buildCollaborativeList(),
        ),
      ],
    );
  }

  Widget _buildPageLayout({
    required IconData headerIcon,
    required Color headerColor,
    required String headerTitle,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isGoogleLoading = true);
        await _loadUserData();
        await _fetchGoogleRecommendations();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  headerTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // ⭐️ 1. HYBRID LIST with SKELETON LOADING & DEDUPLICATION
  Widget _buildPreferenceList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('restaurants')
              .where('status', isEqualTo: 'approved')
              .where('cuisine', whereIn: _userPreferences)
              .limit(_dataLimit)
              .snapshots(),
      builder: (context, snapshot) {
        // Wait for BOTH Firebase AND Google to avoid jumping
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isGoogleLoading) {
          return _buildSkeletonList();
        }

        List<Map<String, dynamic>> finalDisplayList = [];
        List<Map<String, dynamic>> firebaseItems = [];

        // A. Process Firebase
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final item = {...data, 'id': doc.id, 'is_google': false};
            finalDisplayList.add(item);
            firebaseItems.add(item);
          }
        }

        // B. Process Google (Deduplicated)
        if (_googleRecommendations.isNotEmpty) {
          // Filter by User Preference
          final matchedGoogle =
              _googleRecommendations.where((item) {
                String gCuisine =
                    (item['cuisine'] ?? '').toString().toLowerCase();
                return _userPreferences.any(
                  (pref) => gCuisine == pref.toLowerCase(),
                );
              }).toList();

          for (var googleItem in matchedGoogle) {
            bool isDuplicate = false;
            // Normalize name
            String gName = (googleItem['name'] ?? "")
                .toString()
                .toLowerCase()
                .replaceAll(RegExp(r'[^\w\s]'), '');
            GeoPoint? gPoint = googleItem['coordinate'];

            // Check against every Firebase Item
            for (var fItem in firebaseItems) {
              String fName = (fItem['name'] ?? "")
                  .toString()
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^\w\s]'), '');

              if (fName.contains(gName) || gName.contains(fName)) {
                // Location Check (< 200m)
                GeoPoint? fPoint = _parseCoordinates(fItem['coordinate']);
                if (fPoint != null && gPoint != null) {
                  double distDiff = _calculateHaversineDistance(
                    fPoint.latitude,
                    fPoint.longitude,
                    gPoint.latitude,
                    gPoint.longitude,
                  );
                  if (distDiff < 0.2) {
                    isDuplicate = true;
                    break;
                  }
                }
              }
            }
            if (!isDuplicate) finalDisplayList.add(googleItem);
          }
        }

        // C. Sort
        if (_currentPosition != null) {
          finalDisplayList.sort((a, b) {
            final cA = _parseCoordinates(a['coordinate']);
            final cB = _parseCoordinates(b['coordinate']);
            if (cA == null || cB == null) return 0;
            double distA = _calculateHaversineDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              cA.latitude,
              cA.longitude,
            );
            double distB = _calculateHaversineDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              cB.latitude,
              cB.longitude,
            );
            return distA.compareTo(distB);
          });
        }

        if (finalDisplayList.isEmpty) {
          return _buildEmptyState(
            "No matches found.",
            "Try updating your preferences.",
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Column(
            key: ValueKey(finalDisplayList.length),
            children:
                finalDisplayList.map((data) {
                  final bool isGoogle = data['is_google'] == true;
                  String distText = "N/A";
                  final coordinates = _parseCoordinates(data['coordinate']);
                  if (_currentPosition != null && coordinates != null) {
                    double d = _calculateHaversineDistance(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      coordinates.latitude,
                      coordinates.longitude,
                    );
                    distText = "${d.toStringAsFixed(1)} km";
                  }

                  return _RecommendedRestaurantCard(
                    data: data,
                    distance: distText,
                    isGoogle: isGoogle,
                    onTap: () async {
                      // ⭐️ LOG HISTORY
                      await addToViewHistory(context, data['id'], data);

                      if (!context.mounted) return;
                      if (!isGoogle) _trackRestaurantView(data['id']);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => RestaurantDetailPage(
                                restaurantId: data['id'],
                                data: data,
                                initialDistance: distText,
                              ),
                        ),
                      );
                    },
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(
        5,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 110,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 16,
                      color: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 12,
                      color: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 80,
                      height: 12,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Collaborative (Unchanged)
  Widget _buildCollaborativeList() {
    if (_collaborativeRecommendationsFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<DocumentSnapshot>>(
      future: _collaborativeRecommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonList();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            "No community data yet.",
            "Be the first to favorite something!",
          );
        }
        return Column(
          children:
              snapshot.data!.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String distText = "N/A";
                final coordinates = _parseCoordinates(data['coordinate']);
                if (_currentPosition != null && coordinates != null) {
                  double d = _calculateHaversineDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    coordinates.latitude,
                    coordinates.longitude,
                  );
                  distText = "${d.toStringAsFixed(1)} km";
                }
                return _RecommendedRestaurantCard(
                  data: data,
                  distance: distText,
                  isGoogle: false,
                  onTap: () async {
                    // ⭐️ LOG HISTORY
                    await addToViewHistory(context, doc.id, data);

                    if (!context.mounted) return;
                    _trackRestaurantView(doc.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => RestaurantDetailPage(
                              restaurantId: doc.id,
                              data: data,
                              initialDistance: distText,
                            ),
                      ),
                    );
                  },
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ⭐️ Card Design
class _RecommendedRestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final String distance;
  final bool isGoogle;

  const _RecommendedRestaurantCard({
    required this.data,
    required this.onTap,
    required this.distance,
    required this.isGoogle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isGoogle ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 110,
                height: 120,
                child:
                    (isGoogle &&
                            (data['imageUrl'] == null ||
                                data['imageUrl'] == ''))
                        ? Container(
                          color: Colors.white,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.public, color: Colors.blue),
                                Text(
                                  "External",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : Image.network(
                          data['imageUrl'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.restaurant,
                                  color: Colors.black54,
                                ),
                              ),
                        ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🏆 Halal Badge - Community vs Certified
                    HalalBadge(
                      type:
                          isGoogle ? HalalType.community : HalalType.certified,
                      compact: true,
                    ),
                    const SizedBox(height: 6),

                    Text(
                      data['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['cuisine'] ?? 'External',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        Text(
                          " ${(data['rating'] ?? data['avgRating'] ?? 0.0).toStringAsFixed(1)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
