import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PartnerInfoPage extends StatelessWidget {
  const PartnerInfoPage({super.key});

  // ⚠️ REPLACE WITH YOUR ACTUAL DEPLOYED WEB URL
  final String _portalUrl = "https://yakinhalal-863b3.web.app";

  Future<void> _launchPortal() async {
    final Uri url = Uri.parse(_portalUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $_portalUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Partner with YakinHalal", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image or Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront, size: 60, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 30),

            const Text(
              "Become a Merchant",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text(
              "Join our network of trusted Halal restaurants. Manage your menu, track reviews, and reach more customers.",
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 30),

            // Warning Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.gavel, color: Colors.red),
                      SizedBox(width: 10),
                      Text("Strict Policy", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "By proceeding, you agree that all information provided is accurate. Forging Halal certificates or misleading consumers is a serious offense and will result in a permanent ban and potential legal action.",
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Desktop Advice
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.desktop_windows, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text("Note: The portal is best viewed on Desktop.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Agree Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _launchPortal,
                child: const Text("I Agree, Open Partner Portal"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}