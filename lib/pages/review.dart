import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewPage extends StatefulWidget {
  final String restaurantId;
  const ReviewPage({super.key, required this.restaurantId});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  double rating = 0;
  final TextEditingController reviewController = TextEditingController();
  bool isSubmitting = false;

  // Helper to format Timestamp to readable date
  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    Duration diff = now.difference(date);

    if (diff.inDays == 0) return "Today";
    if (diff.inDays == 1) return "Yesterday";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Cleaner Light Grey Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Ratings & Reviews",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
            fontFamily: "Poppins",
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔹 Review List (Expanded)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('restaurantId', isEqualTo: widget.restaurantId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final reviews = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final data = reviews[index].data() as Map<String, dynamic>;
                    return _buildReviewCard(data);
                  },
                );
              },
            ),
          ),

          // 🔹 Add Review Section (Bottom Fixed)
          _buildInputSection(),
        ],
      ),
    );
  }

  // 🔹 Widget: Single Review Card
  Widget _buildReviewCard(Map<String, dynamic> data) {
    final String userName = data['userName'] ?? 'Anonymous';
    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : "?";
    final String? ownerReply = data['reply'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Date
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: "Poppins",
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      formatDate(data['timestamp']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              RatingBarIndicator(
                rating: (data['rating'] ?? 0).toDouble(),
                itemBuilder: (context, index) => const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                ),
                itemCount: 5,
                itemSize: 16.0,
                direction: Axis.horizontal,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Review Text
          Text(
            data['review'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
              fontFamily: "Poppins",
            ),
          ),

          // 🔹 Owner Reply Section (Polished)
          if (ownerReply != null && ownerReply.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1), // Very light teal
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 14, color: Colors.teal.shade700),
                      const SizedBox(width: 6),
                      Text(
                        "Response from Owner",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          fontFamily: "Poppins",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ownerReply,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.teal.shade900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 🔹 Widget: Input Section at Bottom
  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Write a Review",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFamily: "Poppins",
            ),
          ),
          const SizedBox(height: 10),

          // Rating Bar Input
          Center(
            child: RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star_rounded,
                color: Colors.amber,
              ),
              onRatingUpdate: (value) => setState(() => rating = value),
            ),
          ),
          const SizedBox(height: 15),

          // Text Field
          TextField(
            controller: reviewController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Share your experience...",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D69), // App Theme Color
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                "Post Review",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Widget: Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No reviews yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to share your experience!",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // 🔹 Logic: Submit Review
  Future<void> submitReview() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to review")));
      return;
    }

    if (reviewController.text.trim().isEmpty || rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add a rating and comment")));
      return;
    }

    setState(() => isSubmitting = true);

    try {
      // Fetch user name
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      String userName = "Anonymous";
      if (userDoc.exists) {
        userName = (userDoc.data() as Map<String, dynamic>)['name'] ?? 'Anonymous';
      }

      // Save to Firebase
      await FirebaseFirestore.instance.collection('reviews').add({
        'restaurantId': widget.restaurantId,
        'userId': currentUser.uid,
        'userName': userName,
        'review': reviewController.text.trim(),
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
        'reply': null, // Initialize reply as null
      });

      // Reset UI
      reviewController.clear();
      setState(() {
        rating = 0;
        isSubmitting = false;
      });

      // Close keyboard
      if (mounted) FocusScope.of(context).unfocus();

    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}