import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      print("Error getting location: $e");
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
      _chatResults = [];
      _aiReply = "";
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
      if (apiKey.isEmpty) throw "API Key missing";

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final prompt = '''
        User query: "$userQuery"
        Task: Extract the SINGLE most important food keyword.
        Task 2: Write a short, exciting 1-sentence reply.
        Return strictly JSON: {"keyword": "Burger", "reply": "Searching for juicy burgers nearby!"}
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text =
          response.text
              ?.replaceAll('```json', '')
              .replaceAll('```', '')
              .trim() ??
          "{}";

      String keyword = "Food";
      String reply = "Searching nearby...";
      final RegExp keyReg = RegExp(r'"keyword":\s*"([^"]+)"');
      final RegExp repReg = RegExp(r'"reply":\s*"([^"]+)"');
      final kMatch = keyReg.firstMatch(text);
      final rMatch = repReg.firstMatch(text);
      if (kMatch != null) keyword = kMatch.group(1) ?? "Food";
      if (rMatch != null) reply = rMatch.group(1) ?? "Searching...";

      setState(() => _aiReply = reply);

      List<Map<String, dynamic>> allResults = [];

      // A. Internal Firebase Search
      final fbSnapshot =
          await FirebaseFirestore.instance
              .collection('restaurants')
              .where('status', isEqualTo: 'approved')
              .get();
      for (var doc in fbSnapshot.docs) {
        final data = doc.data();
        if (data['name'].toString().toLowerCase().contains(
              keyword.toLowerCase(),
            ) ||
            data['cuisine'].toString().toLowerCase().contains(
              keyword.toLowerCase(),
            )) {
          double dist = 9999.0;
          final GeoPoint? coord = data['coordinate'];
          if (_currentPosition != null && coord != null) {
            dist = _calculateHaversineDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
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

      // B. External Google Search
      if (_currentPosition != null) {
        final googleRes = await GooglePlacesService().searchPlaces(
          keyword,
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        for (var item in googleRes) {
          final GeoPoint gp = item['coordinate'];
          double dist = _calculateHaversineDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
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
      }

      allResults.sort(
        (a, b) => (a['distVal'] as double).compareTo(b['distVal'] as double),
      );
      setState(() => _chatResults = allResults.take(5).toList());
    } catch (e) {
      setState(() => _aiReply = "I had trouble connecting. Try again!");
      print("Chat Error: $e");
    }
  }

  // 5. The UI for "Recently Viewed" (History)
  Widget _buildRecentlyViewedList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.history, color: Color(0xFF006D69), size: 20),
              SizedBox(width: 8),
              Text(
                "RECENTLY VIEWED",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Poppins",
                  color: Color(0xFF006D69),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('view_history')
                    .orderBy('timestamp', descending: true)
                    .limit(5)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF006D69)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.shade200, blurRadius: 5),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.grey.shade400,
                            size: 25,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "No recent views",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
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

                  String timeAgo = "Recently";
                  final timestamp = data['timestamp'] as Timestamp?;
                  if (timestamp != null) {
                    final diff = DateTime.now().difference(timestamp.toDate());
                    if (diff.inMinutes < 1)
                      timeAgo = "Just now";
                    else if (diff.inMinutes < 60)
                      timeAgo = "${diff.inMinutes}m ago";
                    else if (diff.inHours < 24)
                      timeAgo = "${diff.inHours}h ago";
                    else
                      timeAgo = "${diff.inDays}d ago";
                  }

                  return Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () async {
                        await addToViewHistory(
                          context,
                          data['restaurant_id'],
                          data,
                        );
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 6,
                              offset: const Offset(1, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F9F4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.restaurant,
                                  color: Color(0xFF006D69),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      data['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            timeAgo,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (viewCount > 1)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF93DCC9),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                "$viewCount×",
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            "Tap to revisit restaurants you've viewed",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
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
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF006D69),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Your Activity",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Poppins",
                          color: Color(0xFF006D69),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
    if (_userPreferences.isNotEmpty)
      query = query.where('cuisine', whereIn: _userPreferences);

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
                          }).toList(),
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
                          color: Colors.black.withOpacity(0.05),
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
    return GestureDetector(
      onTap: () async {
        // ⭐️ IMPORTANT: Pass context here
        await addToViewHistory(context, restaurantId, data);

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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                data['imageUrl'] ?? '',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const Icon(
                      Icons.restaurant,
                      size: 35,
                      color: Color(0xFF006D69),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ⭐️ RESTORED: Name + Star Rating Row
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
