import 'dart:math' as math;

/// Utility class for distance calculations
class DistanceUtils {
  /// Converts degrees to radians
  static double toRadians(double degree) => degree * math.pi / 180;

  /// Calculates the Haversine distance between two geographic coordinates.
  /// Returns the distance in kilometers.
  ///
  /// [lat1], [lon1] - Latitude and longitude of the first point
  /// [lat2], [lon2] - Latitude and longitude of the second point
  static double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Return large distance for invalid coordinates
    if ((lat1 == 0 && lon1 == 0) || (lat2 == 0 && lon2 == 0)) {
      return 99999.0;
    }

    const double R = 6371; // Earth's radius in kilometers
    final double dLat = toRadians(lat2 - lat1);
    final double dLon = toRadians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRadians(lat1)) *
            math.cos(toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Formats distance for display
  /// Returns distance in km or m depending on the value
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
