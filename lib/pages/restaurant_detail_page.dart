import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'review.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantDetailPage extends StatefulWidget {
  final String restaurantId;
  final Map<String, dynamic> data;
  final String? initialDistance;

  const RestaurantDetailPage({
    super.key,
    required this.restaurantId,
    required this.data,
    this.initialDistance,
  });

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  // ⭐️ State variables
  String? _roadDistance;
  bool _isGoogle = false; // ⭐️ Track if this is external data

  @override
  void initState() {
    super.initState();
    // ⭐️ Check source
    _isGoogle =
        widget.data['is_google'] == true ||
        widget.restaurantId.startsWith('google_');
    _getRealRoadDistance();
  }

  Future<void> _launchGoogleMaps() async {
    final location = widget.data['coordinate'] as GeoPoint?;
    if (location == null) return;

    // Use generic query for better compatibility
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}",
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Google Maps.")),
      );
    }
  }

  Future<void> _getRealRoadDistance() async {
    // Note: For Google Items, we often pass the calculated distance from the list page
    // to save API calls. If initialDistance is present, we use it.
    if (widget.initialDistance != null) {
      setState(() {
        _roadDistance = widget.initialDistance;
      });
      return;
    }
    // ... (Keep your existing Distance Matrix logic here if you want accurate driving time) ...
  }

  Future<void> _toggleFavorite(List<dynamic> favorites) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid);

    // ⭐️ NEW LOGIC: If it's a Google Place, save it to Firestore first!
    if (_isGoogle && !favorites.contains(widget.restaurantId)) {
      final docRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        await docRef.set({
          'name': widget.data['name'],
          'cuisine': widget.data['cuisine'],
          'location': widget.data['location'],
          'imageUrl': widget.data['imageUrl'],
          'rating': widget.data['rating'],
          // Convert raw data to GeoPoint if needed
          'coordinate': widget.data['coordinate'],
          'is_google': true,
          'status': 'external',
          'certificateStatus': 'Community Verified',
        });
      }
    }

    // 2. Standard Toggle Logic
    if (favorites.contains(widget.restaurantId)) {
      await userRef.update({
        'favorites': FieldValue.arrayRemove([widget.restaurantId]),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Removed from Favorites")));
    } else {
      await userRef.update({
        'favorites': FieldValue.arrayUnion([widget.restaurantId]),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Added to Favorites")));
    }
  }

  Future<void> _toggleLike(String menuId, List<dynamic> currentLikes) async {
    // Only works for Firestore items
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final menuRef = FirebaseFirestore.instance.collection('menu').doc(menuId);
    if (currentLikes.contains(currentUser.uid)) {
      await menuRef.update({
        'likes': FieldValue.arrayRemove([currentUser.uid]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await menuRef.update({
        'likes': FieldValue.arrayUnion([currentUser.uid]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ⭐️ 1. AppBar Image
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: Colors.teal,
            // ⭐️ NEW: Custom Back Button with White Circle
            leading: Padding(
              padding: const EdgeInsets.all(8.0), // Add spacing from the edge
              child: CircleAvatar(
                backgroundColor: Colors.white, // The white circle
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.black,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.data['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          color: Colors.blue.shade50,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isGoogle ? Icons.public : Icons.restaurant,
                                size: 50,
                                color: _isGoogle ? Colors.blue : Colors.grey,
                              ),
                              if (_isGoogle)
                                const Text(
                                  "Google Place",
                                  style: TextStyle(color: Colors.blue),
                                ),
                            ],
                          ),
                        ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Only allow Favorites (Updated to support Google items per previous step)
              if (currentUser != null)
                StreamBuilder<DocumentSnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final favs = snapshot.data!.data() as Map<String, dynamic>?;
                    final List<dynamic> favorites = favs?['favorites'] ?? [];
                    final bool isFavorite = favorites.contains(
                      widget.restaurantId,
                    );

                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(favorites),
                      ),
                    );
                  },
                ),
            ],
          ),

          // ⭐️ 2. Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.data['name'] ?? 'Restaurant Name',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Poppins",
                          ),
                        ),
                      ),
                      if (_isGoogle)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Google",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Text(
                    widget.data['cuisine'] ?? 'Cuisine',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ⭐️ 3. Quick Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoBadge(
                        Icons.star,
                        Colors.amber,
                        _isGoogle
                            ? "${widget.data['rating']} (${widget.data['ratingCount']})"
                            : "4.5 (Verified)",
                      ),
                      _buildInfoBadge(
                        Icons.directions_car,
                        Colors.blue,
                        _roadDistance ?? widget.initialDistance ?? "N/A",
                      ),
                      _buildInfoBadge(
                        Icons.access_time_filled,
                        Colors.green,
                        "Open",
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ⭐️ 4. Address Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildContactRow(
                          Icons.location_on,
                          widget.data['location'] ?? 'No address',
                        ),
                        if (!_isGoogle) ...[
                          const Divider(height: 24),
                          _buildContactRow(
                            Icons.phone,
                            widget.data['phone'] ?? 'No phone',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ⭐️ 5. Map Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _launchGoogleMaps,
                      icon: const Icon(Icons.map),
                      label: const Text("Get Directions"),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ⭐️ 6. MENU / GALLERY LOGIC
                  Row(
                    children: [
                      Text(
                        _isGoogle ? "Food Gallery" : "Popular Menu",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isGoogle)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.photo_library,
                            size: 18,
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ⭐️ SWITCH: Google Gallery vs Firestore Menu
                  _isGoogle
                      ? _buildGoogleGallery()
                      : _buildMenuSection(currentUser),

                  const SizedBox(height: 30),

                  // ⭐️ 7. Reviews Section (Hide for Google)
                  if (!_isGoogle) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "User Reviews",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ReviewPage(
                                        restaurantId: widget.restaurantId,
                                      ),
                                ),
                              ),
                          child: const Text("See All"),
                        ),
                      ],
                    ),
                    _buildReviewSection(),
                  ] else
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text("Read Reviews on Google Maps"),
                        onPressed: _launchGoogleMaps,
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ⭐️ 8. Google Photo Gallery Widget
  Widget _buildGoogleGallery() {
    final List<dynamic> gallery = widget.data['gallery'] ?? [];

    if (gallery.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey),
            SizedBox(width: 10),
            Text("No photos available", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: gallery.length,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(gallery[index]),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(8),
              child: const Text(
                "User Photo",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper Widgets

  // Helper Widgets
  Widget _buildInfoBadge(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
        ),
      ],
    );
  }

  // Firestore Menu List
  Widget _buildMenuSection(User? currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('menu')
              .where('restaurantId', isEqualTo: widget.restaurantId)
              .orderBy('likeCount', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Text(
            "No menu items uploaded by partner.",
            style: TextStyle(color: Colors.grey),
          );

        return ListView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final menu = doc.data() as Map<String, dynamic>;
            final List<dynamic> likes = menu['likes'] ?? [];
            final bool isLiked =
                currentUser != null && likes.contains(currentUser.uid);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    menu['imageUrl'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                  ),
                ),
                title: Text(
                  menu['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  "RM ${menu['price']?.toStringAsFixed(2) ?? 'N/A'}",
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      likes.length.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        color: isLiked ? Colors.blue : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _toggleLike(doc.id, likes),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Firestore Reviews List
  Widget _buildReviewSection() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('reviews')
              .where('restaurantId', isEqualTo: widget.restaurantId)
              .orderBy('timestamp', descending: true)
              .limit(2)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Text(
            "No reviews yet.",
            style: TextStyle(color: Colors.grey),
          );

        return Column(
          children:
              snapshot.data!.docs.map((doc) {
                final review = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            review['userName'] ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                Icons.star,
                                size: 14,
                                color:
                                    i < (review['rating'] ?? 0)
                                        ? Colors.amber
                                        : Colors.grey[300],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review['review'] ?? '',
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }
}
