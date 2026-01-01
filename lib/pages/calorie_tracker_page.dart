import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🎨 Custom Animated Circular Progress Painter
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    this.strokeWidth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint =
        Paint()
          ..color = progressColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ---------------- Data Models ----------------
class CalorieEntry {
  final String id;
  final String foodName;
  final int calories;
  final DateTime date;

  CalorieEntry({
    required this.id,
    required this.foodName,
    required this.calories,
    required this.date,
  });

  factory CalorieEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CalorieEntry(
      id: doc.id,
      foodName: data['foodName'] ?? 'Unknown',
      calories: data['calories'] ?? 0,
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}

// ---------------- Main Page Controller ----------------
class CalorieTrackerPage extends StatefulWidget {
  const CalorieTrackerPage({super.key});

  @override
  State<CalorieTrackerPage> createState() => _CalorieTrackerPageState();
}

class _CalorieTrackerPageState extends State<CalorieTrackerPage> {
  int _selectedIndex = 0;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  int _dailyLimit = 2000;

  @override
  void initState() {
    super.initState();
    _loadDailyLimit();
  }

  Future<void> _loadDailyLimit() async {
    if (_currentUser == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .get();
    if (doc.exists && doc.data()!.containsKey('dailyCalorieLimit')) {
      setState(() {
        _dailyLimit = doc.data()!['dailyCalorieLimit'];
      });
    }
  }

  Future<void> _updateDailyLimit(int newLimit) async {
    if (_currentUser == null) return;
    setState(() => _dailyLimit = newLimit);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .set({'dailyCalorieLimit': newLimit}, SetOptions(merge: true));
  }

  Future<void> _addEntry(String name, int cals, DateTime date) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('calorie_tracker')
          .add({
            'foodName': name,
            'calories': cals,
            'date': Timestamp.fromDate(date),
            'timestamp': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Entry Saved!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _deleteEntry(String id) async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('calorie_tracker')
        .doc(id)
        .delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Deleted.")));
  }

  Future<void> _editEntry(String id, String newName, int newCals) async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('calorie_tracker')
        .doc(id)
        .update({'foodName': newName, 'calories': newCals});
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Updated.")));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text("Please login first"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser.uid)
              .collection('calorie_tracker')
              .orderBy('date', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final List<CalorieEntry> entries =
            snapshot.data?.docs
                .map((doc) => CalorieEntry.fromFirestore(doc))
                .toList() ??
            [];
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayEntries =
            entries
                .where(
                  (e) => DateFormat('yyyy-MM-dd').format(e.date) == todayStr,
                )
                .toList();
        final int todayTotal = todayEntries.fold(
          0,
          (total, item) => total + item.calories,
        );

        final List<Widget> pages = [
          _DashboardView(
            entries: todayEntries,
            totalCalories: todayTotal,
            dailyLimit: _dailyLimit,
            onAddPressed: () => _showAddEntryModal(context),
            onSetLimitPressed: () => _showBMICalculator(context),
            onEditEntry: _editEntry,
            onDeleteEntry: _deleteEntry,
          ),
          _HistoryAnalysisView(entries: entries, dailyLimit: _dailyLimit),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Calorie Tracker",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          body: pages[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected:
                (index) => setState(() => _selectedIndex = index),
            backgroundColor: Colors.white,
            elevation: 10,
            indicatorColor: Colors.teal.shade100,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'History',
              ),
            ],
          ),
          // ⭐️ UPDATED FAB: Scan Food (Camera Icon)
          floatingActionButton:
              _selectedIndex == 0
                  ? FloatingActionButton.extended(
                    onPressed: () => _showAddEntryModal(context),
                    backgroundColor: const Color(0xFF006D69),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      "Scan Food",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                  : null,
        );
      },
    );
  }

  void _showAddEntryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEntryForm(onSubmit: _addEntry),
    );
  }

  void _showBMICalculator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BMICalculatorForm(onSave: _updateDailyLimit),
    );
  }
}

// ---------------- 1. Dashboard View (Today) ----------------
class _DashboardView extends StatelessWidget {
  final List<CalorieEntry> entries;
  final int totalCalories;
  final int dailyLimit;
  final VoidCallback onAddPressed;
  final VoidCallback onSetLimitPressed;
  final Function(String, String, int) onEditEntry;
  final Function(String) onDeleteEntry;

  const _DashboardView({
    required this.entries,
    required this.totalCalories,
    required this.dailyLimit,
    required this.onAddPressed,
    required this.onSetLimitPressed,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  // 🍔 Smart food icon based on food name
  Map<String, dynamic> _getFoodIconData(String foodName) {
    final name = foodName.toLowerCase();

    // Drinks
    if (name.contains('coffee') || name.contains('kopi')) {
      return {'icon': Icons.coffee, 'color': Colors.brown};
    }
    if (name.contains('tea') || name.contains('teh')) {
      return {'icon': Icons.emoji_food_beverage, 'color': Colors.green};
    }
    if (name.contains('juice') ||
        name.contains('jus') ||
        name.contains('drink')) {
      return {'icon': Icons.local_drink, 'color': Colors.orange};
    }
    if (name.contains('water') || name.contains('air')) {
      return {'icon': Icons.water_drop, 'color': Colors.blue};
    }

    // Rice/Main meals
    if (name.contains('rice') || name.contains('nasi')) {
      return {'icon': Icons.rice_bowl, 'color': Colors.amber};
    }
    if (name.contains('chicken') || name.contains('ayam')) {
      return {'icon': Icons.set_meal, 'color': Colors.deepOrange};
    }
    if (name.contains('fish') || name.contains('ikan')) {
      return {'icon': Icons.set_meal, 'color': Colors.cyan};
    }

    // Breakfast
    if (name.contains('egg') || name.contains('telur')) {
      return {'icon': Icons.egg, 'color': Colors.amber};
    }
    if (name.contains('bread') ||
        name.contains('roti') ||
        name.contains('toast')) {
      return {'icon': Icons.bakery_dining, 'color': Colors.brown};
    }

    // Snacks & Desserts
    if (name.contains('cake') ||
        name.contains('kek') ||
        name.contains('dessert')) {
      return {'icon': Icons.cake, 'color': Colors.pink};
    }
    if (name.contains('ice') || name.contains('ais krim')) {
      return {'icon': Icons.icecream, 'color': Colors.pink};
    }
    if (name.contains('cookie') || name.contains('biscuit')) {
      return {'icon': Icons.cookie, 'color': Colors.brown};
    }

    // Fast food
    if (name.contains('burger')) {
      return {'icon': Icons.lunch_dining, 'color': Colors.amber};
    }
    if (name.contains('pizza')) {
      return {'icon': Icons.local_pizza, 'color': Colors.red};
    }
    if (name.contains('fries') || name.contains('kentang')) {
      return {'icon': Icons.fastfood, 'color': Colors.amber};
    }

    // Noodles
    if (name.contains('noodle') ||
        name.contains('mee') ||
        name.contains('mie')) {
      return {'icon': Icons.ramen_dining, 'color': Colors.deepOrange};
    }

    // Fruits & Vegetables
    if (name.contains('salad') ||
        name.contains('vegetable') ||
        name.contains('sayur')) {
      return {'icon': Icons.eco, 'color': Colors.green};
    }
    if (name.contains('fruit') ||
        name.contains('buah') ||
        name.contains('apple') ||
        name.contains('banana')) {
      return {'icon': Icons.apple, 'color': Colors.red};
    }

    // Default
    return {'icon': Icons.restaurant, 'color': Colors.teal};
  }

  void _showEditDialog(BuildContext context, CalorieEntry entry) {
    final nameCtrl = TextEditingController(text: entry.foodName);
    final calCtrl = TextEditingController(text: entry.calories.toString());
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Edit Entry"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Food Name"),
                ),
                TextField(
                  controller: calCtrl,
                  decoration: const InputDecoration(labelText: "Calories"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  onEditEntry(
                    entry.id,
                    nameCtrl.text,
                    int.tryParse(calCtrl.text) ?? 0,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = (totalCalories / dailyLimit).clamp(0.0, 1.0);
    bool isOverLimit = totalCalories > dailyLimit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isOverLimit
                            ? [const Color(0xFFFF9A9E), const Color(0xFFFECFEF)]
                            : [
                              const Color(0xFFa18cd1),
                              const Color(0xFFfbc2eb),
                            ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Calories Consumed Today",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // 🎨 Circular Progress with Animation - Centered
                    Center(
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: progress.clamp(0.0, 1.0),
                              ),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return CustomPaint(
                                  size: const Size(150, 150),
                                  painter: _CircularProgressPainter(
                                    progress: value,
                                    progressColor:
                                        isOverLimit
                                            ? Colors.red.shade300
                                            : Colors.white,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    strokeWidth: 12,
                                  ),
                                );
                              },
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "$totalCalories",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "of $dailyLimit kcal",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Remaining calories indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOverLimit
                            ? "🔥 ${totalCalories - dailyLimit} kcal over limit!"
                            : "✨ ${dailyLimit - totalCalories} kcal remaining",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    if (isOverLimit)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Try some exercise today!",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  onPressed: onSetLimitPressed,
                  tooltip: "Set Daily Limit",
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ⭐️ NEW: Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAddPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text(
                    "AI Scan Food",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSetLimitPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.teal.shade100),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text(
                    "Calc BMI",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            "Today's Meals",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          if (entries.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = entries[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  onDismissed: (direction) => onDeleteEntry(item.id),
                  child: GestureDetector(
                    onTap: () => _showEditDialog(context, item),
                    child: Builder(
                      builder: (context) {
                        final iconData = _getFoodIconData(item.foodName);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade100,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Smart food icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (iconData['color'] as Color)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  iconData['icon'] as IconData,
                                  color: iconData['color'] as Color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.foodName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat(
                                            'h:mm a',
                                          ).format(item.date),
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Calorie badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      size: 14,
                                      color: Colors.orange.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${item.calories}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Colors.teal.shade300,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No meals tracked yet",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the button above to scan your first meal!",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 2. SMART Add Entry Form (IMPROVED UI) ----------------
class _AddEntryForm extends StatefulWidget {
  final Function(String, int, DateTime) onSubmit;
  const _AddEntryForm({required this.onSubmit});

  @override
  State<_AddEntryForm> createState() => _AddEntryFormState();
}

class _AddEntryFormState extends State<_AddEntryForm> {
  final _nameController = TextEditingController();
  final _calsController = TextEditingController();
  final DateTime _selectedDate = DateTime.now();
  File? _imageFile;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    return key ?? "";
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "AI Food Analysis",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildImageSourceCard(
                context: ctx,
                icon: Icons.camera_alt,
                title: "Take Photo",
                subtitle: "Use camera to capture your food",
                color: const Color(0xFF2196F3),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAnalyzeImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _buildImageSourceCard(
                context: ctx,
                icon: Icons.photo_library,
                title: "Choose from Gallery",
                subtitle: "Select an existing food photo",
                color: const Color(0xFF9C27B0),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAnalyzeImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _isAnalyzing = true;
      });

      if (_apiKey.isEmpty) throw "API Key missing";
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      final imageBytes = await pickedFile.readAsBytes();
      final prompt = TextPart(
        "Identify this food. Return strictly a JSON object with keys: 'food_name' (short descriptive name) and 'calories' (estimated integer). Example: {\"food_name\": \"Fried Rice\", \"calories\": 450}",
      );
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);
      final text = response.text ?? "";
      final cleanText =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      final nameMatch = RegExp(
        r'"food_name":\s*"([^"]+)"',
      ).firstMatch(cleanText);
      final calMatch = RegExp(r'"calories":\s*(\d+)').firstMatch(cleanText);

      if (nameMatch != null && calMatch != null) {
        setState(() {
          _nameController.text = nameMatch.group(1) ?? "";
          _calsController.text = calMatch.group(1) ?? "";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✨ Food analyzed successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw "Could not parse AI response.";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("AI Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _submit() {
    if (_nameController.text.isEmpty || _calsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all fields"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.onSubmit(
      _nameController.text,
      int.parse(_calsController.text),
      _selectedDate,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            "Add Food Entry",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: "Poppins",
            ),
          ),
          const SizedBox(height: 24),

          // ⭐️ HUGE SCAN CARD
          if (!_isAnalyzing && _imageFile == null) ...[
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI Smart Scan",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Take a photo to estimate calories",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "OR TYPE MANUALLY",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (_isAnalyzing)
            Container(
              height: 150,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text(
                    "Analyzing Food...",
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (_imageFile != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _imageFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageFile = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          "AI Analyzed",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          if (_imageFile != null) const SizedBox(height: 20),

          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: "Food Name",
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.restaurant_menu, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _calsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Calories (kcal)",
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Save Entry",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 3. History & Calendar View ----------------
class _HistoryAnalysisView extends StatefulWidget {
  final List<CalorieEntry> entries;
  final int dailyLimit;
  const _HistoryAnalysisView({required this.entries, required this.dailyLimit});

  @override
  State<_HistoryAnalysisView> createState() => _HistoryAnalysisViewState();
}

class _HistoryAnalysisViewState extends State<_HistoryAnalysisView> {
  int _selectedTab = 0;
  final tabs = ['Weekly', 'Monthly', 'Insights'];

  Map<String, int> get _groupedByDate {
    Map<String, int> map = {};
    for (var e in widget.entries) {
      String key = DateFormat('yyyy-MM-dd').format(e.date);
      map[key] = (map[key] ?? 0) + e.calories;
    }
    return map;
  }

  Map<String, int> get _last7Days {
    final now = DateTime.now();
    Map<String, int> map = {};
    final dailyData = _groupedByDate;
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      map[key] = dailyData[key] ?? 0;
    }
    return map;
  }

  Map<String, int> get _thisMonth {
    final now = DateTime.now();
    Map<String, int> map = {};
    final dailyData = _groupedByDate;
    for (int i = 1; i <= 31; i++) {
      try {
        final date = DateTime(now.year, now.month, i);
        if (date.month != now.month) break;
        final key = DateFormat('yyyy-MM-dd').format(date);
        map[key] = dailyData[key] ?? 0;
      } catch (e) {
        break;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final dailyTotals = _groupedByDate;
    final weeklyTotals = _last7Days;
    final monthlyTotals = _thisMonth;
    // Average calories calculation (available for future use)
    // final double avgCals = dailyTotals.values.isEmpty ? 0 : dailyTotals.values.reduce((a, b) => a + b) / dailyTotals.length;
    final int daysWithinLimit =
        dailyTotals.entries.where((e) => e.value <= widget.dailyLimit).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children:
                  tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final isSelected = _selectedTab == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.teal : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          if (_selectedTab == 0) _buildWeeklyChart(weeklyTotals),
          if (_selectedTab == 1) _buildMonthlyChart(monthlyTotals),
          if (_selectedTab == 2)
            _buildInsightsView(dailyTotals, daysWithinLimit),
          const SizedBox(height: 24),
          // History List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "History Log",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...dailyTotals.entries.map((e) {
                  final exceeded = e.value > widget.dailyLimit;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM dd').format(DateTime.parse(e.key)),
                        ),
                        Text(
                          "${e.value} kcal",
                          style: TextStyle(
                            color: exceeded ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(Map<String, int> data) {
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce(max);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "This Week",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Limit: ${widget.dailyLimit} kcal",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160, // Increased height to accommodate all elements
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children:
                  data.entries.map((e) {
                    final isToday = e.key == today;
                    final percentage = maxVal == 0 ? 0.0 : (e.value / maxVal);
                    final barHeight = max(8.0, percentage * 90); // Max bar height 90px
                    final isOver = e.value > widget.dailyLimit;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: barHeight),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, height, child) {
                        return SizedBox(
                          width: isToday ? 40 : 32,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Value label
                              if (e.value > 0)
                                Text(
                                  "${e.value}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isOver
                                            ? Colors.red
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              const SizedBox(height: 4),
                            // Bar
                            Container(
                              width: isToday ? 32 : 24,
                              height: height,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors:
                                      isOver
                                          ? [
                                            Colors.red.shade400,
                                            Colors.red.shade200,
                                          ]
                                          : [
                                            Colors.teal.shade400,
                                            Colors.teal.shade200,
                                          ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow:
                                    isToday
                                        ? [
                                          BoxShadow(
                                            color: (isOver
                                                    ? Colors.red
                                                    : Colors.teal)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Day label
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isToday ? 8 : 4,
                                vertical: isToday ? 4 : 2,
                              ),
                              decoration:
                                  isToday
                                      ? BoxDecoration(
                                        color: Colors.teal,
                                        borderRadius: BorderRadius.circular(8),
                                      )
                                      : null,
                              child: Text(
                                DateFormat(
                                  'E',
                                ).format(DateTime.parse(e.key)).substring(0, 2),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      isToday
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                  color:
                                      isToday
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        );
                      },
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(Map<String, int> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            data.entries.map((e) {
              final over = e.value > widget.dailyLimit;
              return Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: over ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    "${DateTime.parse(e.key).day}",
                    style: TextStyle(
                      fontSize: 10,
                      color: over ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildInsightsView(Map<String, int> dailyTotals, int goodDays) {
    final total = dailyTotals.length;
    final pct = total == 0 ? 0 : (goodDays / total * 100).toInt();
    final avgCalories =
        dailyTotals.isEmpty
            ? 0
            : (dailyTotals.values.reduce((a, b) => a + b) / dailyTotals.length)
                .round();
    final totalCalories =
        dailyTotals.isEmpty ? 0 : dailyTotals.values.reduce((a, b) => a + b);
    // bestDay calculation removed - unused

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Success Rate Circle
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _CircularProgressPainter(
                        progress: value,
                        progressColor:
                            pct >= 70
                                ? Colors.green
                                : pct >= 40
                                ? Colors.orange
                                : Colors.red,
                        backgroundColor: Colors.grey.shade200,
                        strokeWidth: 12,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$pct%",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Success",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  value: "$goodDays",
                  label: "Good Days",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.cancel,
                  iconColor: Colors.red,
                  value: "${total - goodDays}",
                  label: "Over Limit",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.show_chart,
                  iconColor: Colors.blue,
                  value: "$avgCalories",
                  label: "Avg kcal/day",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  value: "$totalCalories",
                  label: "Total kcal",
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Motivational Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    pct >= 70
                        ? [Colors.green.shade400, Colors.teal.shade400]
                        : pct >= 40
                        ? [Colors.orange.shade400, Colors.amber.shade400]
                        : [Colors.red.shade400, Colors.pink.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(
                  pct >= 70
                      ? "🏆"
                      : pct >= 40
                      ? "💪"
                      : "🎯",
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pct >= 70
                        ? "Amazing! You're crushing your goals!"
                        : pct >= 40
                        ? "Good effort! Keep pushing forward!"
                        : "Every day is a new chance to improve!",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ---------------- 4. BMI Calculator ----------------
class _BMICalculatorForm extends StatefulWidget {
  final Function(int) onSave;
  const _BMICalculatorForm({required this.onSave});

  @override
  State<_BMICalculatorForm> createState() => _BMICalculatorFormState();
}

class _BMICalculatorFormState extends State<_BMICalculatorForm> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = 'Male';
  int? _calculatedTDEE;
  String? _errorMessage;

  void _calculate() {
    // Clear previous error
    setState(() => _errorMessage = null);

    // Validate inputs
    if (_weightCtrl.text.trim().isEmpty ||
        _heightCtrl.text.trim().isEmpty ||
        _ageCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields");
      return;
    }

    // Parse values with error handling
    try {
      double w = double.parse(_weightCtrl.text.trim());
      double h = double.parse(_heightCtrl.text.trim());
      int a = int.parse(_ageCtrl.text.trim());

      // Validate reasonable ranges
      if (w <= 0 || w > 500) {
        setState(() => _errorMessage = "Please enter a valid weight (1-500 kg)");
        return;
      }
      if (h <= 0 || h > 300) {
        setState(() => _errorMessage = "Please enter a valid height (1-300 cm)");
        return;
      }
      if (a <= 0 || a > 150) {
        setState(() => _errorMessage = "Please enter a valid age (1-150)");
        return;
      }

      // Calculate BMR using Mifflin-St Jeor Equation
      double bmr =
          (_gender == 'Male')
              ? (10 * w) + (6.25 * h) - (5 * a) + 5
              : (10 * w) + (6.25 * h) - (5 * a) - 161;

      // TDEE with sedentary activity level (BMR * 1.2)
      setState(() => _calculatedTDEE = (bmr * 1.2).round());
    } catch (e) {
      setState(() => _errorMessage = "Please enter valid numbers only");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Set Daily Calorie Limit",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInput("Weight (kg)", _weightCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput("Height (cm)", _heightCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInput("Age", _ageCtrl)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items:
                      ['Male', 'Female']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => _gender = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Show error message if any
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          if (_calculatedTDEE != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$_calculatedTDEE kcal",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(_calculatedTDEE!);
                    Navigator.pop(context);
                  },
                  child: const Text("Use This"),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Calculate",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController c) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
