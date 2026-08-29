// ============================================================
//  CareQueue — Patient Live Queue Screen
//  My Bookings List + Live Queue Detail view
//  File location: lib/screens/patient/patient_live_queue_screen.dart
//  HTML: #s-pat-live → showLQCards() + showLQDetail()
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../../utils/lang.dart';

class PatientLiveQueueScreen extends StatefulWidget {
  const PatientLiveQueueScreen({Key? key}) : super(key: key);
  @override
  State<PatientLiveQueueScreen> createState() => _PatientLiveQueueScreenState();
}

class _PatientLiveQueueScreenState extends State<PatientLiveQueueScreen> {

  void _onLangChange() { if (mounted) setState(() {}); }

  // ── Colors ────────────────────────────────────────────────
  static const Color _p    = Color(0xFF1a6b5a);
  static const Color _pl   = Color(0xFF25a882);
  static const Color _pd   = Color(0xFF0f3d33);
  static const Color _bg   = Color(0xFFf0f7f5);
  static const Color _bd   = Color(0xFFd4ede8);
  static const Color _dim  = Color(0xFF6b8f88);
  static const Color _ok   = Color(0xFF27ae60);
  static const Color _err  = Color(0xFFe74c3c);
  static const Color _warn = Color(0xFFf39c12);
  static const Color _a    = Color(0xFFff6b35);

  // ── State ─────────────────────────────────────────────────
  // View: 'list' = My Bookings, 'detail' = Live Queue detail
  String _view = 'list';

  // Session
  String _patientGmail = '';
  String _clinicId     = 'CLN-2024-001';
  String _clinicName   = 'Sri Murugan Clinic';

  // My bookings list
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingList = true;

  // Selected booking for detail view
  Map<String, dynamic>? _selectedBooking;

  // Live queue detail data
  int  _currentToken = 1;   // liveCur from doctor side
  List<Map<String, dynamic>> _liveQueue = [];
  bool _loadingDetail = false;

  // Auto-refresh timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLangChange);
    _loadSession();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    langNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  // ── Load session ──────────────────────────────────────────
  Future<void> _loadSession() async {
    final s = await Session.load();
    if (s == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }
    setState(() {
      _patientGmail = s['gmail'] ?? '';
      _clinicId     = s['clinicId'] ?? 'CLN-2024-001';
    });
    await _loadMyBookings();
  }

  // ════════════════════════════════════════════════════════
  //  LOAD MY BOOKINGS  —  showLQCards() from HTML
  // ════════════════════════════════════════════════════════
  Future<void> _loadMyBookings() async {
    setState(() => _loadingList = true);
    try {
      // Get bookings from API
      final result = await ApiService.getMyBookings(0);
      if (result['success'] == true) {
        final raw   = result['bookings'] as List;
        final today = _todayStr();

        // Filter: ONLY show active bookings
        // → Past dates → ALWAYS hide
        // → Today done/skipped → hide
        // → Future dates → show
        // → Today waiting/your-turn → show
        final filtered = raw.where((b) {
          final date   = (b['schedule_date'] ?? '') as String;
          final status = (b['status'] ?? 'waiting') as String;

          if (date.isEmpty) return false;
          if (date.compareTo(today) < 0) return false; // past → hide
          if (date == today && (status == 'done' || status == 'skipped')) return false; // today done → hide

          return true;
        }).toList();

        final sorted = filtered.map((b) => {
          'token':       b['token_number'] is int
              ? 'T-${b['token_number'].toString().padLeft(2,'0')}'
              : '${b['token_number']}',
          'date':        b['schedule_date'] as String,
          'clinicId':    b['clinic_id'] as String,
          'clinicName':  b['clinic_name'] ?? _clinicName,
          'status':      b['status'] ?? 'waiting',
          'openingTime': b['opening_time'] ?? '',
          'closingTime': b['closing_time'] ?? '',
          'bookingId':   b['id'],
        }).toList()
          ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

        setState(() => _bookings = sorted);
      }
    } catch (_) {
      _toast('❌ Bookings could not be loaded.');
    } finally {
      setState(() => _loadingList = false);
    }
  }

  // ════════════════════════════════════════════════════════
  //  SHOW LIVE QUEUE DETAIL  —  showLQDetail() from HTML
  // ════════════════════════════════════════════════════════
  Future<void> _showDetail(Map<String, dynamic> booking) async {
    setState(() {
      _view            = 'detail';
      _selectedBooking = booking;
      _loadingDetail   = true;
    });

    await _refreshDetail();

    // Auto-refresh every 15s when in detail view
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_view == 'detail') _refreshDetail();
    });
  }

  Future<void> _refreshDetail() async {
    if (_selectedBooking == null) return;
    final b      = _selectedBooking!;
    final cid    = b['clinicId'] as String;
    final date   = b['date'] as String;

    try {
      final result = await ApiService.getLiveQueue(cid, date);
      if (result['success'] == true) {
        final queue = (result['queue'] as List).map((q) => {
          'token':  q['token_number'] is int
              ? 'T-${q['token_number'].toString().padLeft(2,'0')}'
              : '${q['token_number']}',
          'name':   q['patient_name'] ?? '—',
          'status': q['status'] ?? 'waiting',
        }).toList();

        // Find current token = first waiting (doctor's position)
        // Or last done token
        int cur = 1;
        for (final q in queue) {
          if (q['status'] == 'done' || q['status'] == 'skipped') {
            final n = int.tryParse((q['token'] as String).replaceAll('T-','')) ?? 0;
            if (n >= cur) cur = n + 1;
          }
        }
        // If a 'waiting' item exists and comes after done ones, cur stays
        // check if any done exists
        final hasDone = queue.any((q) => q['status'] == 'done');
        if (!hasDone) cur = 1;

        setState(() {
          _liveQueue     = queue;
          _currentToken  = cur;
          _loadingDetail = false;
        });
      }
    } catch (_) {
      setState(() => _loadingDetail = false);
    }
  }

  // Back to list
  void _goBack() {
    _refreshTimer?.cancel();
    setState(() { _view = 'list'; _selectedBooking = null; });
  }

  // ── Helpers ───────────────────────────────────────────────
  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  String _formatDate(String d, {bool long = false}) {
    try {
      final dt = DateTime.parse(d);
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const months = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
      const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      const dShort = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      if (long) return '${days[dt.weekday-1]}, ${dt.day} ${months[dt.month-1]} ${dt.year}';
      return '${dShort[dt.weekday-1]}, ${dt.day} ${mo[dt.month-1]}';
    } catch (_) { return d; }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

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
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _view == 'list'
              ? _buildListBody()
              : _buildDetailBody(),
        ),
        _buildBottomNav(),
      ]),
    );
  }

  // ── Header (.hdr) ─────────────────────────────────────────
  Widget _buildHeader() {
    final title = _view == 'list'
        ? Lang.t('my_bookings')
        : _formatDate(_selectedBooking?['date'] ?? '');

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
          // Back / Home button
          GestureDetector(
            onTap: _view == 'list'
                ? () => Navigator.pushReplacementNamed(context, '/patient-home')
                : _goBack,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('‹', style: TextStyle(fontSize: 22, color: Color(0xFF1a2e2a)))),
            ),
          ),
          const SizedBox(width: 12),

          // Title (.htitle)
          Expanded(child: Text(title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF1a2e2a)))),

          // 🌐 Language Switcher
          _buildLangSwitcher(),
          const SizedBox(width: 8),

          // LIVE indicator (.live-ind)
          Row(children: [
            _LiveDot(),
            const SizedBox(width: 5),
            const Text('LIVE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ok)),
          ]),
        ]),
      )),
    );
  }

  // ── Language Switcher helper ──────────────────────────────
  Widget _buildLangSwitcher() {
    return ValueListenableBuilder<AppLang>(
      valueListenable: langNotifier,
      builder: (_, cur, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFe8f5f1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF25a882).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: AppLang.values.map((lang) {
            final active = cur == lang;
            final label  = lang == AppLang.en ? 'EN' : lang == AppLang.ta ? 'த' : 'සි';
            return GestureDetector(
              onTap: () => Lang.set(lang),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: active ? _p : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(label,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _p,
                  )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  LIST BODY  —  showLQCards()
  // ════════════════════════════════════════════════════════
  Widget _buildListBody() {
    if (_loadingList) {
      return  Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _p, strokeWidth: 2.5),
          SizedBox(height: 12),
          Text(Lang.t('loading'), style: TextStyle(color: _dim, fontSize: 14)),
        ],
      ));
    }

    if (_bookings.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('📋', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text(Lang.t('no_booking_title'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _dim)),
        SizedBox(height: 8),
        Text(Lang.t('no_bookings'),
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/patient-home'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_p, _pl]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(Lang.t('book_token_btn'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadMyBookings,
      color: _p,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (_, i) => _buildBookingCard(_bookings[i]),
      ),
    );
  }

  // ── Booking Card (.lqcard) ────────────────────────────────
  Widget _buildBookingCard(Map<String, dynamic> b) {
    final today     = _todayStr();
    final date      = b['date'] as String;
    final token     = b['token'] as String;
    final clinic    = b['clinicName'] as String;
    final isToday   = date == today;
    final isPast    = date.compareTo(today) < 0;
    final myN       = int.tryParse(token.replaceAll('T-', '')) ?? 0;
    final curN      = isToday ? _currentToken : 0;
    final ahead     = isToday ? (myN - curN).clamp(0, 999) : 0;
    final isDone    = isToday && myN < curN;

    // Status logic (exact from HTML)
    String sText; Color sBg, sColor, bColor;
    if (isPast || isDone) {
      sText = Lang.t('completed'); sBg = Color(0xFFe8f8ef);
      sColor = _ok; bColor = _ok;
    } else if (isToday && ahead == 0) {
      sText = Lang.t('your_turn_status'); sBg = Color(0xFFffeaea);
      sColor = _err; bColor = _err;
    } else if (isToday) {
      sText = '~${ahead * 5} min'; sBg = const Color(0xFFe8f5f0);
      sColor = _p; bColor = _pl;
    } else {
      sText = Lang.t('upcoming_status'); sBg = Color(0xFFfff8e1);
      sColor = _warn; bColor = const Color(0xFFdddddd);
    }

    return GestureDetector(
      onTap: !isPast ? () => _showDetail(b) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: bColor, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top: date + status badge
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_formatDate(date, long: true),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: Color(0xFF1a2e2a))),
              const SizedBox(height: 3),
              Text('🏥 $clinic',
                  style: const TextStyle(fontSize: 12, color: _dim)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
              child: Text(sText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sColor)),
            ),
          ]),

          const SizedBox(height: 12),

          // 3 stat boxes: Your Token / Now / Ahead
          Row(children: [
            _statMini(Lang.t('your_token'), token, _p),
            SizedBox(width: 8),
            _statMini(Lang.t('now_label'), isToday ? 'T-${_pad(curN)}' : '—', _ok),
            SizedBox(width: 8),
            _statMini(Lang.t('ahead_label'), (isToday && !isDone) ? '$ahead' : '—', _a),
          ]),

          if (!isPast) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(Lang.t('tap_live_queue'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _p)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _statMini(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _dim)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );

  // ════════════════════════════════════════════════════════
  //  DETAIL BODY  —  showLQDetail() from HTML
  // ════════════════════════════════════════════════════════
  Widget _buildDetailBody() {
    if (_loadingDetail) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _p, strokeWidth: 2.5),
          SizedBox(height: 12),
          Text(Lang.t('loading'), style: TextStyle(color: _dim)),
        ],
      ));
    }

    final b       = _selectedBooking!;
    final token   = b['token'] as String;
    final date    = b['date'] as String;
    final clinic  = b['clinicName'] as String;
    final myN     = int.tryParse(token.replaceAll('T-', '')) ?? 0;
    final curN    = _currentToken;
    final ahead   = (myN - curN).clamp(0, 999);
    final dateLabel = _formatDate(date, long: true);

    return RefreshIndicator(
      onRefresh: _refreshDetail,
      color: _p,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: [

          // ── .qnow — green "Currently Calling" block ───────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_ok, Color(0xFF2ecc71)]),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            child: Column(children: [
              // .qnow-l
              Text(Lang.t('currently_calling'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.8), letterSpacing: 1)),
              const SizedBox(height: 6),
              // .qnow-n — big current token
              Text('T-${_pad(curN)}',
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800,
                      color: Colors.white, height: 1)),
              const SizedBox(height: 4),
              Text('$dateLabel · $clinic',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
            ]),
          ),

          // ── .qmine — orange "Your Token + Ahead" bar ─────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_a, Color(0xFFff8c5a)]),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Lang.t('your_token'),
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                  // .qmine-n
                  Text(token,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                          color: Colors.white, height: 1.1)),
                ]),
                // .qwait — ahead count box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    // .qwait-n
                    Text('$ahead',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    // .qwait-l
                    Text(Lang.t('ahead_label'),
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                  ]),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Alert box (.alrt) ────────────────────────
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFfff8f0),
                  border: Border.all(color: const Color(0xFFffe0cc), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('⏱️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      ahead == 0 ? Lang.t('your_turn_alert') : '~${ahead * 5} ${Lang.t("wait_alert")}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _a),
                    ),
                    SizedBox(height: 3),
                    Text(Lang.t('alert_ready'),
                        style: TextStyle(fontSize: 12, color: _dim)),
                  ])),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Queue Status Card ─────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _bd),
                  boxShadow: [BoxShadow(color: _p.withOpacity(0.1),
                      blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Lang.t('queue_status'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: _dim, letterSpacing: 1)),
                  const SizedBox(height: 12),

                  // Show tokens from current to myN+1
                  ..._buildQueueRows(curN, myN),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Refresh button (.btn.btn-a — orange) ──────
              GestureDetector(
                onTap: () async {
                  setState(() => _loadingDetail = true);
                  await _refreshDetail();
                  _toast(Lang.t('refreshed'));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_a, Color(0xFFff8c5a)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: _a.withOpacity(0.3),
                        blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Text(Lang.t('refresh_btn'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                          color: Colors.white))),
                ),
              ),

              const SizedBox(height: 10),

              // Auto-refresh hint
              Center(
                child: Text('${Lang.t("auto_refresh")} · ${_liveQueue.where((q) => q['status'] != 'skipped').length} ${Lang.t("total_tokens")}',
                    style: const TextStyle(fontSize: 12, color: _dim)),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Queue rows (from curN to myN+1) ──────────────────────
  List<Widget> _buildQueueRows(int curN, int myN) {
    final rows = <Widget>[];
    final end  = myN + 1;

    for (int i = curN; i <= end; i++) {
      final tokenStr = 'T-${_pad(i)}';
      final isMe     = i == myN;
      final isCur    = i == curN;
      final aheadN   = (i - curN).clamp(0, 999);

      // Pill text + colors
      String pillText; Color pillBg, pillColor;
      if (isCur) {
        pillText = Lang.t('now_label'); pillBg = Color(0xFFe8f8ef); pillColor = _ok;
      } else if (isMe) {
        pillText = '~${aheadN * 5} min'; pillBg = const Color(0xFFe8f5f0); pillColor = _p;
      } else {
        pillText = Lang.t('status_waiting'); pillBg = Colors.transparent; pillColor = _dim;
      }

      rows.add(Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFe8f5f0) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMe ? '$tokenStr ${Lang.t("you_label")}' : tokenStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w500,
                color: isMe ? _p : const Color(0xFF1a2e2a),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
              child: Text(pillText,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pillColor)),
            ),
          ],
        ),
      ));
    }
    return rows;
  }

  // ── Bottom Nav ────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFd4ede8))),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: Row(children: [
        _navBtn('🎟️', Lang.t('nav_book'), () => Navigator.pushReplacementNamed(context, '/patient-home'), active: false),
        _navBtn('📊', Lang.t('nav_live'), null, active: true),
        _navBtn('👤', Lang.t('nav_profile'), () => Navigator.pushReplacementNamed(context, '/patient-profile'), active: false),
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
          Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? _p : _dim,
          )),
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
}

// ════════════════════════════════════════════════════════
//  LIVE DOT  —  CSS .ldot + @keyframes ping
//  Pulsing green dot indicator
// ════════════════════════════════════════════════════════
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _anim = Tween<double>(begin: 0.3, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: 18, height: 18,
        child: Stack(alignment: Alignment.center, children: [
          // Ping ring
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF27ae60).withOpacity(_anim.value),
            ),
          ),
          // Solid dot
          Container(
            width: 9, height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFF27ae60),
            ),
          ),
        ]),
      ),
    );
  }
}
