import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projekfyp/firebase_options.dart';
import 'pages/registration.dart';
import 'pages/dashboard.dart'; // 👈 your home/dashboard after login
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ⭐️ MOVE THIS LINE INSIDE HERE
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFEEEEEE),
      ),
      // 👇 Here we decide depending on auth state
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // ✅ User logged in → go to Dashboard/Home
            return const DashboardPage(); // or MyHomePage()
          } else {
            // ❌ No user → show your onboarding (AndroidCompact1)
            return const AndroidCompact1();
          }
        },
      ),
    );
  }
}

class AndroidCompact1 extends StatelessWidget {
  const AndroidCompact1({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.5;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // First circle (top-left)
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
            // Second circle
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
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: size.width * 0.65,
                    height: size.width * 0.65,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: AssetImage("assets/images/app_icon.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Get Started button
                  SizedBox(
                    width: size.width * 0.6,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF03BF8D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                            const RegistrationPage(), // 👈 go to register
                          ),
                        );
                      },
                      child: const Text(
                        "Get Started",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}