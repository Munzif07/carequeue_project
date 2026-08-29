// ============================================================
//  CareQueue — Patient Auth Screen (patient_auth_screen.dart)
//  Login + Register Screen
//  File location: lib/screens/patient/patient_auth_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../../utils/lang.dart';

class PatientAuthScreen extends StatefulWidget {
  const PatientAuthScreen({Key? key}) : super(key: key);

  @override
  State<PatientAuthScreen> createState() => _PatientAuthScreenState();
}

class _PatientAuthScreenState extends State<PatientAuthScreen>
    with SingleTickerProviderStateMixin {

  String _activeTab = 'login'; // 'login' or 'register'
  bool _loading = false;

  // Colors
  static const Color _p   = Color(0xFF1a6b5a);
  static const Color _pl  = Color(0xFF25a882);
  static const Color _pd  = Color(0xFF0f3d33);
  static const Color _bg  = Color(0xFFf0f7f5);
  static const Color _bd  = Color(0xFFd4ede8);
  static const Color _dim = Color(0xFF6b8f88);
  static const Color _err = Color(0xFFe74c3c);

  // Login
  final _lGmail = TextEditingController();
  final _lPass  = TextEditingController();
  bool _lPassVisible = false;

  // Register
  final _rName  = TextEditingController();
  final _rNic   = TextEditingController();
  final _rPhone = TextEditingController();
  final _rGmail = TextEditingController();
  final _rPatId = TextEditingController();
  final _rPass  = TextEditingController();
  final _rConf  = TextEditingController();
  bool _rPassVisible = false;
  bool _rConfVisible = false;

  // Errors
  String? _eName, _eNic, _ePhone, _eGmail, _ePatId, _ePass, _eConf;

  // Animation
  late AnimationController _animCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    langNotifier.addListener(_onLangChange);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _lGmail.dispose(); _lPass.dispose();
    _rName.dispose(); _rNic.dispose(); _rPhone.dispose();
    _rGmail.dispose(); _rPatId.dispose(); _rPass.dispose(); _rConf.dispose();
    langNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  void _switchTab(String tab) {
    setState(() {
      _activeTab = tab;
      _eName = _eNic = _ePhone = _eGmail = _ePatId = _ePass = _eConf = null;
    });
    _animCtrl.forward(from: 0);
  }

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

  // ══ LOGIN ════════════════════════════════════════════════
  Future<void> _patLogin() async {
    final gmail = _lGmail.text.trim().toLowerCase();
    final pass  = _lPass.text;

    if (gmail.isEmpty || pass.isEmpty) {
      _toast(Lang.t('err_login_both'));
      return;
    }
    // Must include @gmail.com exactly once
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@gmail\.com$').hasMatch(gmail)) {
      _toast('❌ Please enter a valid @gmail.com address');
      return;
    }
    setState(() => _loading = true);
    _toast('⏳ Logging in...');
    try {
      final result = await ApiService.patientLogin(gmail, pass);
      if (!result['success']) { _toast('❌ ${result['message'] ?? 'Login failed!'}'); return; }

      await Session.save(
        name:     result['user']['name'],
        gmail:    result['user']['gmail'],
        patId:    result['user']['patid'] ?? '',
        clinicId: result['user']['clinic_id'] ?? 'CLN-2024-001',
        role:     'patient',
        token:    result['token'] ?? '',
      );
      _toast('👋 ${Lang.t("welcome_back")}, ${(result["user"]["name"] as String).split(" ")[0]}!');
      if (mounted) Navigator.pushReplacementNamed(context, '/patient-home');
    } catch (e) {
      _toast('❌ Server error! Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ══ REGISTER ═════════════════════════════════════════════
  Future<void> _patRegister() async {
    setState(() => _eName = _eNic = _ePhone = _eGmail = _ePatId = _ePass = _eConf = null);

    final name  = _rName.text.trim();
    final nic   = _rNic.text.trim().toUpperCase();
    final phone = _rPhone.text.trim();
    final gmail = _rGmail.text.trim().toLowerCase();
    // Combine fixed "P-" prefix with user-typed 4 digits
    final patId = 'P-${_rPatId.text.trim().padLeft(4, '0')}';

    bool ok = true;

    // 01. Full name
    if (name.isEmpty) {
      setState(() => _eName = Lang.t('err_name_empty')); ok = false;
    } else if (!RegExp(r"^[A-Za-z][A-Za-z\s\.]*$").hasMatch(name)) {
      setState(() => _eName = Lang.t('err_name_english')); ok = false;
    }

    // 02. NIC
    if (nic.isEmpty) {
      setState(() => _eNic = Lang.t('err_nic_empty')); ok = false;
    } else if (!RegExp(r'^\d{12}$').hasMatch(nic) && !RegExp(r'^\d{9}[Vv]$').hasMatch(nic)) {
      setState(() => _eNic = Lang.t('err_nic_format')); ok = false;
    }

    // 03. Phone
    if (phone.isEmpty) {
      setState(() => _ePhone = Lang.t('err_phone_empty')); ok = false;
    } else if (!RegExp(r'^07\d{8}$').hasMatch(phone)) {
      setState(() => _ePhone = Lang.t('err_phone_format')); ok = false;
    }

    // 04. Gmail — must be full @gmail.com format, exactly once
    if (gmail.isEmpty) {
      setState(() => _eGmail = Lang.t('err_gmail_empty')); ok = false;
    } else if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@gmail\.com$').hasMatch(gmail)) {
      setState(() => _eGmail = Lang.t('err_gmail_format')); ok = false;
    }

    // 05. Patient ID — user types 4 digits, we build P-XXXX
    final digits = _rPatId.text.trim();
    if (digits.isEmpty) {
      setState(() => _ePatId = Lang.t('err_patid_empty')); ok = false;
    } else if (!RegExp(r'^\d{4}$').hasMatch(digits)) {
      setState(() => _ePatId = Lang.t('err_patid_format')); ok = false;
    }

    final pass  = _rPass.text;
    final conf  = _rConf.text;

    // Password
    if (pass.isEmpty || pass.length < 6) {
      setState(() => _ePass = Lang.t('err_pass_empty')); ok = false;
    }
    if (pass != conf) {
      setState(() => _eConf = Lang.t('err_pass_match')); ok = false;
    }
    if (!ok) return;

    // ── Step 1: Send OTP to Gmail ─────────────────────────
    setState(() => _loading = true);
    try {
      final otpResult = await ApiService.sendOTP(
        gmail: gmail,
        purpose: 'register',
        nic: nic,
        patId: patId,
        clinicId: 'CLN-2024-001',
      );
      if (!otpResult['success']) {
        _toast('❌ ${otpResult['message'] ?? 'Failed to send OTP!'}');
        return;
      }
      // ── Step 2: Show OTP verification popup ──────────────
      _toast('📧 OTP sent to $gmail');
      if (mounted) {
        _showOTPDialog(
          gmail: gmail,
          purpose: 'register',
          onVerified: () async {
            // ── Step 3: Register after OTP verified ──────────
            setState(() => _loading = true);
            try {
              final result = await ApiService.patientRegister(
                name: name, nic: nic, phone: phone,
                gmail: gmail, patId: patId,
                clinicId: 'CLN-2024-001', password: pass,
              );
              if (!result['success']) {
                _toast('❌ ${result['message'] ?? 'Registration failed!'}');
                return;
              }
              await Session.save(
                name: name, gmail: gmail,
                patId: patId, clinicId: 'CLN-2024-001',
                role: 'patient', token: result['token'] ?? '',
              );
              _toast('🎉 Welcome ${name.split(' ')[0]}!');
              if (mounted) Navigator.pushReplacementNamed(context, '/patient-home');
            } catch (e) {
              _toast('❌ Server error! Try again.');
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
        );
      }
    } catch (e) {
      _toast('❌ Server error! Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── OTP Dialog ────────────────────────────────────────────
  void _showOTPDialog({
    required String gmail,
    required String purpose,
    required VoidCallback onVerified,
  }) {
    final otpCtrl = TextEditingController();
    String? otpError;
    bool verifying = false;
    bool resending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('✉️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text('Verify Your Gmail',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                    color: Color(0xFF1a2e2a))),
              const SizedBox(height: 6),
              Text('Enter the 6-digit code sent to\n$gmail',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
              const SizedBox(height: 20),

              // OTP input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: otpError != null
                      ? const Color(0xFFe53935)
                      : const Color(0xFF25a882), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  buildCounter: (_,{required currentLength,required isFocused,maxLength})=>null,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                      letterSpacing: 12, color: Color(0xFF1a2e2a)),
                  decoration: const InputDecoration(
                    border: InputBorder.none, hintText: '------',
                    hintStyle: TextStyle(fontSize: 24, letterSpacing: 10,
                        color: Color(0xFFcccccc)),
                  ),
                ),
              ),
              if (otpError != null) ...[
                const SizedBox(height: 6),
                Text(otpError!, style: const TextStyle(fontSize: 12, color: Color(0xFFe53935))),
              ],
              const SizedBox(height: 8),
              Text('⏰ Code expires in 10 minutes',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),

              const SizedBox(height: 20),

              // Verify button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: verifying ? null : () async {
                    final code = otpCtrl.text.trim();
                    if (code.length != 6) {
                      setS(() => otpError = '❌ Enter 6-digit code');
                      return;
                    }
                    setS(() { verifying = true; otpError = null; });
                    try {
                      final r = await ApiService.verifyOTP(
                          gmail: gmail, otp: code, purpose: purpose);
                      if (r['success'] == true) {
                        Navigator.pop(ctx);
                        onVerified();
                      } else {
                        setS(() {
                          otpError = '❌ ${r['message'] ?? 'Incorrect OTP'}';
                          verifying = false;
                        });
                      }
                    } catch (_) {
                      setS(() { otpError = '❌ Connection error'; verifying = false; });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: verifying ? null : const LinearGradient(
                          colors: [Color(0xFF1a6b5a), Color(0xFF25a882)]),
                      color: verifying ? Colors.grey.shade300 : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: verifying
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(Lang.t('verify_register_btn'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              color: Colors.white))),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Resend OTP
              GestureDetector(
                onTap: resending ? null : () async {
                  setS(() { resending = true; otpError = null; });
                  try {
                    final r = await ApiService.sendOTP(gmail: gmail, purpose: purpose);
                    setS(() => resending = false);
                    if (r['success'] == true) {
                      otpCtrl.clear();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('📧 New OTP sent!'),
                        backgroundColor: Color(0xFF1a6b5a),
                      ));
                    } else {
                      setS(() => otpError = '❌ ${r['message']}');
                    }
                  } catch (_) {
                    setS(() { resending = false; otpError = '❌ Connection error'; });
                  }
                },
                child: Text(resending ? 'Sending...' : '🔄 Resend OTP',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: resending ? Colors.grey : const Color(0xFF1a6b5a))),
              ),

              const SizedBox(height: 8),

              // Cancel
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Text('✕ Cancel',
                  style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ══ BUILD ════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _activeTab == 'login' ? _buildLoginForm() : _buildRegisterForm(),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_pd, _p]),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
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
                  child: const Center(child: Text('‹', style: TextStyle(fontSize: 22, color: Colors.white))),
                ),
              ),
              LangSwitcher(activeColor: _p, inactiveColor: Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          const Text('👤', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text(Lang.t('patient'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          SizedBox(height: 3),
          Text(Lang.t('patient_desc'),
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 16),
          // Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              _tabBtn(Lang.t('login'), 'login'),
              _tabBtn(Lang.t('register'), 'register'),
            ]),
          ),
        ]),
      )),
    );
  }

  Widget _tabBtn(String label, String key) {
    final active = _activeTab == key;
    return Expanded(child: GestureDetector(
      onTap: () => _switchTab(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: active ? _p : Colors.white.withOpacity(0.6),
          )),
      ),
    ));
  }

  // ══ LOGIN FORM ═══════════════════════════════════════════
  Widget _buildLoginForm() {
    return Column(children: [
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Lang.t('login_title')),
        _label(Lang.t('gmail_label')),
        _gmailInput(controller: _lGmail),
        SizedBox(height: 12),
        _label(Lang.t('password_label')),
        _passInput(controller: _lPass, hint: '••••••••',
            visible: _lPassVisible, onToggle: () => setState(() => _lPassVisible = !_lPassVisible)),
        SizedBox(height: 10),
        // Forgot Password link
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _loading ? null : _showForgotPassword,
            child: Text(
              Lang.t('forgot_password'),
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: _p, decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ])),
      SizedBox(height: 14),
      _btnPrimary(label: Lang.t('login_btn'), onTap: _loading ? null : _patLogin, loading: _loading),
      SizedBox(height: 14),
      _divider(Lang.t('or')),
      SizedBox(height: 14),
      _btnOutline(label: Lang.t('create_account'), onTap: () => _switchTab('register')),
      const SizedBox(height: 20),
    ]);
  }

  // ══ FORGOT PASSWORD FLOW ═════════════════════════════════
  void _showForgotPassword() {
    final gmailCtrl  = TextEditingController();
    final passCtrl   = TextEditingController();
    final confCtrl   = TextEditingController();
    String step      = 'email'; // email → otp → newpass
    String? errMsg;
    bool   loading   = false;
    bool   passVis   = false;
    bool   confVis   = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {

          // ── Step 1: Enter Gmail ─────────────────────────
          if (step == 'email') {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔑', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(Lang.t('forgot_password'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: Color(0xFF1a2e2a))),
                  const SizedBox(height: 6),
                  Text(Lang.t('forgot_pass_sub'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                  const SizedBox(height: 20),

                  // Gmail input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: errMsg != null
                          ? const Color(0xFFe53935) : const Color(0xFF25a882), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: gmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        border: InputBorder.none, isDense: true,
                        hintText: 'yourname@gmail.com',
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        prefixIcon: const Text('✉️ ', style: TextStyle(fontSize: 16)),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
                      ),
                    ),
                  ),
                  if (errMsg != null) ...[
                    const SizedBox(height: 6),
                    Text(errMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFFe53935))),
                  ],
                  const SizedBox(height: 20),

                  // Send OTP button
                  SizedBox(width: double.infinity,
                    child: GestureDetector(
                      onTap: loading ? null : () async {
                        final g = gmailCtrl.text.trim().toLowerCase();
                        if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@gmail\.com$').hasMatch(g)) {
                          setS(() => errMsg = '❌ ${Lang.t("err_gmail_format")}'); return;
                        }
                        setS(() { loading = true; errMsg = null; });
                        try {
                          final r = await ApiService.sendOTP(gmail: g, purpose: 'forgot');
                          if (r['success'] == true) {
                            setS(() { step = 'otp'; loading = false; });
                          } else {
                            setS(() { errMsg = '❌ ${r['message']}'; loading = false; });
                          }
                        } catch (_) {
                          setS(() { errMsg = '❌ Connection error'; loading = false; });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: loading ? null : const LinearGradient(
                              colors: [Color(0xFF1a6b5a), Color(0xFF25a882)]),
                          color: loading ? Colors.grey.shade300 : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(Lang.t('send_otp_btn'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                  color: Colors.white))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Text(Lang.t('cancel_btn'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  ),
                ]),
              ),
            );
          }

          // ── Step 2: Enter OTP ───────────────────────────
          if (step == 'otp') {
            final otpCtrl = TextEditingController();
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('✉️', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(Lang.t('verify_gmail'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: Color(0xFF1a2e2a))),
                  const SizedBox(height: 6),
                  Text('${Lang.t("otp_sent_to")}\n${gmailCtrl.text.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                  const SizedBox(height: 20),
                  // OTP input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: errMsg != null
                          ? const Color(0xFFe53935) : const Color(0xFF25a882), width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6, textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      buildCounter: (_,{required currentLength,required isFocused,maxLength})=>null,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                          letterSpacing: 12),
                      decoration: const InputDecoration(
                        border: InputBorder.none, hintText: '------',
                        hintStyle: TextStyle(fontSize: 24, letterSpacing: 10,
                            color: Color(0xFFcccccc))),
                    ),
                  ),
                  if (errMsg != null) ...[
                    const SizedBox(height: 6),
                    Text(errMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFFe53935))),
                  ],
                  const SizedBox(height: 6),
                  Text(Lang.t('otp_expires'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  const SizedBox(height: 20),
                  // Verify button
                  SizedBox(width: double.infinity,
                    child: GestureDetector(
                      onTap: loading ? null : () async {
                        final code = otpCtrl.text.trim();
                        if (code.length != 6) {
                          setS(() => errMsg = '❌ ${Lang.t("otp_6digits")}'); return;
                        }
                        setS(() { loading = true; errMsg = null; });
                        try {
                          final r = await ApiService.verifyOTP(
                              gmail: gmailCtrl.text.trim().toLowerCase(),
                              otp: code, purpose: 'forgot');
                          if (r['success'] == true) {
                            setS(() { step = 'newpass'; loading = false; });
                          } else {
                            setS(() { errMsg = '❌ ${r['message']}'; loading = false; });
                          }
                        } catch (_) {
                          setS(() { errMsg = '❌ Connection error'; loading = false; });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: loading ? null : const LinearGradient(
                              colors: [Color(0xFF1a6b5a), Color(0xFF25a882)]),
                          color: loading ? Colors.grey.shade300 : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(Lang.t('verify_btn'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                  color: Colors.white))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setS(() { step = 'email'; errMsg = null; }),
                    child: Text(Lang.t('back_btn'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  ),
                ]),
              ),
            );
          }

          // ── Step 3: Enter New Password ──────────────────
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔐', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(Lang.t('new_password_title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: Color(0xFF1a2e2a))),
                const SizedBox(height: 6),
                Text(Lang.t('new_password_sub'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                const SizedBox(height: 20),

                // New Password
                _passInput(controller: passCtrl, hint: Lang.t('new_pass_hint'),
                  visible: passVis, onToggle: () => setS(() => passVis = !passVis)),
                const SizedBox(height: 12),
                // Confirm Password
                _passInput(controller: confCtrl, hint: Lang.t('confirm_pass_hint'),
                  visible: confVis, onToggle: () => setS(() => confVis = !confVis)),

                if (errMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFFe53935))),
                ],
                const SizedBox(height: 20),

                SizedBox(width: double.infinity,
                  child: GestureDetector(
                    onTap: loading ? null : () async {
                      final np = passCtrl.text;
                      final cp = confCtrl.text;
                      if (np.length < 6) {
                        setS(() => errMsg = '❌ ${Lang.t("err_pass_empty")}'); return;
                      }
                      if (np != cp) {
                        setS(() => errMsg = '❌ ${Lang.t("err_pass_match")}'); return;
                      }
                      setS(() { loading = true; errMsg = null; });
                      try {
                        final r = await ApiService.resetPassword(
                            gmail: gmailCtrl.text.trim().toLowerCase(),
                            newPassword: np);
                        if (r['success'] == true) {
                          Navigator.pop(ctx);
                          _toast('✅ ${Lang.t("pass_reset_success")}');
                        } else {
                          setS(() { errMsg = '❌ ${r['message']}'; loading = false; });
                        }
                      } catch (_) {
                        setS(() { errMsg = '❌ Connection error'; loading = false; });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: loading ? null : const LinearGradient(
                            colors: [Color(0xFF1a6b5a), Color(0xFF25a882)]),
                        color: loading ? Colors.grey.shade300 : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(Lang.t('reset_pass_btn'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                color: Colors.white))),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ══ REGISTER FORM ════════════════════════════════════════
  Widget _buildRegisterForm() {
    return Column(children: [
      // Card 1: Personal Details
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Lang.t('personal_details')),
        _label(Lang.t('fullname_label')),
        _textInput(controller: _rName, icon: '👤', hint: Lang.t('fullname_hint'),
            error: _eName,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\s\.]'))]),
        SizedBox(height: 12),
        _label(Lang.t('nic_label')),
        _textInput(controller: _rNic, icon: '🪪', hint: '991234567V', error: _eNic,
            caps: TextCapitalization.characters,
            onChanged: (v) { final u = v.toUpperCase(); if (u != v) { _rNic.value = _rNic.value.copyWith(text: u, selection: TextSelection.collapsed(offset: u.length)); } }),
        SizedBox(height: 12),
        _label(Lang.t('phone_label')),
        _textInput(controller: _rPhone, icon: '📱', hint: Lang.t('phone_hint'),
            error: _ePhone, keyboard: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        SizedBox(height: 12),
        _label(Lang.t('gmail_label') + ' *'),
        _gmailInput(controller: _rGmail, error: _eGmail),
      ])),
      const SizedBox(height: 14),

      // Card 2: Clinic Details
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Lang.t('clinic_details')),
        _label(Lang.t('patient_id_label')),
        // P- prefix fixed, user types 4 digits only
        _patIdInput(error: _ePatId),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
          child: Text(Lang.t('patient_id_hint_info'),
              style: TextStyle(fontSize: 12, color: _dim)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_p, _pl]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Text('🏥', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Lang.t('registered_clinic'), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
              const Text('Sri Murugan Clinic', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('CLN-2024-001', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
            ]),
          ]),
        ),
      ])),
      const SizedBox(height: 14),

      // Card 3: Password
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Lang.t('password_section')),
        _label(Lang.t('password_label') + ' *'),
        _passInput(controller: _rPass, hint: Lang.t('min_pass_hint'),
            visible: _rPassVisible, onToggle: () => setState(() => _rPassVisible = !_rPassVisible),
            error: _ePass),
        SizedBox(height: 12),
        _label(Lang.t('confirm_pass_label')),
        _passInput(controller: _rConf, hint: Lang.t('confirm_pass_hint'),
            visible: _rConfVisible, onToggle: () => setState(() => _rConfVisible = !_rConfVisible),
            error: _eConf),
      ])),
      const SizedBox(height: 14),

      _btnPrimary(label: Lang.t('register_btn'), onTap: _loading ? null : _patRegister, loading: _loading),
      SizedBox(height: 14),
      _divider(Lang.t('already_account')),
      SizedBox(height: 14),
      _btnOutline(label: Lang.t('login'), onTap: () => _switchTab('login')),
      const SizedBox(height: 20),
    ]);
  }

  // ══ REUSABLE WIDGETS ═════════════════════════════════════
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _bd),
      boxShadow: [BoxShadow(color: _p.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  Widget _cardTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(t.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _dim, letterSpacing: 1)),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
  );

  // ── Patient ID input — "P-" fixed prefix, user types 4 digits ──
  Widget _patIdInput({String? error}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FocusBorderBox(focusColor: _pl, borderColor: _bd, child: Row(children: [
        const SizedBox(width: 13),
        const Text('🪪', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        // Fixed "P-" prefix
        const Text('P-', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1a6b5a))),
        // User types 4 digits only
        SizedBox(
          width: 70,
          child: TextField(
            controller: _rPatId,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            buildCounter: (_,{required currentLength,required isFocused,maxLength})=> null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '0001',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 13),
      ])),
      if (error != null) ...[const SizedBox(height: 3),
        Text(error, style: const TextStyle(fontSize: 12, color: _err))],
    ]);
  }

  Widget _gmailInput({required TextEditingController controller, String? error}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FocusBorderBox(focusColor: _pl, borderColor: _bd, child: Row(children: [
        const SizedBox(width: 13),
        const Text('✉️', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'yourname@gmail.com',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 13),
          ),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
        )),
        const SizedBox(width: 13),
      ])),
      if (error != null) ...[const SizedBox(height: 3), Text(error, style: const TextStyle(fontSize: 12, color: _err))],
    ]);
  }

  Widget _textInput({
    required TextEditingController controller, required String icon, required String hint,
    String? error, TextInputType keyboard = TextInputType.text,
    TextCapitalization caps = TextCapitalization.none, int? maxLength,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FocusBorderBox(focusColor: _pl, borderColor: _bd, child: Row(children: [
        const SizedBox(width: 13),
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller, keyboardType: keyboard,
          textCapitalization: caps, maxLength: maxLength, onChanged: onChanged,
          inputFormatters: inputFormatters,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          decoration: InputDecoration(border: InputBorder.none, hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 13)),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
        )),
        const SizedBox(width: 13),
      ])),
      if (error != null) ...[const SizedBox(height: 3), Text(error, style: const TextStyle(fontSize: 12, color: _err))],
    ]);
  }

  Widget _passInput({
    required TextEditingController controller, required String hint,
    required bool visible, required VoidCallback onToggle, String? error,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FocusBorderBox(focusColor: _pl, borderColor: _bd, child: Row(children: [
        const SizedBox(width: 13),
        Text(visible ? '🔓' : '🔑', style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller, obscureText: !visible,
          decoration: InputDecoration(border: InputBorder.none, hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 13)),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
        )),
        IconButton(onPressed: onToggle, icon: Icon(visible ? Icons.visibility_off : Icons.visibility, color: _dim, size: 20),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 40)),
      ])),
      if (error != null) ...[const SizedBox(height: 3), Text(error, style: const TextStyle(fontSize: 12, color: _err))],
    ]);
  }

  Widget _btnPrimary({required String label, VoidCallback? onTap, bool loading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: onTap != null ? const LinearGradient(colors: [_p, _pl]) : null,
          color: onTap == null ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null ? [BoxShadow(color: _p.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))] : null,
        ),
        child: Center(child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
      ),
    );
  }

  Widget _btnOutline({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _p, width: 2)),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _p))),
      ),
    );
  }

  Widget _divider(String text) => Row(children: [
    Expanded(child: Divider(color: _bd)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: TextStyle(fontSize: 13, color: _dim))),
    Expanded(child: Divider(color: _bd)),
  ]);
}

// ══ Focus Border Box ════════════════════════════════════
class _FocusBorderBox extends StatefulWidget {
  final Widget child;
  final Color focusColor;
  final Color borderColor;
  const _FocusBorderBox({required this.child, required this.focusColor, required this.borderColor});

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
        border: Border.all(color: _focused ? widget.focusColor : widget.borderColor, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: widget.child,
    ),
  );
}
