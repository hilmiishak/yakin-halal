import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'restaurant_detail_page.dart';
import 'package:share_plus/share_plus.dart';

class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to see your favorites.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE3F9F4),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "FAVOURITES",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: "Poppins",
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text("Could not find user data."));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          // Ensure the favorites field exists and is a list
          final List<dynamic> favoriteIds = userData['favorites'] is List ? userData['favorites'] : [];

          // This check is crucial and correctly implemented.
          if (favoriteIds.isEmpty) {
            return const Center(
              child: Text("You haven't added any favorites yet!"),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('restaurants')
                .where(FieldPath.documentId, whereIn: favoriteIds)
                .snapshots(),
            builder: (context, restaurantSnapshot) {
              if (restaurantSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // This is the message you likely see if an ID is invalid
              if (!restaurantSnapshot.hasData || restaurantSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Your favorite restaurants could not be loaded.\nThey may have been removed."));
              }

              final favoriteRestaurants = restaurantSnapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favoriteRestaurants.length,
                itemBuilder: (context, index) {
                  final doc = favoriteRestaurants[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return FavouriteCard(
                    restaurantId: doc.id,
                    data: data,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ✅ IMPROVED FavouriteCard
class FavouriteCard extends StatelessWidget {
  final String restaurantId;
  final Map<String, dynamic> data;

  const FavouriteCard({
    super.key,
    required this.restaurantId,
    required this.data,
  });

  Future<void> _unfavorite() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    await userRef.update({
      'favorites': FieldValue.arrayRemove([restaurantId])
    });
  }

  // Helper widget to build text rows consistently
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) =>
            RestaurantDetailPage(restaurantId: restaurantId, data: data)
        ));
      },
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias, // Ensures content respects the border radius
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  data['imageUrl'] ?? '',
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white),
                  ),
                ),
                // Positioned icons with a nice background for visibility
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                          onPressed: _unfavorite,
                        ),
                  IconButton(
                    // ⭐️ Changed icon to 'share' for better UX
                    icon: const Icon(Icons.share, color: Colors.white, size: 20),
                    onPressed: () {
                      final String name = data['name'] ?? 'This Restaurant';
                      final String address = data['location'] ?? '';

                      // ⭐️ The Share Function
                      SharePlus.instance.share(ShareParams(text: "Check out $name! 📍 Located at: $address. Found on the YakinHalal app."));
                    },
                  ),
                 ],
                 ),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF93DCC9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildInfoRow("Cuisine", data['cuisine'] ?? 'N/A'),
                  _buildInfoRow("Certification", data['certificateStatus'] ?? 'N/A'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}