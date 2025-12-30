import 'package:flutter/material.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String cuisine;
  final String distance;
  final String rating;
  final String certification;
  final String imageUrl;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.cuisine,
    required this.distance,
    required this.rating,
    required this.certification,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.network(
              imageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Poppins",
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(cuisine,
                      style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text("Distance: $distance", style: const TextStyle(fontSize: 13)),
                  Text("Rating: $rating", style: const TextStyle(fontSize: 13)),
                  Text("Certification: $certification",
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}