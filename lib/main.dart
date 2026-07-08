import 'package:dadu_admin_panel/pages/screens/home.dart';
import 'package:dadu_admin_panel/pages/screens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadu_admin_panel/constants/constants.dart';

const Duration _sessionDuration = Duration(days: 3);

Future<bool> _isSessionValid() async {
  final prefs = await SharedPreferences.getInstance();
  final loginTimestamp = prefs.getInt('login_timestamp');

  if (loginTimestamp == null) {
    return false;
  }

  final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
  final isExpired = DateTime.now().difference(loginTime) > _sessionDuration;

  if (isExpired) {
    await FirebaseAuth.instance.signOut();
    await prefs.remove('login_timestamp');
    return false;
  }

  return true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            // User is logged in
            if (snapshot.hasData && snapshot.data != null) {
              return FutureBuilder<bool>(
                future: _isSessionValid(),
                builder: (context, sessionSnapshot) {
                  if (!sessionSnapshot.hasData) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (sessionSnapshot.data == true) {
                    return const AdminDashboard();
                  }

                  return const LoginPage();
                },
              );
            } else {
              // User is not logged in
              return const LoginPage();
            }
          }
          // Loading state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
