import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Entry Saved!")));
    } catch (e) {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Updated.")));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null)
      return const Center(child: Text("Please login first"));

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
          (sum, item) => sum + item.calories,
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
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Calories Consumed Today",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "$totalCalories / $dailyLimit kcal",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverLimit ? Colors.red.shade700 : Colors.white,
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
                            ),
                            SizedBox(width: 8),
                            Text(
                              "You've exceeded your limit!",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.fastfood_rounded,
                              color: Colors.teal.shade700,
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
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat('h:mm a').format(item.date),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${item.calories} kcal",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
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
            Icon(Icons.no_food_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              "No food tracked yet today.",
              style: TextStyle(color: Colors.grey.shade500),
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
  DateTime _selectedDate = DateTime.now();
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✨ Food analyzed successfully!"),
              backgroundColor: Colors.green,
            ),
          );
      } else {
        throw "Could not parse AI response.";
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("AI Failed: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
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
                      color: Colors.purple.withOpacity(0.3),
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
                        color: Colors.white.withOpacity(0.2),
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
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(Map<String, int> data) {
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce(max);
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            data.entries.map((e) {
              final h = maxVal == 0 ? 0.0 : (e.value / maxVal * 100).toDouble();
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 20,
                    height: h,
                    decoration: BoxDecoration(
                      color:
                          e.value > widget.dailyLimit
                              ? Colors.red
                              : Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('E').format(DateTime.parse(e.key)),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            }).toList(),
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
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 10,
                  color: Colors.green,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              Text(
                "$pct%",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text("Success Rate"),
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

  void _calculate() {
    if (_weightCtrl.text.isEmpty ||
        _heightCtrl.text.isEmpty ||
        _ageCtrl.text.isEmpty)
      return;
    double w = double.parse(_weightCtrl.text);
    double h = double.parse(_heightCtrl.text);
    int a = int.parse(_ageCtrl.text);
    double bmr =
        (_gender == 'Male')
            ? (10 * w) + (6.25 * h) - (5 * a) + 5
            : (10 * w) + (6.25 * h) - (5 * a) - 161;
    setState(() => _calculatedTDEE = (bmr * 1.2).round());
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
                  value: _gender,
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
