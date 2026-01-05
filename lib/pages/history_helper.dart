// lib/history_helper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ----------------------- ROBUST GLOBAL HISTORY LOGGER -----------------------
Future<void> addToViewHistory(
  BuildContext context,
  String restaurantId,
  Map<String, dynamic> data,
) async {
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
    debugPrint(
      "❌ Error: No valid ID found for history logging: ${data['name']}",
    );
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

    debugPrint("✅ History Saved: ${data['name']} ($finalId)");
  } catch (e) {
    debugPrint("❌ Error updating view history: $e");
    // Only show snackbar if context is valid and mounted
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving history: $e")));
    }
  }
}

// 🗑️ Clear all view history
Future<void> clearAllViewHistory(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('view_history');

    final snapshots = await collection.get();

    // Delete all documents in batch
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("History cleared successfully"),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error clearing history: $e")));
    }
  }
}

// 🗑️ Remove single item from history
Future<void> removeFromViewHistory(
  BuildContext context,
  String restaurantId,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('view_history')
        .doc(restaurantId)
        .delete();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error removing item: $e")));
    }
  }
}
