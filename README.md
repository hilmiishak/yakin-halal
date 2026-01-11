# YakinHalal (FYP Project)

**YakinHalal** is a Hybrid Intelligent Recommendation System designed to facilitate trustworthy Halal restaurant discovery. It bridges the gap between religious obligations and modern health consciousness by integrating real-time geolocation, verified Halal certification, and AI-assisted calorie tracking.

## 🚀 Key Features

### 1. Hybrid Recommendation Engine
* **Intelligent Ranking:** Prioritizes restaurants based on a weighted score of **Halal Status** (Certified > Community), **Distance**, and **User Preferences**.
* **Collaborative Filtering:** Uses a "Neighbor Cluster" algorithm to recommend restaurants liked by other users with similar taste profiles (e.g., matching User A and User B who both like "Thai Food").
* **Dual-Data Source:** Seamlessly merges live data from the **Google Places API** with a curated internal **Firebase Database** to ensure comprehensive coverage.

### 2. AI Calorie Tracker (Halalan Toyyiban)
* **Visual Food Analysis:** Integrated with **Google Gemini AI** to recognize food from photos.
* **Smart Logging:** Automatically estimates calories and nutritional info, allowing users to track their daily intake effortlessly.

### 3. Trust & Verification Ecosystem
* **Green "Certified" Badge:** Exclusive for restaurants with official Halal certificates verified manually by Admins.
* **Blue "Community Verified" Badge:** For Muslim-friendly establishments trusted by the community.
* **Partner Portal:** A dedicated web platform for restaurant owners to manage their profiles, menus, and certificate uploads.

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend:** Firebase (Firestore, Authentication, Cloud Functions)
* **AI Model:** Google Gemini API (Multimodal Vision)
* **Location Services:** Google Places API & Geolocator
* **State Management:** Provider / SetState

## 🏗️ Installation & Setup

1.  **Clone the repository**
    ```bash
    git clone [https://github.com/your-username/YakinHalal.git](https://github.com/your-username/YakinHalal.git)
    cd YakinHalal
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Environment Configuration**
    * Create a `.env` file in the root directory.
    * Add your API Keys:
        ```env
        GEMINI_API_KEY=your_gemini_api_key
        GOOGLE_MAPS_API_KEY=your_google_maps_api_key
        ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## 📱 Project Modules
* **User App:** Discovery, AI Chat, Calorie Tracking.
* **Partner Portal (Web):** Restaurant management and certificate submission.
* **Admin Panel (Web):** Application moderation, user management, and analytics.

---
*Developed by Muhammad Hilmi Bin Ishak as a Final Year Project (Bachelor of Computer Science).*
