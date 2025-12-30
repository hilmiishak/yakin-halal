const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// ⭐️ GEN 2 CLOUD FUNCTION ⭐️
exports.updateRestaurantRating = onDocumentWritten("reviews/{reviewId}", async (event) => {

    // In Gen 2, the 'change' object is located at event.data
    const change = event.data;

    // If there is no data (shouldn't happen), stop.
    if (!change) return null;

    // 1. Determine the Restaurant ID
    let restaurantId;
    // Check if the document exists after the change (Create/Update)
    if (change.after && change.after.exists) {
        restaurantId = change.after.data().restaurantId;
    }
    // If not, check if it existed before (Delete)
    else if (change.before && change.before.exists) {
        restaurantId = change.before.data().restaurantId;
    }

    if (!restaurantId) {
        console.log("No restaurant ID found in review.");
        return null;
    }

    const restaurantRef = admin.firestore().collection("restaurants").doc(restaurantId);

    // 2. "Preprocessing": Aggregate all raw reviews
    const reviewsSnapshot = await admin
      .firestore()
      .collection("reviews")
      .where("restaurantId", "==", restaurantId)
      .get();

    const ratingCount = reviewsSnapshot.size;
    let avgRating = 0.0;

    // 3. Calculate the mathematical average
    if (ratingCount > 0) {
      let totalRating = 0;
      reviewsSnapshot.forEach((doc) => {
        // Use '|| 0' to prevent errors if a rating is missing
        totalRating += (doc.data().rating || 0);
      });
      avgRating = totalRating / ratingCount;
    }

    // 4. Store the "Normalized" data back to the Restaurant
    console.log(`Updating Restaurant ${restaurantId}: Rating ${avgRating} (${ratingCount})`);

    return restaurantRef.update({
      avgRating: avgRating,
      ratingCount: ratingCount,
    });
});