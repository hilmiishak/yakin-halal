import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verification_wait_page.dart';

class PreferencePage extends StatefulWidget {
  final String userId;
  final bool isEditing; // ⭐️ 1. Add this flag

  const PreferencePage({
    super.key,
    required this.userId,
    this.isEditing = false, // ⭐️ Default is false (Registration mode)
  });

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  final List<String> preferences = [
    "Malaysian Food",
    "Japanese Cuisine",
    "Indo Food",
    "Thai Food",
    "Western (Burgers & Pizza)",
    "Korean Cuisine",
    "Middle Eastern",
    "Vegetarian",
    "Spicy",
    "Gluten-Free",
  ];

  final Set<String> selectedPrefs = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ⭐️ 2. If editing, load existing preferences first
    if (widget.isEditing) {
      _loadExistingPreferences();
    }
  }

  // ⭐️ NEW: Load existing data so the user sees what they previously picked
  Future<void> _loadExistingPreferences() async {
    setState(() => _isLoading = true);
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List<dynamic> currentPrefs = data['preferences'] ?? [];
        setState(() {
          selectedPrefs.addAll(currentPrefs.map((e) => e.toString()));
        });
      }
    } catch (e) {
      debugPrint("Error loading prefs: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    if (selectedPrefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one preference.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);

      await userRef.update({'preferences': selectedPrefs.toList()});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Preferences saved!')));

        // ⭐️ 3. NAVIGATION LOGIC (UPDATED)
        if (widget.isEditing) {
          // If Editing: Go back to App
          Navigator.pop(context);
        } else {
          // If Registration: Go to Verification Wait Page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const VerificationWaitPage(),
            ), // ⭐️ Change this
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint("Error saving preferences: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.5;

    return Scaffold(
      // ⭐️ Added AppBar for Edit Mode (easier to go back without saving)
      appBar:
          widget.isEditing
              ? AppBar(
                title: const Text(
                  "Edit Preferences",
                  style: TextStyle(color: Colors.black),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.black),
              )
              : null,
      body: SafeArea(
        child: Stack(
          children: [
            // ... Background circles (unchanged) ...
            Positioned(
              left: -circleSize * 0.6,
              top: -circleSize * 0.2,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x636ED2B7),
                ),
              ),
            ),
            Positioned(
              left: circleSize * 0.005,
              top: -circleSize * 0.6,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x636ED2B7),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Adjust spacing if AppBar is present
                  SizedBox(height: widget.isEditing ? 20 : 180),

                  Text(
                    widget.isEditing
                        ? "UPDATE YOUR TASTE"
                        : "WHAT TYPE OF FOOD YOU LIKE",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Preference chips (unchanged logic)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children:
                        preferences.map((pref) {
                          final isSelected = selectedPrefs.contains(pref);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedPrefs.remove(pref);
                                } else {
                                  selectedPrefs.add(pref);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF4DBE9C)
                                        : const Color(0xFFD9D9D9),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                pref,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF03BF8D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _isLoading ? null : _savePreferences,
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                widget.isEditing
                                    ? "Update Preferences"
                                    : "Save & Finish",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
