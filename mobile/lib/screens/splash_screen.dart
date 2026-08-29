// ============================================================
//  CareQueue — Splash Screen
//  Language: English | Tamil | Sinhala
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/lang.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  static const Color _pd = Color(0xFF0f3d33);
  static const Color _p  = Color(0xFF1a6b5a);
  static const Color _pl = Color(0xFF25a882);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    // Rebuild when language changes
    langNotifier.addListener(_onLangChange);
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    langNotifier.removeListener(_onLangChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0], colors: [_pd, _p, _pl],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Language Switcher ──
                    Align(
                      alignment: Alignment.topRight,
                      child: LangSwitcher(
                        activeColor:   _p,
                        inactiveColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Logo ──
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
                      ),
                      child: const Center(child: Text('🏥', style: TextStyle(fontSize: 44))),
                    ),
                    const SizedBox(height: 16),

                    Text('CareQueue',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 0.5)),
                    SizedBox(height: 6),
                    Text(Lang.t('app_tagline'),
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.65))),

                    const SizedBox(height: 36),

                    // ── WHO ARE YOU label ──
                    Text('WHO ARE YOU?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.55), letterSpacing: 1.5)),
                    const SizedBox(height: 14),

                    // ── Patient Card ──
                    _RoleCard(
                      icon: '👤',
                      title: Lang.t('patient'),
                      desc:  Lang.t('patient_desc'),
                      onTap: () => Navigator.pushNamed(context, '/patient-auth'),
                    ),
                    const SizedBox(height: 12),

                    // ── Doctor Card ──
                    _RoleCard(
                      icon: '👨‍⚕️',
                      title: Lang.t('doctor'),
                      desc:  Lang.t('doctor_desc'),
                      onTap: () => Navigator.pushNamed(context, '/doctor-auth'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role Card Widget ──────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String icon, title, desc;
  final VoidCallback onTap;
  const _RoleCard({required this.icon, required this.title,
      required this.desc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 3),
            Text(desc,  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
          ])),
          Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.6), size: 16),
        ]),
      ),
    );
  }
}
