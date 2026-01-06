import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

// Import your other pages
import 'find_restaurant.dart';
import 'recommendation_page.dart';
import 'favourite_pages.dart';
import 'profile.dart';
import 'restaurant_detail_page.dart';
import 'calorie_tracker_page.dart';
import 'google_places_service.dart';
import 'history_helper.dart'; // ⭐️ IMPORT THE HELPER
import '../utils/distance_utils.dart'; // ⭐️ IMPORT DISTANCE UTILS
import '../widgets/halal_badge.dart'; // 🏆 HALAL BADGE

// ----------------------- MAIN DASHBOARD CONTAINER -----------------------

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The 5 main pages of your app
    final List<Widget> pages = [
      HomePage(onGoToRecommend: () => _onItemTapped(2)), // Index 0
      const CalorieTrackerPage(), // Index 1
      const RecommendedPage(), // Index 2
      const FavouritesPage(), // Index 3
      const ProfilePage(), // Index 4
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF93DCC9),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department),
            label: "Tracker",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.recommend_rounded),
            label: "Recommend",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Favorites",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ----------------------- HOME PAGE (The Main Logic) -----------------------

class HomePage extends StatefulWidget {
  final VoidCallback onGoToRecommend;

  const HomePage({super.key, required this.onGoToRecommend});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = "User";
  List<String> _userPreferences = [];
  bool _loadingPrefs = true;
  Position? _currentPosition;

  // AI Chatbot Variables
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;
  List<Map<String, dynamic>> _chatResults = [];
  String _aiReply = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _getCurrentLocation();
  }

  // 1. Get User Name & Preferences
  Future<void> _fetchUserData() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        if (userDoc.exists && mounted) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            userName = userData['name'] ?? 'User';
            _userPreferences = List<String>.from(userData['preferences'] ?? []);
            _loadingPrefs = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loadingPrefs = false);
      }
    }
  }

  // 2. Get GPS Location
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
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  // 3. Distance Math Helper
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return DistanceUtils.calculateHaversineDistance(lat1, lon1, lat2, lon2);
  }

  // 4. AI Chatbot Logic (Gemini)
  Future<void> _handleChatSubmit(String userQuery) async {
    if (userQuery.isEmpty) return;
    setState(() {
      _isChatLoading = true;
      _chatResults = [];
      _aiReply = "";
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
      if (apiKey.isEmpty) throw "API Key missing";

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final prompt = '''
        User query: "$userQuery"
        Task 1: Extract the SINGLE most important food keyword (e.g., "shawarma", "burger", "nasi lemak").
        Task 2: Extract the location/area if mentioned (e.g., "bukit bintang", "KLCC", "Petaling Jaya"). If no specific location is mentioned, use "nearby".
        Task 3: Write a short, exciting 1-sentence reply that mentions the location if specified.
        
        Return strictly JSON format:
        {"keyword": "shawarma", "location": "bukit bintang", "reply": "Finding delicious shawarma spots in Bukit Bintang!"}
        
        If no location mentioned:
        {"keyword": "burger", "location": "nearby", "reply": "Searching for juicy burgers nearby!"}
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text =
          response.text
              ?.replaceAll('```json', '')
              .replaceAll('```', '')
              .trim() ??
          "{}";

      String keyword = "Food";
      String location = "nearby";
      String reply = "Searching nearby...";

      final RegExp keyReg = RegExp(r'"keyword":\s*"([^"]+)"');
      final RegExp locReg = RegExp(r'"location":\s*"([^"]+)"');
      final RegExp repReg = RegExp(r'"reply":\s*"([^"]+)"');

      final kMatch = keyReg.firstMatch(text);
      final lMatch = locReg.firstMatch(text);
      final rMatch = repReg.firstMatch(text);

      if (kMatch != null) keyword = kMatch.group(1) ?? "Food";
      if (lMatch != null) location = lMatch.group(1) ?? "nearby";
      if (rMatch != null) reply = rMatch.group(1) ?? "Searching...";

      setState(() => _aiReply = reply);

      // Determine search coordinates
      double searchLat = _currentPosition?.latitude ?? 3.1390;
      double searchLng = _currentPosition?.longitude ?? 101.6869;

      // If a specific location is mentioned, geocode it
      if (location.toLowerCase() != "nearby") {
        final coords = await _geocodeLocation(location);
        if (coords != null) {
          searchLat = coords['lat']!;
          searchLng = coords['lng']!;
        }
      }

      List<Map<String, dynamic>> allResults = [];

      // A. Internal Firebase Search
      final fbSnapshot =
          await FirebaseFirestore.instance
              .collection('restaurants')
              .where('status', isEqualTo: 'approved')
              .get();
      for (var doc in fbSnapshot.docs) {
        final data = doc.data();
        final nameMatch = data['name'].toString().toLowerCase().contains(
          keyword.toLowerCase(),
        );
        final cuisineMatch = data['cuisine'].toString().toLowerCase().contains(
          keyword.toLowerCase(),
        );
        final locationMatch =
            location.toLowerCase() == "nearby" ||
            data['location'].toString().toLowerCase().contains(
              location.toLowerCase(),
            );

        if ((nameMatch || cuisineMatch) && locationMatch) {
          double dist = 9999.0;
          final GeoPoint? coord = data['coordinate'];
          if (coord != null) {
            dist = _calculateHaversineDistance(
              searchLat,
              searchLng,
              coord.latitude,
              coord.longitude,
            );
          }
          allResults.add({
            ...data,
            'id': doc.id,
            'is_google': false,
            'distance': "${dist.toStringAsFixed(1)} km",
            'distVal': dist,
          });
        }
      }

      // B. External Google Search - include location in query if specified
      final searchQuery =
          location.toLowerCase() == "nearby" ? keyword : "$keyword $location";

      final googleRes = await GooglePlacesService().searchPlaces(
        searchQuery,
        searchLat,
        searchLng,
      );
      for (var item in googleRes) {
        final GeoPoint gp = item['coordinate'];
        double dist = _calculateHaversineDistance(
          searchLat,
          searchLng,
          gp.latitude,
          gp.longitude,
        );

        final String googleId =
            item['place_id'] ??
            DateTime.now().millisecondsSinceEpoch.toString();

        allResults.add({
          ...item,
          'id': googleId,
          'is_google': true,
          'distance': "${dist.toStringAsFixed(1)} km",
          'distVal': dist,
        });
      }

      allResults.sort(
        (a, b) => (a['distVal'] as double).compareTo(b['distVal'] as double),
      );
      setState(() {
        _chatResults = allResults.take(5).toList();
        _isChatLoading = false;
      });
    } catch (e) {
      setState(() {
        _aiReply = "I had trouble connecting. Try again!";
        _isChatLoading = false;
      });
      debugPrint("Chat Error: $e");
    }
  }

  // Geocode a location name to coordinates using Google Geocoding API
  Future<Map<String, double>?> _geocodeLocation(String locationName) async {
    try {
      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
      if (apiKey.isEmpty) return null;

      // Add "Malaysia" to improve accuracy for Malaysian locations
      final query = Uri.encodeComponent("$locationName, Malaysia");
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'lat': location['lat'].toDouble(),
            'lng': location['lng'].toDouble(),
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint("Geocoding error: $e");
      return null;
    }
  }

  // 5. The UI for "Recently Viewed" (History)
  Widget _buildRecentlyViewedList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Clear Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006D69).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Color(0xFF006D69),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Recently Viewed",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Poppins",
                      color: Color(0xFF006D69),
                    ),
                  ),
                ],
              ),
              // Clear All Button
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('view_history')
                        .limit(1)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox();
                  }
                  return GestureDetector(
                    onTap: () => _showClearHistoryDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_sweep,
                            size: 14,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Clear",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('view_history')
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF006D69)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.explore_outlined,
                          color: Colors.grey.shade400,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No restaurants viewed yet",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Start exploring halal restaurants!",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final viewCount = data['view_count'] ?? 1;
                  final isGoogle = data['is_google'] ?? false;

                  String timeAgo = "Recently";
                  final timestamp = data['timestamp'] as Timestamp?;
                  if (timestamp != null) {
                    final diff = DateTime.now().difference(timestamp.toDate());
                    if (diff.inMinutes < 1) {
                      timeAgo = "Just now";
                    } else if (diff.inMinutes < 60) {
                      timeAgo = "${diff.inMinutes}m ago";
                    } else if (diff.inHours < 24) {
                      timeAgo = "${diff.inHours}h ago";
                    } else {
                      timeAgo = "${diff.inDays}d ago";
                    }
                  }

                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.up,
                    onDismissed: (_) {
                      final currentContext = context;
                      removeFromViewHistory(currentContext, doc.id);
                    },
                    background: Container(
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.delete, color: Colors.red),
                      ),
                    ),
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () async {
                          await addToViewHistory(
                            context,
                            data['restaurant_id'],
                            data,
                          );
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => RestaurantDetailPage(
                                    restaurantId: data['restaurant_id'],
                                    data: data,
                                    initialDistance:
                                        data['distance'] ?? "Calculating...",
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors:
                                  isGoogle
                                      ? [Colors.blue.shade50, Colors.white]
                                      : [const Color(0xFFE3F9F4), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color:
                                  isGoogle
                                      ? Colors.blue.shade100
                                      : const Color(
                                        0xFF93DCC9,
                                      ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // View count badge (top right)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Source indicator
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isGoogle
                                                ? Colors.blue.shade100
                                                : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isGoogle ? "Community" : "Certified",
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isGoogle
                                                  ? Colors.blue.shade700
                                                  : Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                    if (viewCount > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "${viewCount}x",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // Restaurant Name (full, multi-line)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      data['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF006D69),
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                // Time ago (bottom)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      timeAgo,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Swipe hint
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_up, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                "Swipe up to remove",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Clear History Confirmation Dialog
  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.delete_forever, color: Colors.red.shade400),
                const SizedBox(width: 8),
                const Text("Clear History"),
              ],
            ),
            content: const Text(
              "Are you sure you want to clear all your recently viewed restaurants?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  clearAllViewHistory(context);
                },
                child: const Text("Clear All"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFE3F9F4),
        elevation: 0,
        title: Text(
          "WELCOME ${userName.toUpperCase()}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: "Poppins",
            color: Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FindRestaurant(),
                          ),
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.shade200, blurRadius: 5),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              "Find your Halal Restaurant!",
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: "Poppins",
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Icon(Icons.search, color: Colors.black, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildRecentlyViewedList(),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "RECOMMENDED FOR YOU",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Poppins",
                          color: Color(0xFF006D69),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Color(0xFF006D69),
                          size: 24,
                        ),
                        onPressed: widget.onGoToRecommend,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _loadingPrefs
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF006D69),
                        ),
                      )
                      : _buildRecommendationList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: _showChatBottomSheet,
                backgroundColor: const Color(0xFF006D69),
                icon: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
                label: const Text(
                  "Ask AI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Recommendation Stream
  Widget _buildRecommendationList() {
    Query query = FirebaseFirestore.instance
        .collection('restaurants')
        .where('status', isEqualTo: 'approved');
    if (_userPreferences.isNotEmpty) {
      query = query.where('cuisine', whereIn: _userPreferences);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(3).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No recommendations yet",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            String distanceText = "N/A";
            final GeoPoint? coord = data['coordinate'];
            if (_currentPosition != null && coord != null) {
              double dist = _calculateHaversineDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                coord.latitude,
                coord.longitude,
              );
              distanceText = "${dist.toStringAsFixed(1)} km";
            }

            final cardData = {
              ...data,
              'distance': distanceText,
              'id': doc.id,
              'is_google': false,
            };

            return RestaurantCard(restaurantId: doc.id, data: cardData);
          },
        );
      },
    );
  }

  // ⭐️ MODERN CHATBOT BOTTOM SHEET
  void _showChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F9F4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF006D69),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "AI Food Assistant",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontFamily: "Poppins",
                            color: Color(0xFF006D69),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF006D69),
                              radius: 16,
                              child: Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F7F6),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFE0ECE9),
                                  ),
                                ),
                                child: Text(
                                  _aiReply.isEmpty
                                      ? "Hello! I'm your Halal Food Assistant. 🤖\n\nTell me what you're craving (e.g., 'Spicy Nasi Lemak nearby') and I'll find the best spots for you!"
                                      : _aiReply,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_chatResults.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              "🔎 Here is what I found:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ..._chatResults.map((data) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: RestaurantCard(
                                restaurantId: data['id'],
                                data: data,
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      20 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: "Ask for food...",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: const Color(0xFFF5F7FA),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (val) async {
                              setModalState(() => _isChatLoading = true);
                              await _handleChatSubmit(val);
                              setModalState(() => _isChatLoading = false);
                              _chatController.clear();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            setModalState(() => _isChatLoading = true);
                            await _handleChatSubmit(_chatController.text);
                            setModalState(() => _isChatLoading = false);
                            _chatController.clear();
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: Color(0xFF006D69),
                              shape: BoxShape.circle,
                            ),
                            child:
                                _isChatLoading
                                    ? const Padding(
                                      padding: EdgeInsets.all(14.0),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ----------------------- HELPER WIDGETS -----------------------

class RestaurantCard extends StatelessWidget {
  final String restaurantId;
  final Map<String, dynamic> data;
  const RestaurantCard({
    super.key,
    required this.restaurantId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGoogle = data['is_google'] ?? false;

    return GestureDetector(
      onTap: () async {
        // ⭐️ IMPORTANT: Pass context here
        await addToViewHistory(context, restaurantId, data);

        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => RestaurantDetailPage(
                  restaurantId: restaurantId,
                  data: data,
                  initialDistance: data['distance'],
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
        ),
        child: Row(
          children: [
            // Image with Certified Badge overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    data['imageUrl'] ?? '',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            size: 35,
                            color: Color(0xFF006D69),
                          ),
                        ),
                  ),
                ),
                // 🏆 Certified Badge on image
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isGoogle ? Colors.blue : Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isGoogle ? Icons.people : Icons.verified,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Star Rating + Certified Badge Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF006D69),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      HalalBadge(
                        type:
                            isGoogle
                                ? HalalType.community
                                : HalalType.certified,
                        compact: true,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: Colors.amber, size: 15),
                      const SizedBox(width: 3),
                      Text(
                        (data['rating'] ?? '4.5').toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          "Distance: ${data['distance'] ?? 'N/A'}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Cuisine
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          "Cuisine: ${data['cuisine'] ?? 'N/A'}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // ⭐️ RESTORED: Price Level
                  if (data['priceLevel'] != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          "Price: ${data['priceLevel'] ?? ''}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
