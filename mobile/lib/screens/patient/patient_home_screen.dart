// ============================================================
//  CareQueue — Patient Home Screen (patient_home_screen.dart)
//  Token Booking + Date Selection + Booking Success
//  File location: lib/screens/patient/patient_home_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../../utils/lang.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({Key? key}) : super(key: key);

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {

  void _onLangChange() { if (mounted) setState(() {}); }

  // ── Colors ────────────────────────────────────────────────
  static const Color _p   = Color(0xFF1a6b5a);
  static const Color _pl  = Color(0xFF25a882);
  static const Color _pd  = Color(0xFF0f3d33);
  static const Color _bg  = Color(0xFFf0f7f5);
  static const Color _bd  = Color(0xFFd4ede8);
  static const Color _dim = Color(0xFF6b8f88);
  static const Color _ok  = Color(0xFF27ae60);
  static const Color _err = Color(0xFFe74c3c);
  static const Color _warn= Color(0xFFf39c12);
  static const Color _a   = Color(0xFFff6b35);

  // ── State ─────────────────────────────────────────────────
  int _navIndex = 0; // 0=Book, 1=Live Queue, 2=Profile

  // User info (from session)
  String _patientName  = '';
  String _patientGmail = '';
  String _patientId    = '';
  String _clinicId     = 'CLN-2024-001';
  String _clinicName   = 'Sri Murugan Clinic';

  // Date list from API
  List<Map<String, dynamic>> _dates = [];
  bool _loadingDates = true;

  // Selected date
  Map<String, dynamic>? _selectedDate;
  bool _booking = false;

  // Booking success data
  Map<String, dynamic>? _bookedData; // null = booking page, non-null = success page

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLangChange);
    _loadSession();
  }

  // ── Load logged-in user ───────────────────────────────────
  Future<void> _loadSession() async {
    final s = await Session.load();
    if (s == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }
    setState(() {
      _patientName  = s['name'] ?? '';
      _patientGmail = s['gmail'] ?? '';
      _patientId    = s['patId'] ?? '';
      _clinicId     = s['clinicId'] ?? 'CLN-2024-001';
    });
    _loadDates();
  }

  // ── Load clinic dates from API ────────────────────────────
  // loadBookingDates() from HTML
  Future<void> _loadDates() async {
    setState(() { _loadingDates = true; _selectedDate = null; });
    try {
      final result = await ApiService.getClinicDates(_clinicId);
      if (result['success'] == true) {
        final raw = result['dates'] as List<dynamic>;
        final today = _todayStr();

        // Filter only upcoming dates (>= today), sorted
        final filtered = raw
            .map((d) => {
                  'date':         d['schedule_date'] as String,
                  'openingTime':  d['opening_time'] ?? '',
                  'closingTime':  d['closing_time'] ?? '',
                  'maxPatients':  int.tryParse('${d['max_patients']}') ?? 20,
                  'bookedCount':  int.tryParse('${d['booked_count'] ?? 0}') ?? 0,
                  'alreadyBooked': d['already_booked_by_me'] == true,
                })
            .where((d) => (d['date'] as String).compareTo(today) >= 0)
            .toList()
          ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

        setState(() => _dates = filtered);
      }
    } catch (_) {
      _toast('❌ Dates load ஆகலை. Check server.');
    } finally {
      setState(() => _loadingDates = false);
    }
  }

  // ── Book Token ────────────────────────────────────────────
  // bookToken() from HTML
  Future<void> _bookToken() async {
    if (_selectedDate == null) { _toast('⚠️ Please select a date!'); return; }

    final d     = _selectedDate!;
    final date  = d['date'] as String;

    // Closing time passed? (today only)
    if (date == _todayStr() && (d['closingTime'] as String).isNotEmpty) {
      if (_isClosingTimePassed(d['closingTime'] as String)) {
        _toast('⏰ Booking closed! Clinic closing time முடிஞ்சுவிட்டது.'); return;
      }
    }

    // Full check
    final booked  = d['bookedCount'] as int;
    final maxPats = d['maxPatients'] as int;
    if (booked >= maxPats) { _toast('❌ Full! இந்த date-ல் slot இல்லை.'); return; }

    setState(() => _booking = true);
    try {
      final result = await ApiService.bookToken(
        patientId: 0, // Server side-ல் gmail-ல் identify பண்ணலாம்
        clinicId:  _clinicId,
        date:      date,
      );

      if (result['success'] != true) {
        _toast('❌ ${result['message'] ?? 'Booking failed!'}');
        return;
      }

      final token     = result['token_number'] ?? result['token'] ?? '—';
      final dateLabel = _formatDate(date);

      setState(() {
        _bookedData = {
          'token':      'T-${token.toString().padLeft(2, '0')}',
          'name':       _patientName,
          'patId':      _patientId,
          'date':       dateLabel,
          'clinicName': _clinicName,
          'rawDate':    date,
        };
        _selectedDate = null;
      });
      _toast('🎉 Token booked!');
    } catch (_) {
      _toast('❌ Server error! Try again.');
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  bool _isClosingTimePassed(String closingTime) {
    try {
      final parts  = closingTime.trim().split(' ');
      final ampm   = parts.length > 1 ? parts[1].toUpperCase() : '';
      final hm     = parts[0].split(':');
      int hour     = int.parse(hm[0]);
      int minute   = hm.length > 1 ? int.parse(hm[1]) : 0;
      if (ampm == 'PM' && hour != 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      final closeMinutes = hour * 60 + minute;
      final now = DateTime.now();
      final nowMinutes  = now.hour * 60 + now.minute;
      return nowMinutes >= closeMinutes;
    } catch (_) {
      return false;
    }
  }

  // Booking opens 3 days before clinic date
  bool _isBookingOpen(String dateStr) {
    final today    = DateTime.now();
    final target   = DateTime.parse(dateStr);
    final diffDays = target.difference(DateTime(today.year, today.month, today.day)).inDays;
    return diffDays >= 0 && diffDays <= 3;
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
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
    // Show booking success page if token booked
    if (_bookedData != null) return _buildBookingSuccess();

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
        _buildBottomNav(),
      ]),
    );
  }

  // ── Header (.hdr) ─────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(bottom: false, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFd4ede8))),
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          // Title
          Expanded(
            child: Text(Lang.t('available_dates'),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700,
                    color: Color(0xFF1a2e2a))),
          ),
          // 🌐 Language Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFe8f5f1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _pl.withOpacity(0.3)),
            ),
            child: ValueListenableBuilder<AppLang>(
              valueListenable: langNotifier,
              builder: (_, cur, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: AppLang.values.map((lang) {
                  final active = cur == lang;
                  final label  = lang == AppLang.en ? 'EN'
                               : lang == AppLang.ta ? 'த' : 'සි';
                  return GestureDetector(
                    onTap: () => Lang.set(lang),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? _p : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(label,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _p,
                        )),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Patient name pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _p, borderRadius: BorderRadius.circular(20)),
            child: Text(
              _patientName.isEmpty ? 'Patient' : _patientName.split(' ')[0],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ]),
      )),
    );
  }

  // ── Body ─────────────────────────────────────────────────
  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadDates,
      color: _p,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Banner
          _buildBanner(),
          const SizedBox(height: 14),

          // Date cards
          _loadingDates ? _buildLoading() : _buildDateList(),

          // Selected date confirm section
          if (_selectedDate != null) ...[
            const SizedBox(height: 14),
            _buildConfirmSection(),
          ],

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Banner (.banner) ──────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_p, _pl]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const Text('📅', style: TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
         Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Lang.t('dates_header'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            SizedBox(height: 3),
            Text(Lang.t('dates_subtitle'),
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        )),
      ]),
    );
  }

  // ── Loading ───────────────────────────────────────────────
  Widget _buildLoading() {
    return  Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Column(children: [
        CircularProgressIndicator(color: _p, strokeWidth: 2.5),
        SizedBox(height: 12),
        Text(Lang.t('loading'), style: TextStyle(color: _dim, fontSize: 14)),
      ])),
    );
  }

  // ── Date List ─────────────────────────────────────────────
  Widget _buildDateList() {
    if (_dates.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          const Text('📅', style: TextStyle(fontSize: 36)),
          SizedBox(height: 10),
          Text(Lang.t('no_dates_title'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _dim)),
          SizedBox(height: 6),
          Text('$_clinicName — ${Lang.t("no_dates_sub")}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );
    }

    return Column(
      children: _dates.map((d) => _buildDateCard(d)).toList(),
    );
  }

  // ── Date Card ─────────────────────────────────────────────
  Widget _buildDateCard(Map<String, dynamic> d) {
    final dateStr     = d['date'] as String;
    final booked      = d['bookedCount'] as int;
    final maxP        = d['maxPatients'] as int;
    final openTime    = d['openingTime'] as String;
    final closeTime   = d['closingTime'] as String;
    final dateLabel   = _formatDate(dateStr);
    final today       = _todayStr();

    final isFull      = booked >= maxP;
    final bookingOpen = _isBookingOpen(dateStr);
    final closedToday = dateStr == today && closeTime.isNotEmpty && _isClosingTimePassed(closeTime);
    final isSelected  = _selectedDate?['date'] == dateStr;
    final alreadyBooked = d['alreadyBooked'] == true;

    // Status logic (exact from HTML JS)
    Color borderColor;
    String statusText;
    Color statusBg;
    Color statusColor;
    bool clickable = false;

    if (alreadyBooked) {
      borderColor = _p; statusText = Lang.t('already_booked');
      statusBg = const Color(0xFFe8f5f0); statusColor = _p;
    } else if (isFull) {
      borderColor = _err; statusText = Lang.t('full');
      statusBg = const Color(0xFFffeaea); statusColor = _err;
    } else if (closedToday) {
      borderColor = Color(0xFFdddddd); statusText = Lang.t('booking_closed');
      statusBg = const Color(0xFFf5f5f5); statusColor = const Color(0xFF999999);
    } else if (!bookingOpen) {
      borderColor = const Color(0xFFdddddd);
      statusText = Lang.t('opens_later');
      statusBg = const Color(0xFFfff8e1); statusColor = _warn;
    } else {
      borderColor = _pl; statusText = Lang.t('booking_open');
      statusBg = const Color(0xFFe8f5f0); statusColor = _p;
      clickable = true;
    }

    if (isSelected) borderColor = _p;

    return GestureDetector(
      onTap: clickable ? () => setState(() => _selectedDate = d) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFe8f5f0) : Colors.white,
          border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Date + Status badge
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateLabel, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1a2e2a))),
              const SizedBox(height: 3),
              Text('🏥 $_clinicName',
                  style: const TextStyle(fontSize: 12, color: _dim)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg, borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          const SizedBox(height: 10),

          // Opening/Closing time + booked count
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (openTime.isNotEmpty)
              _timeBadge('🟢 $openTime', const Color(0xFFe8f8ef), _ok),
            if (openTime.isNotEmpty)
              const Text('→', style: TextStyle(color: _dim, fontSize: 12)),
            if (closeTime.isNotEmpty)
              _timeBadge('🔴 $closeTime', const Color(0xFFffeaea), _err),
            Text('· 👥 ${Lang.t("max")}: $maxP · ✅ $booked ${Lang.t("booked_count")}',
                style: const TextStyle(fontSize: 12, color: _dim)),
          ]),
        ]),
      ),
    );
  }

  Widget _timeBadge(String text, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );

  // ── Confirm Section (after date selected) ─────────────────
  Widget _buildConfirmSection() {
    final d         = _selectedDate!;
    final dateLabel = _formatDate(d['date'] as String);
    final booked    = d['bookedCount'] as int;
    final openTime  = d['openingTime'] as String;
    final closeTime = d['closingTime'] as String;

    return Column(children: [
      // Selected info card (green gradient)
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_p, _pl]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Lang.t('selected'),
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 4),
          Text(dateLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            '${openTime.isNotEmpty ? "🟢 $openTime → " : ""}🔴 $closeTime · 👥 $booked booked',
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Book button
      GestureDetector(
        onTap: _booking ? null : _bookToken,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_p, _pl]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _p.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Center(child: _booking
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(Lang.t('book_btn'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
      ),
    ]);
  }

  // ── Bottom Nav (.bnav) ────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFd4ede8))),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: Row(children: [
        _navBtn(0, '🎟️', Lang.t('nav_book')),
        _navBtn(1, '📊', Lang.t('nav_live')),
        _navBtn(2, '👤', Lang.t('nav_profile')),
      ]),
    );
  }

  Widget _navBtn(int index, String icon, String label) {
    final active = index == 0; // Book is always active on this screen
    return Expanded(child: GestureDetector(
      onTap: () {
        if (index == 1) { Navigator.pushReplacementNamed(context, '/patient-live'); return; }
        if (index == 2) { Navigator.pushReplacementNamed(context, '/patient-profile'); return; }
        // index == 0 → already here
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? _p : _dim,
          )),
          const SizedBox(height: 2),
          // Active dot
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
  //  BOOKING SUCCESS SCREEN  (s-booked in HTML)
  // ════════════════════════════════════════════════════════
  Widget _buildBookingSuccess() {
    final data      = _bookedData!;
    final token     = data['token']     as String;
    final name      = data['name']      as String;
    final patId     = data['patId']     as String;
    final date      = data['date']      as String;
    final clinic    = data['clinicName']as String;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Header
        Container(
          color: Colors.white,
          child: SafeArea(bottom: false, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFd4ede8))),
            ),
            child: Center(
              child: Text(Lang.t('booking_confirmed'),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF1a2e2a))),
            ),
          )),
        ),

        // Body
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 4),

            // Token card (.tok-ok)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_pd, _p]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(children: [
                Text(Lang.t('your_token'),
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
                const SizedBox(height: 6),
                // Big token number
                Text(token,
                    style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800,
                        color: Colors.white, height: 1)),
                const SizedBox(height: 8),
                Text(name,
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 5),
                Text(date,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
              ]),
            ),

            const SizedBox(height: 14),

            // Alert box (.alrt)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFfff8f0),
                border: Border.all(color: const Color(0xFFffe0cc), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🔔', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Lang.t('alert_set'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _a)),
                  SizedBox(height: 3),
                  Text(Lang.t('alert_msg'),
                      style: const TextStyle(fontSize: 12, color: _dim)),
                ])),
              ]),
            ),

            const SizedBox(height: 14),

            // Summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _bd),
                boxShadow: [BoxShadow(color: _p.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Lang.t('summary'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: _dim, letterSpacing: 1)),
                SizedBox(height: 14),
                _summaryRow(Lang.t('token_label'),      token,    bold: true, valueColor: _p),
                _summaryRow(Lang.t('name_label2'),       name),
                _summaryRow(Lang.t('patient_id_label2'), patId),
                _summaryRow(Lang.t('date_label'),       date),
                _summaryRow(Lang.t('clinic_label'),     clinic),
                _summaryRow(Lang.t('status_label'),     Lang.t('status_confirmed'), valueColor: _ok),
              ]),
            ),

            const SizedBox(height: 14),

            // Live Queue button
            _btn(
              label: Lang.t('live_queue_check'),
              gradient: const [_p, _pl],
              onTap: () {
                setState(() => _bookedData = null);
                Navigator.pushNamed(context, '/patient-live');
              },
            ),
            const SizedBox(height: 10),

            // New Booking button
            GestureDetector(
              onTap: () => setState(() { _bookedData = null; _loadDates(); }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _p, width: 2),
                ),
                child: Center(child: Text(Lang.t('new_booking'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _p))),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        )),
      ]),
    );
  }

  // Summary row helper
  Widget _summaryRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _dim)),
        Text(value, style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: valueColor ?? const Color(0xFF1a2e2a),
        )),
      ]),
    );
  }

  // Gradient button helper
  Widget _btn({required String label, required List<Color> gradient, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Center(child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
      ),
    );
  }
}
