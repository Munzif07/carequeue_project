// ============================================================
//  CareQueue — main.dart (FINAL COMPLETE VERSION)
//  All routes registered + Google Fonts + Theme
//  File: lib/main.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/splash_screen.dart';
import 'screens/patient/patient_auth_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/patient/patient_live_queue_screen.dart';
import 'screens/patient/patient_profile_screen.dart';
import 'screens/doctor/doctor_auth_screen.dart';
import 'screens/doctor/doctor_dashboard_screen.dart';
import 'utils/lang.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Lang.load(); // Load saved language from device
  runApp(const CareQueueApp());
}

class CareQueueApp extends StatelessWidget {
  const CareQueueApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder — app rebuilds when language changes
    return ValueListenableBuilder<AppLang>(
      valueListenable: langNotifier,
      builder: (_, __, ___) => MaterialApp(
        title: 'CareQueue',
        debugShowCheckedModeBanner: false,

        // ── Theme ──────────────────────────────────────────
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1a6b5a),
            primary:   const Color(0xFF1a6b5a),
            secondary: const Color(0xFFff6b35),
            background: const Color(0xFFf0f7f5),
          ),
          textTheme: GoogleFonts.nunitoTextTheme(
            Theme.of(context).textTheme,
          ),
          scaffoldBackgroundColor: const Color(0xFFf0f7f5),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1a2e2a),
            elevation: 0,
          ),
        ),

        // ── Routes ─────────────────────────────────────────
        initialRoute: '/',
        routes: {
          '/':                (ctx) => const SplashScreen(),
          '/patient-auth':    (ctx) => const PatientAuthScreen(),
          '/patient-home':    (ctx) => const PatientHomeScreen(),
          '/patient-live':    (ctx) => const PatientLiveQueueScreen(),
          '/patient-profile': (ctx) => const PatientProfileScreen(),
          '/doctor-auth':     (ctx) => const DoctorAuthScreen(),
          '/doctor-dashboard':(ctx) => const DoctorDashboardScreen(),
        },

        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Page not found: ${settings.name}')),
          ),
        ),
      ),
    );
  }
}

