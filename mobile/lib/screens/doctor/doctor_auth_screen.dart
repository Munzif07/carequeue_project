// ============================================================
//  CareQueue — Doctor Auth Screen (doctor_auth_screen.dart)
//  File location: lib/screens/doctor/doctor_auth_screen.dart
//  HTML: #s-doc-auth  —  .ah.blue header + demobox + login form
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../../utils/lang.dart';

class DoctorAuthScreen extends StatefulWidget {
  const DoctorAuthScreen({Key? key}) : super(key: key);

  @override
  State<DoctorAuthScreen> createState() => _DoctorAuthScreenState();
}

class _DoctorAuthScreenState extends State<DoctorAuthScreen>
    with SingleTickerProviderStateMixin {

  void _onLangChange() { if (mounted) setState(() {}); }

  // ── Colors (HTML .ah.blue = #1a2e4a → #2c4a7a) ──────────
  static const Color _blue1 = Color(0xFF1a2e4a); // dark navy
  static const Color _blue2 = Color(0xFF2c4a7a); // medium navy
  static const Color _p     = Color(0xFF1a6b5a);
  static const Color _pl    = Color(0xFF25a882);
  static const Color _bg    = Color(0xFFf0f7f5);
  static const Color _bd    = Color(0xFFd4ede8);
  static const Color _dim   = Color(0xFF6b8f88);
  static const Color _err   = Color(0xFFe74c3c);

  // ── Controllers ──────────────────────────────────────────
  final _cidCtrl  = TextEditingController(); // Clinic ID
  final _nameCtrl = TextEditingController(); // Doctor name (optional)
  final _passCtrl = TextEditingController(); // Password

  bool _passVisible = false;
  bool _loading     = false;

  // ── Errors ───────────────────────────────────────────────
  String? _eCid, _ePass;

  // ── Animation ────────────────────────────────────────────
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLangChange);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cidCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    langNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  // ── Toast ────────────────────────────────────────────────
  void _toast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: const Color(0xFF1a2e2a),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(milliseconds: 2800),
    ));
  }

  // ── Auto-fill demo credentials ───────────────────────────
  void _fillDemo() {
    setState(() {
      _cidCtrl.text  = 'CLN-2024-001';
      _passCtrl.text = 'password';
      _eCid = _ePass = null;
    });
    _toast('✅ Demo credentials filled!');
  }

  // ════════════════════════════════════════════════════════
  //  DOCTOR LOGIN  —  docLogin() from HTML
  // ════════════════════════════════════════════════════════
  Future<void> _docLogin() async {
    // Clear errors
    setState(() => _eCid = _ePass = null);

    final cid  = _cidCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text;

    // Validation
    bool ok = true;
    if (cid.isEmpty)  { setState(() => _eCid  = Lang.t('err_cid_empty')); ok = false; }
    if (pass.isEmpty) { setState(() => _ePass = Lang.t('err_dpass_empty'));  ok = false; }
    if (!ok) return;

    setState(() => _loading = true);
    _toast('⏳ Logging in...');

    try {
      final result = await ApiService.doctorLogin(cid, pass, name);

      if (result['success'] != true) {
        _toast('❌ ${result['message'] ?? 'Login failed!'}');
        return;
      }

      final doctor = result['doctor'] as Map<String, dynamic>;

      // Save session as doctor role
      await Session.save(
        name:     doctor['name']        ?? name,
        gmail:    '',
        patId:    '',
        clinicId: doctor['clinic_id']   ?? cid,
        role:     'doctor',
        token:    result['token']       ?? '',
      );

      _toast('👋 Welcome, ${(doctor['name'] ?? name).toString().split(' ')[0]}!');
      if (mounted) Navigator.pushReplacementNamed(context, '/doctor-dashboard');

    } catch (_) {
      _toast('❌ Server error! Check connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Blue header
        _buildHeader(),
        // Scrollable body
        Expanded(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  // Demo box
                  _buildDemoBox(),
                  const SizedBox(height: 14),
                  // Login form card
                  _buildLoginCard(),
                  const SizedBox(height: 14),
                  // Login button (.btn.btn-b — blue gradient)
                  _buildLoginBtn(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Blue Header (.ah.blue) ───────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue1, _blue2],
        ),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Back button + LangSwitcher row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('‹', style: TextStyle(fontSize: 22, color: Colors.white)),
                  ),
                ),
              ),
              LangSwitcher(activeColor: _blue2, inactiveColor: Colors.white),
            ],
          ),
          const SizedBox(height: 16),

          // Icon (.ah-ic)
          const Text('👨‍⚕️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),

          // Title (.ah-ti)
          Text(Lang.t('doc_login_title'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 3),

          // Subtitle (.ah-su)
          Text(Lang.t('doc_login_sub'),
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
        ]),
      )),
    );
  }

  // ── Demo Box (.demobox) ──────────────────────────────────
  // background: linear-gradient(135deg, #1a2e4a, #2c4a7a)
  Widget _buildDemoBox() {
    return GestureDetector(
      onTap: _fillDemo, // Tap to auto-fill
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_blue1, _blue2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          // Key icon
          const Text('🔑', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),

          // Demo credentials
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // .demolbl
            Text(Lang.t('demo_clinic_id'),
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65))),
            // .demoid — big letter spacing
            const Text('CLN-2024-001',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 3),
            // .demolbl
            Text(Lang.t('demo_password_label'),
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65))),
          ])),

          // Tap to fill hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(Lang.t('tap_to_fill'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.85))),
          ),
        ]),
      ),
    );
  }

  // ── Login Card ───────────────────────────────────────────
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bd),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1a6b5a).withOpacity(0.1),
              blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Card title (.ctitle)
         Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(Lang.t('doc_login_card'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _dim, letterSpacing: 1)),
        ),

        // ── Clinic ID field ──
        _label(Lang.t('clinic_id_label')),
        _FocusBorderBox(focusColor: _blue2, borderColor: _bd,
          child: Row(children: [
            const SizedBox(width: 13),
            const Text('🏥', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _cidCtrl,
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) {
                // Auto uppercase
                final up = v.toUpperCase();
                if (up != v) _cidCtrl.value = _cidCtrl.value.copyWith(
                    text: up, selection: TextSelection.collapsed(offset: up.length));
              },
              decoration: InputDecoration(
                border: InputBorder.none, hintText: Lang.t('clinic_id_hint'),
                isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
              style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a),
                  fontWeight: FontWeight.w700, letterSpacing: 1),
            )),
            const SizedBox(width: 13),
          ]),
        ),
        if (_eCid != null) ...[
          const SizedBox(height: 3),
          Text(_eCid!, style: const TextStyle(fontSize: 12, color: _err)),
        ],

        const SizedBox(height: 14),

        // ── Password ──
        _label(Lang.t('password_label')),
        _FocusBorderBox(focusColor: _blue2, borderColor: _bd,
          child: Row(children: [
            const SizedBox(width: 13),
            Text(_passVisible ? '🔓' : '🔑', style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _passCtrl,
              obscureText: !_passVisible,
              decoration: const InputDecoration(
                border: InputBorder.none, hintText: '••••••••',
                isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
              style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
            )),
            IconButton(
              onPressed: () => setState(() => _passVisible = !_passVisible),
              icon: Icon(_passVisible ? Icons.visibility_off : Icons.visibility,
                  color: _dim, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ]),
        ),
        if (_ePass != null) ...[
          const SizedBox(height: 3),
          Text(_ePass!, style: const TextStyle(fontSize: 12, color: _err)),
        ],

        const SizedBox(height: 4),

        // Hint text
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            const Text('💡 ', style: TextStyle(fontSize: 12)),
            Expanded(child: Text(
              Lang.t('doc_login_note'),
              style: TextStyle(fontSize: 12, color: _dim),
            )),
          ]),
        ),
      ]),
    );
  }

  // ── Login Button (.btn.btn-b — blue gradient) ─────────────
  Widget _buildLoginBtn() {
    return GestureDetector(
      onTap: _loading ? null : _docLogin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: _loading
              ? null
              : const LinearGradient(
                  colors: [_blue1, _blue2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _loading ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _loading ? null : [
            BoxShadow(color: _blue1.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(Lang.t('doc_login_btn'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    );
  }

  // ── Label helper ─────────────────────────────────────────
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
  );
}

// ════════════════════════════════════════════════════════
//  Focus Border Box (reused from patient_auth)
//  Blue focus color for doctor screen
// ════════════════════════════════════════════════════════
class _FocusBorderBox extends StatefulWidget {
  final Widget child;
  final Color focusColor;
  final Color borderColor;

  const _FocusBorderBox({
    required this.child,
    required this.focusColor,
    required this.borderColor,
  });

  @override
  State<_FocusBorderBox> createState() => _FocusBorderBoxState();
}

class _FocusBorderBoxState extends State<_FocusBorderBox> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (f) => setState(() => _focused = f),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _focused ? Colors.white : const Color(0xFFf0f7f5),
        border: Border.all(
          color: _focused ? widget.focusColor : widget.borderColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: widget.child,
    ),
  );
}
