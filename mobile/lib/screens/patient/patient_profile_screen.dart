// ============================================================
//  CareQueue — Patient Profile Screen
//  View Profile + Edit Profile + Delete Account popup
//  File location: lib/screens/patient/patient_profile_screen.dart
//  HTML: #s-pat-profile → pf-view + pf-edit + delete-popup
// ============================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../../utils/lang.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({Key? key}) : super(key: key);
  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {

  void _onLangChange() { if (mounted) setState(() {}); }

  // ── Colors ────────────────────────────────────────────────
  static const Color _p    = Color(0xFF1a6b5a);
  static const Color _pl   = Color(0xFF25a882);
  static const Color _pd   = Color(0xFF0f3d33);
  static const Color _bg   = Color(0xFFf0f7f5);
  static const Color _bd   = Color(0xFFd4ede8);
  static const Color _dim  = Color(0xFF6b8f88);
  static const Color _err  = Color(0xFFe74c3c);

  // ── View Mode: 'view' or 'edit' ───────────────────────────
  String _mode = 'view';

  // ── Profile data (from session) ───────────────────────────
  String _name     = '';
  String _nic      = '';
  String _phone    = '';
  String _gmail    = '';
  String _patId    = '';
  String _clinicId = '';
  String _clinicName = 'Sri Murugan Clinic';

  // ── Edit controllers ──────────────────────────────────────
  final _eName  = TextEditingController();
  final _ePhone = TextEditingController();
  final _eGmail = TextEditingController();
  final _eNic   = TextEditingController();

  // Change password (optional)
  final _eOld = TextEditingController();
  final _eNew = TextEditingController();
  final _eCnf = TextEditingController();
  bool _oldVisible = false;
  bool _newVisible = false;
  bool _cnfVisible = false;

  // Edit errors
  String? _errOld, _errCnf;
  bool _saving = false;

  // ── Delete popup ──────────────────────────────────────────
  bool _showDeletePopup = false;
  final _delPassCtrl = TextEditingController();
  bool _delPassVisible = false;
  String? _errDelPass;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLangChange);
    _loadSession();
  }

  @override
  void dispose() {
    _eName.dispose(); _ePhone.dispose(); _eGmail.dispose(); _eNic.dispose();
    _eOld.dispose(); _eNew.dispose(); _eCnf.dispose();
    _delPassCtrl.dispose();
    langNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  // ── Load session data ─────────────────────────────────────
  Future<void> _loadSession() async {
    final s = await Session.load();
    if (s == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }
    setState(() {
      _name     = s['name']     ?? '';
      _gmail    = s['gmail']    ?? '';
      _patId    = s['patId']    ?? '';
      _clinicId = s['clinicId'] ?? 'CLN-2024-001';
    });

    // Load full profile from API
    try {
      final result = await ApiService.getMyProfile(_patId, _clinicId);
      if (result['success'] == true) {
        final u = result['user'];
        setState(() {
          _name    = u['name']  ?? _name;
          _nic     = u['nic']   ?? '';
          _phone   = u['phone'] ?? '';
          _gmail   = u['gmail'] ?? _gmail;
          _clinicName = u['clinic_name'] ?? _clinicName;
        });
        await Session.save(
          name: _name, gmail: _gmail, patId: _patId,
          clinicId: _clinicId, role: 'patient',
          token: s['token'] ?? '',
        );
      }
    } catch (_) {}
  }

  // ── Enter edit mode ───────────────────────────────────────
  // editMode(true) from HTML
  void _enterEdit() {
    _eName.text  = _name;
    _ePhone.text = _phone;
    _eGmail.text = _gmail.replaceAll('@gmail.com', '');
    _eNic.text   = _nic;
    _eOld.clear(); _eNew.clear(); _eCnf.clear();
    setState(() { _mode = 'edit'; _errOld = _errCnf = null; });
  }

  void _cancelEdit() => setState(() => _mode = 'view');

  // ── Save profile ──────────────────────────────────────────
  // saveProfile() from HTML
  Future<void> _saveProfile() async {
    setState(() => _errOld = _errCnf = null);

    final name  = _eName.text.trim();
    final phone = _ePhone.text.trim();
    final gmail = _eGmail.text.trim().replaceAll(RegExp(r'@.*'), '').toLowerCase();
    final nic   = _eNic.text.trim().toUpperCase();
    final oldP  = _eOld.text;
    final newP  = _eNew.text;
    final cnfP  = _eCnf.text;

    if (name.isEmpty || phone.isEmpty || gmail.isEmpty || nic.isEmpty) {
      _toast('⚠️ Please fill in all fields!');
      return;
    }

    // Password change validation (optional)
    if (oldP.isNotEmpty || newP.isNotEmpty || cnfP.isNotEmpty) {
      if (newP.length < 6) { _toast('⚠️ Min 6 characters!'); return; }
      if (newP != cnfP) {
        setState(() => _errCnf = 'Passwords match ஆகலை');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final result = await ApiService.updateProfile(
        patId:    _patId,
        clinicId: _clinicId,
        name:     name,
        phone:    phone,
        gmail:    '$gmail@gmail.com',
        nic:      nic,
        oldPassword: oldP.isNotEmpty ? oldP : null,
        newPassword: newP.isNotEmpty ? newP : null,
      );

      if (result['success'] != true) {
        if (result['message']?.toString().contains('password') == true) {
          setState(() => _errOld = Lang.t('err_old_pass'));
        } else {
          _toast('❌ ${result['message']}');
        }
        return;
      }

      // Update local state + session
      setState(() {
        _name = name; _phone = phone;
        _gmail = '$gmail@gmail.com'; _nic = nic;
        _mode = 'view';
      });
      final s = await Session.load();
      await Session.save(
        name: name, gmail: '$gmail@gmail.com',
        patId: _patId, clinicId: _clinicId,
        role: 'patient', token: s?['token'] ?? '',
      );
      _toast('✅ Profile updated!');
    } catch (_) {
      _toast('❌ Server error!');
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Delete account ────────────────────────────────────────
  Future<void> _deleteAccount() async {
    setState(() => _errDelPass = null);
    final pass = _delPassCtrl.text;
    if (pass.isEmpty) {
      setState(() => _errDelPass = Lang.t('err_pass_empty'));
      return;
    }

    setState(() => _deleting = true);
    try {
      final result = await ApiService.deleteAccount(password: pass);
      if (result['success'] != true) {
        setState(() => _errDelPass = '❌ ${result['message'] ?? Lang.t('err_pass_wrong')}');
        return;
      }
      _delPassCtrl.clear();
      await Session.clear();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      setState(() => _errDelPass = '❌ Connection error. Try again.');
    } finally {
      setState(() => _deleting = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> _logout() async {
    await Session.clear();
    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: const Color(0xFF1a2e2a),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      duration: const Duration(milliseconds: 2800),
    ));
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Scaffold(
          backgroundColor: _bg,
          body: Column(children: [
            // Hero header (.phero)
            _buildHero(),
            // Scrollable content
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _mode == 'view' ? _buildViewMode() : _buildEditMode(),
            )),
            _buildBottomNav(),
          ]),
        ),

        // Delete confirm popup (overlay)
        if (_showDeletePopup) _buildDeletePopup(),
      ]),
    );
  }

  // ── Hero Header (.phero) ──────────────────────────────────
  Widget _buildHero() {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : '?';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_pd, _p, _pl],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(children: [
          // 🌐 Language Switcher row (top right)
          Align(
            alignment: Alignment.topRight,
            child: LangSwitcher(
              activeColor: _p,
              inactiveColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),

          // .pav — avatar circle with name initial
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2.5),
            ),
            child: Center(child: Text(initial,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                    color: Colors.white))),
          ),
          const SizedBox(height: 10),
          // .pname
          Text(_name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 4),
          // .psub
          Text('${Lang.t("patient_id_prefix")}$_patId',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
        ]),
      )),
    );
  }

  // ════════════════════════════════════════════════════════
  //  VIEW MODE  (#pf-view)
  // ════════════════════════════════════════════════════════
  Widget _buildViewMode() {
    return Column(children: [
      // My Details card
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + Edit button
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(Lang.t('my_details'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _dim, letterSpacing: 1)),
          GestureDetector(
            onTap: _enterEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: _p, borderRadius: BorderRadius.circular(10)),
              child: Text(Lang.t('edit_btn'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // .prow rows
        _pRow('👤', Lang.t('profile_name'),       _name),
        _pRow('🪪', Lang.t('profile_nic'),        _nic.isEmpty  ? '—' : _nic),
        _pRow('📱', Lang.t('profile_phone'),      _phone.isEmpty ? '—' : _phone),
        _pRow('✉️', Lang.t('profile_gmail'),      _gmail.isEmpty ? '—' : _gmail),
        _pRow('🪪', Lang.t('profile_patient_id'), _patId.isEmpty ? '—' : _patId),
        _pRow('🏥', Lang.t('profile_clinic'),     _clinicName, last: true),
      ])),

      const SizedBox(height: 14),

      // Logout button (.btn.btn-r)
      _btn(
        label: Lang.t('logout_btn'),
        onTap: _logout,
        gradient: [const Color(0xFF636e72), const Color(0xFF2d3436)],
      ),

      const SizedBox(height: 10),

      // Delete Account button (white bg, red border)
      GestureDetector(
        onTap: () => setState(() { _showDeletePopup = true; _delPassCtrl.clear(); _errDelPass = null; }),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _err, width: 2),
          ),
          child: Center(child: Text(Lang.t('delete_my_account'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _err))),
        ),
      ),

      const SizedBox(height: 20),
    ]);
  }

  // .prow
  Widget _pRow(String icon, String label, String value, {bool last = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          // .pric
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // .prl
            Text(label, style: const TextStyle(fontSize: 12, color: _dim)),
            const SizedBox(height: 2),
            // .prv
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Color(0xFF1a2e2a))),
          ])),
        ]),
      ),
      if (!last) Divider(color: _bd, height: 1),
    ]);
  }

  // ════════════════════════════════════════════════════════
  //  EDIT MODE  (#pf-edit)
  // ════════════════════════════════════════════════════════
  Widget _buildEditMode() {
    return Column(children: [
      // Card 1: Personal Info
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Lang.t('edit_profile_title'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: _dim, letterSpacing: 1)),
        const SizedBox(height: 14),

        _label(Lang.t('name_label')),
        _field(controller: _eName, icon: '👤', hint: Lang.t('fullname_edit_hint')),
        const SizedBox(height: 12),

        _label(Lang.t('profile_phone')),
        _field(controller: _ePhone, icon: '📱', hint: '07XXXXXXXX',
            keyboard: TextInputType.phone),
        const SizedBox(height: 12),

        _label(Lang.t('profile_gmail')),
        // Gmail split input
        _gmailField(),
        const SizedBox(height: 12),

        _label(Lang.t('profile_nic')),
        _field(controller: _eNic, icon: '🪪', hint: '991234567V',
            caps: TextCapitalization.characters,
            onChanged: (v) {
              final u = v.toUpperCase();
              if (u != v) _eNic.value = _eNic.value.copyWith(
                  text: u, selection: TextSelection.collapsed(offset: u.length));
            }),
      ])),

      const SizedBox(height: 14),

      // Card 2: Change Password (optional)
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(Lang.t('change_pass_title'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _dim, letterSpacing: 1)),
          SizedBox(width: 8),
          Text(Lang.t('optional_label'),
              style: TextStyle(fontSize: 11, color: _dim.withOpacity(0.7))),
        ]),
        const SizedBox(height: 14),

        _label(Lang.t('old_pass_label')),
        _passField(ctrl: _eOld, hint: '••••••••',
            visible: _oldVisible, onToggle: () => setState(() => _oldVisible = !_oldVisible)),
        if (_errOld != null) ...[
          const SizedBox(height: 3),
          Text(_errOld!, style: const TextStyle(fontSize: 12, color: _err)),
        ],
        const SizedBox(height: 12),

        _label(Lang.t('new_pass_label')),
        _passField(ctrl: _eNew, hint: Lang.t('new_pass_hint'),
            visible: _newVisible, onToggle: () => setState(() => _newVisible = !_newVisible)),
        const SizedBox(height: 12),

        _label(Lang.t('confirm_new_pass')),
        _passField(ctrl: _eCnf, hint: Lang.t('confirm_pass_hint2'),
            visible: _cnfVisible, onToggle: () => setState(() => _cnfVisible = !_cnfVisible)),
        if (_errCnf != null) ...[
          const SizedBox(height: 3),
          Text(_errCnf!, style: const TextStyle(fontSize: 12, color: _err)),
        ],
      ])),

      const SizedBox(height: 14),

      // Cancel + Save buttons (grid 1fr 1fr)
      Row(children: [
        // Cancel (.btn.btn-o)
        Expanded(child: GestureDetector(
          onTap: _cancelEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _p, width: 2),
            ),
            child: Center(child: Text(Lang.t('cancel_btn'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _p))),
          ),
        )),
        const SizedBox(width: 12),
        // Save (.btn.btn-p)
        Expanded(child: GestureDetector(
          onTap: _saving ? null : _saveProfile,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: _saving ? null : const LinearGradient(colors: [_p, _pl]),
              color: _saving ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(Lang.t('save_btn'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
        )),
      ]),

      const SizedBox(height: 20),
    ]);
  }

  // ════════════════════════════════════════════════════════
  //  DELETE CONFIRM POPUP  (#delete-popup)
  // ════════════════════════════════════════════════════════
  Widget _buildDeletePopup() {
    return GestureDetector(
      onTap: () => setState(() => _showDeletePopup = false),
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(child: GestureDetector(
          onTap: () {}, // prevent dismiss on card tap
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
                  blurRadius: 60, offset: const Offset(0, 20))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Warning icon
              const Text('⚠️', style: TextStyle(fontSize: 52)),
              SizedBox(height: 10),
              Text(Lang.t('delete_account_title'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _err)),
              SizedBox(height: 8),
              Text(Lang.t('delete_warning_long'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _dim)),

              const SizedBox(height: 14),

              // What gets deleted box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFffeaea),
                  border: Border.all(color: const Color(0xFFffd0d0), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Lang.t('delete_data_title'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _err)),
                  const SizedBox(height: 8),
                  for (final item in [
                    Lang.t('delete_item1'),
                    Lang.t('delete_item2'),
                    Lang.t('delete_item3'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(item,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFc0392b))),
                    ),
                ]),
              ),

              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(Lang.t('enter_pass_confirm'),
                    style: TextStyle(fontSize: 13, color: _dim)),
              ),
              const SizedBox(height: 10),

              // Password field
              Container(
                decoration: BoxDecoration(
                  color: _bg, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _bd, width: 2),
                ),
                child: Row(children: [
                  const SizedBox(width: 13),
                  const Text('🔑', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _delPassCtrl,
                    obscureText: !_delPassVisible,
                    decoration: InputDecoration(
                      border: InputBorder.none, hintText: Lang.t('your_password_hint'),
                      isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 13),
                    ),
                    style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
                  )),
                  IconButton(
                    onPressed: () => setState(() => _delPassVisible = !_delPassVisible),
                    icon: Icon(_delPassVisible ? Icons.visibility_off : Icons.visibility,
                        color: _dim, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ]),
              ),

              if (_errDelPass != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_errDelPass!,
                      style: const TextStyle(fontSize: 12, color: _err)),
                ),
              ],

              const SizedBox(height: 16),

              // Cancel + Delete buttons
              Row(children: [
                // Cancel
                Expanded(child: GestureDetector(
                  onTap: () {
                    _delPassCtrl.clear();
                    setState(() {
                      _showDeletePopup = false;
                      _errDelPass = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _p, width: 2),
                    ),
                    child: Center(child: Text(Lang.t('cancel_btn'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _p))),
                  ),
                )),
                const SizedBox(width: 10),
                // Delete
                Expanded(child: GestureDetector(
                  onTap: _deleting ? null : _deleteAccount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _deleting ? null
                          : const LinearGradient(colors: [Color(0xFFc0392b), _err]),
                      color: _deleting ? Colors.grey.shade300 : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: _deleting
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(Lang.t('delete_btn'),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                              color: Colors.white))),
                  ),
                )),
              ]),
            ]),
          ),
        )),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFd4ede8))),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: Row(children: [
        _navBtn('🎟️', Lang.t('nav_book'),  () => Navigator.pushReplacementNamed(context, '/patient-home'), active: false),
        _navBtn('📊', Lang.t('nav_live'), () => Navigator.pushReplacementNamed(context, '/patient-live'), active: false),
        _navBtn('👤', Lang.t('nav_profile'),   null, active: true),
      ]),
    );
  }

  Widget _navBtn(String icon, String label, VoidCallback? onTap, {bool active = false}) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: active ? _p : _dim)),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 20 : 0, height: 3,
            decoration: BoxDecoration(color: _p, borderRadius: BorderRadius.circular(2)),
          ),
        ]),
      ),
    ));
  }

  // ════════════════════════════════════════════════════════
  //  REUSABLE FIELD WIDGETS
  // ════════════════════════════════════════════════════════
  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _bd),
      boxShadow: [BoxShadow(color: _p.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
  );

  Widget _field({
    required TextEditingController controller,
    required String icon, required String hint,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization caps = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    return _FocusBorderBox(focusColor: _pl, borderColor: _bd,
      child: Row(children: [
        const SizedBox(width: 13),
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller, keyboardType: keyboard,
          textCapitalization: caps, onChanged: onChanged,
          decoration: InputDecoration(border: InputBorder.none, hintText: hint,
              isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 13)),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
        )),
        const SizedBox(width: 13),
      ]),
    );
  }

  Widget _gmailField() => _FocusBorderBox(focusColor: _pl, borderColor: _bd,
    child: Row(children: [
      const SizedBox(width: 13),
      const Text('✉️', style: TextStyle(fontSize: 15)),
      const SizedBox(width: 8),
      Expanded(child: TextField(
        controller: _eGmail,
        keyboardType: TextInputType.emailAddress,
        onChanged: (v) {
          final c = v.replaceAll(RegExp(r'@.*'), '').toLowerCase();
          if (c != v) _eGmail.value = _eGmail.value.copyWith(
              text: c, selection: TextSelection.collapsed(offset: c.length));
        },
        decoration: const InputDecoration(border: InputBorder.none, hintText: 'yourname',
            isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 13)),
        style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
      )),
      const Padding(
        padding: EdgeInsets.only(right: 14),
        child: Text('@gmail.com',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _p)),
      ),
    ]),
  );

  Widget _passField({
    required TextEditingController ctrl, required String hint,
    required bool visible, required VoidCallback onToggle,
  }) {
    return _FocusBorderBox(focusColor: _pl, borderColor: _bd,
      child: Row(children: [
        const SizedBox(width: 13),
        Text(visible ? '🔓' : '🔑', style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: ctrl, obscureText: !visible,
          decoration: InputDecoration(border: InputBorder.none, hintText: hint,
              isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 13)),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
        )),
        IconButton(
          onPressed: onToggle,
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility, color: _dim, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ]),
    );
  }

  Widget _btn({required String label, required VoidCallback onTap, required List<Color> gradient}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  Focus Border Box
// ════════════════════════════════════════════════════════
class _FocusBorderBox extends StatefulWidget {
  final Widget child;
  final Color focusColor, borderColor;
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
