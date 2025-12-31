import 'package:flutter/material.dart';

/// 🏆 Halal Badge Widget
/// Used to distinguish between:
/// - Certified Halal (Firebase data with official certificates)
/// - Community Verified (Google API data verified by users)

enum HalalType {
  certified, // Firebase - Official halal certificate
  community, // Google API - Community verified
}

class HalalBadge extends StatelessWidget {
  final HalalType type;
  final bool compact;

  const HalalBadge({super.key, required this.type, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactBadge();
    }
    return _buildFullBadge();
  }

  Widget _buildCompactBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color:
            type == HalalType.certified
                ? Colors.green.shade50
                : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              type == HalalType.certified
                  ? Colors.green.shade300
                  : Colors.blue.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == HalalType.certified ? Icons.verified : Icons.people,
            size: 12,
            color:
                type == HalalType.certified
                    ? Colors.green.shade700
                    : Colors.blue.shade700,
          ),
          const SizedBox(width: 3),
          Text(
            type == HalalType.certified ? "Certified" : "Community Verified",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color:
                  type == HalalType.certified
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              type == HalalType.certified
                  ? [Colors.green.shade400, Colors.teal.shade400]
                  : [Colors.blue.shade400, Colors.indigo.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (type == HalalType.certified ? Colors.green : Colors.blue)
                .withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == HalalType.certified ? Icons.verified : Icons.people,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            type == HalalType.certified
                ? "Certified Halal"
                : "Community Verified",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🛡️ Trust Shield Widget
/// Shows the trust level with visual indicator
class TrustShield extends StatelessWidget {
  final HalalType type;
  final int? communityVotes; // Only for community type

  const TrustShield({super.key, required this.type, this.communityVotes});

  String get _trustLabel {
    if (type == HalalType.certified) {
      return "100% Verified";
    }
    if (communityVotes == null) return "Community";
    if (communityVotes! >= 50) return "High Trust";
    if (communityVotes! >= 10) return "Moderate";
    return "New";
  }

  Color get _trustColor {
    if (type == HalalType.certified) return Colors.green;
    if (communityVotes == null) return Colors.blue;
    if (communityVotes! >= 50) return Colors.green;
    if (communityVotes! >= 10) return Colors.orange;
    return Colors.grey;
  }

  IconData get _trustIcon {
    if (type == HalalType.certified) return Icons.shield;
    if (communityVotes == null) return Icons.people;
    if (communityVotes! >= 50) return Icons.star;
    if (communityVotes! >= 10) return Icons.thumb_up;
    return Icons.new_releases;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _trustColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_trustIcon, size: 14, color: _trustColor),
        ),
        const SizedBox(width: 4),
        Text(
          _trustLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _trustColor,
          ),
        ),
      ],
    );
  }
}

/// 🎨 Source Indicator Chip
/// A simple chip showing where the data comes from
class SourceChip extends StatelessWidget {
  final bool isGoogle;

  const SourceChip({super.key, required this.isGoogle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGoogle ? Colors.blue : Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGoogle ? Icons.public : Icons.verified,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isGoogle ? "Community" : "Certified",
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
