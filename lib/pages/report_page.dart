import 'dart:convert';
import 'dart:io'; // Needed for File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // ⭐️ Import Image Picker
import 'package:http/http.dart' as http; // ⭐️ Import HTTP

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  // ⚠️ CLOUDINARY CONFIG (Same as your Profile Page)
  final String _cloudinaryCloudName = "dajmimoiy";
  final String _cloudinaryUploadPreset = "Halal_Restaurant";

  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _restaurantNameController = TextEditingController(); // ⭐️ New Controller

  String _selectedIssue = 'Fake Halal Status';
  bool _isSubmitting = false;
  XFile? _selectedImage; // ⭐️ To store the picked image

  final List<String> _issues = [
    'Fake Halal Status',
    'Hygiene Issue',
    'Illegal Business',
    'Inappropriate Content',
    'Other'
  ];

  // ⭐️ 1. Function to Pick Image
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  // ⭐️ 2. Function to Upload Image to Cloudinary
  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload");
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonResponse = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        debugPrint('Upload failed: ${jsonResponse['error']['message']}');
        return null;
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  // ⭐️ 3. Updated Submit Logic
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      String? imageUrl;

      // Upload image if one is selected
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': user?.uid ?? 'anonymous',
        'userEmail': user?.email ?? 'anonymous',
        'issueType': _selectedIssue,
        'restaurantName': _restaurantNameController.text.trim(), // ⭐️ Optional field
        'description': _descController.text.trim(),
        'evidenceImageUrl': imageUrl, // ⭐️ Optional image URL
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report submitted successfully to Admin.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting report: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        title: const Text("Report a Problem", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFE3F9F4),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "We take safety seriously. Please report any illegal activities or fake Halal claims.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // --- Issue Type Dropdown ---
              const Text("Issue Type", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedIssue,
                    isExpanded: true,
                    items: _issues.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedIssue = newValue!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- ⭐️ NEW: Restaurant Name (Optional) ---
              const Text("Restaurant Name (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _restaurantNameController,
                decoration: InputDecoration(
                  hintText: "e.g. Warung Ali (Nilai)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Description ---
              const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: "Please provide details...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- ⭐️ NEW: Attach Picture (Optional) ---
              const Text("Attach Evidence (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (_selectedImage != null)
              // Show selected image preview
                Stack(
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: FileImage(File(_selectedImage!.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImage = null; // Remove image
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
              else
              // Show Upload Button
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Upload Photo", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Submit Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}