// lib/history_helper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ----------------------- ROBUST GLOBAL HISTORY LOGGER -----------------------
Future<void> addToViewHistory(BuildContext context, String restaurantId, Map<String, dynamic> data) async {
  final user = FirebaseAuth.instance.currentUser;

  // If user not logged in, we can't save to their history
  if (user == null) return;

  // 1. Validate ID - Handle both Firebase IDs and Google Place IDs
  String finalId = restaurantId;
  if (finalId.isEmpty || finalId == "null") {
    // Priority: place_id > id > restaurant_id
    finalId = data['place_id'] ?? data['id'] ?? data['restaurant_id'] ?? '';
  }

  if (finalId.isEmpty) {
    print("❌ Error: No valid ID found for history logging: ${data['name']}");
    return;
  }

  try {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('view_history')
        .doc(finalId);

    // 2. Prepare Data
    final historyData = {
      'restaurant_id': finalId,
      'name': data['name'] ?? 'Unknown',
      'cuisine': data['cuisine'] ?? 'General',
      'distance': data['distance'] ?? '',
      'is_google': data['is_google'] ?? false,
      'imageUrl': data['imageUrl'] ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'view_count': FieldValue.increment(1),
    };

    // 3. Write Data (Set with merge)
    await ref.set(historyData, SetOptions(merge: true));

    print("✅ History Saved: ${data['name']} ($finalId)");

  } catch (e) {
    print("❌ Error updating view history: $e");
    // Only show snackbar if context is valid and mounted
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving history: $e")));
    }
  }
}