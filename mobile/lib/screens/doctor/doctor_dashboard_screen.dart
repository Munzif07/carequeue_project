// ============================================================
//  CareQueue — Doctor Dashboard Screen
//  Doctor Dashboard — Queue and Schedule
//  File location: lib/screens/doctor/doctor_dashboard_screen.dart
//  HTML: #s-doctor + #s-doc-sch
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/emergency_date_change_popup.dart';
import '../../utils/session.dart';
import '../../utils/lang.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({Key? key}) : super(key: key);
  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {

  // ── Colors ────────────────────────────────────────────────
  static const Color _blue1 = Color(0xFF1a2e4a);
  static const Color _blue2 = Color(0xFF2c4a7a);
  static const Color _p     = Color(0xFF1a6b5a);
  static const Color _pl    = Color(0xFF25a882);
  static const Color _bg    = Color(0xFFf0f7f5);
  static const Color _bd    = Color(0xFFd4ede8);
  static const Color _dim   = Color(0xFF6b8f88);
  static const Color _ok    = Color(0xFF27ae60);
  static const Color _err   = Color(0xFFe74c3c);
  static const Color _warn  = Color(0xFFf39c12);
  static const Color _a     = Color(0xFFff6b35);

  // ── Nav Tab: 0=Queue, 1=Schedule ─────────────────────────
  int _tab = 0;

  // ── Session ───────────────────────────────────────────────
  String _docName  = '';
  String _clinicId = '';

  // ── Queue State ───────────────────────────────────────────
  List<Map<String, dynamic>> _queue      = [];
  int    _qIdx        = 0;   // current patient pointer (docQIdx)
  int    _doneCount   = 0;   // docDone
  bool   _loadingQ    = true;
  bool   _isClinicDay = false;
  String _activeDate  = '';
  String _activeDateLabel = 'Loading...';

  // Current token card
  String _curTok  = '—';
  String _curName = '—';
  String _curInfo = '—';
  bool   _markingDone = false;
  bool   _markingSkip = false;

  // Auto-refresh timer
  Timer? _refreshTimer;

  // ── Schedule State ────────────────────────────────────────
  List<Map<String, dynamic>> _scheduleDates = [];
  bool   _loadingSch   = false;
  String _schDate      = '';
  String? _schOpenTime;
  String? _schCloseTime;
  int    _schMaxPat    = 20;
  bool   _addingDate   = false;

  final List<String> _openTimes  = ['6:00 AM','7:00 AM','8:00 AM','9:00 AM','10:00 AM','11:00 AM'];
  final List<String> _closeTimes = ['12:00 PM','2:00 PM','4:00 PM','6:00 PM','8:00 PM','10:00 PM'];

  // Max patients controller
  final _maxCtrl = TextEditingController(text: '20');

  void _onLangChange() { if (mounted) setState(() {}); }

    @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLangChange);
    _loadSession();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _maxCtrl.dispose();
    langNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  // ── Load Session ──────────────────────────────────────────
  Future<void> _loadSession() async {
    final s = await Session.load();
    if (s == null || s['role'] != 'doctor') {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }
    setState(() {
      _docName  = s['name'] ?? 'Doctor';
      _clinicId = s['clinicId'] ?? '';
    });
    await _buildDocQueue();
    // Auto refresh every 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _syncQueue());
  }

  // ── Greeting ──────────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning 👋';
    if (h < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  String _formatDate(String d) {
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${w[dt.weekday-1]}, ${dt.day} ${m[dt.month-1]}';
    } catch (_) { return d; }
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD DOC QUEUE  —  buildDocQueue() from HTML
  // ══════════════════════════════════════════════════════════
  Future<void> _buildDocQueue({bool forceRebuild = true}) async {
    setState(() => _loadingQ = true);
    try {
      final today = _todayStr();

      // Get clinic dates to find active date
      final schResult = await ApiService.getClinicDates(_clinicId);
      List<String> allDates = [];
      if (schResult['success'] == true) {
        allDates = (schResult['dates'] as List)
            .map((d) => d['schedule_date'] as String)
            .toList()
          ..sort();
      }

      // Active date = today if scheduled, else next upcoming
      String? activeDate;
      if (allDates.contains(today)) {
        activeDate = today;
      } else {
        activeDate = allDates.where((d) => d.compareTo(today) > 0).firstOrNull;
      }

      _activeDate  = activeDate ?? '';
      _isClinicDay = activeDate == today;

      // Date label
      if (activeDate == null) {
        _activeDateLabel = 'No upcoming clinic';
      } else if (activeDate == today) {
        _activeDateLabel = 'Today';
      } else {
        _activeDateLabel = _formatDate(activeDate);
      }

      if (activeDate == null) {
        setState(() {
          _queue = []; _qIdx = 0; _doneCount = 0;
          _curTok = '—'; _curName = 'No upcoming clinic';
          _curInfo = 'Please add a date in the Schedule tab';
          _loadingQ = false;
        });
        return;
      }

      // Load queue
      final qResult = await ApiService.getLiveQueue(_clinicId, activeDate);
      if (qResult['success'] == true) {
        final rawQ = (qResult['queue'] as List).map((b) => {
          'id':     b['id'],
          'token':  b['token_number'] is int
              ? 'T-${b['token_number'].toString().padLeft(2,'0')}'
              : '${b['token_number']}',
          'name':   b['patient_name'] ?? '—',
          'patId':  b['patid'] ?? '—',
          'status': b['status'] ?? 'waiting',
        }).toList();

        // Preserve existing status if already working
        if (!forceRebuild && _queue.isNotEmpty) {
          for (final existing in _queue) {
            final match = rawQ.firstWhere(
                (r) => r['token'] == existing['token'],
                orElse: () => <String, dynamic>{});
            if (match.isNotEmpty && existing['status'] != 'waiting') {
              match['status'] = existing['status'];
            }
          }
        }

        setState(() => _queue = rawQ);
        _recalcIdx();
      }
    } catch (_) {
      _toast('❌ Queue load ஆகலை. Check server.');
    } finally {
      setState(() => _loadingQ = false);
      _updateCurrentCard();
    }
  }

  // Only sync new bookings without resetting position
  Future<void> _syncQueue() async {
    if (_activeDate.isEmpty) return;
    try {
      final qResult = await ApiService.getLiveQueue(_clinicId, _activeDate);
      if (qResult['success'] == true) {
        final rawQ = (qResult['queue'] as List).map((b) => {
          'id':     b['id'],
          'token':  b['token_number'] is int
              ? 'T-${b['token_number'].toString().padLeft(2,'0')}'
              : '${b['token_number']}',
          'name':   b['patient_name'] ?? '—',
          'patId':  b['patid'] ?? '—',
          'status': b['status'] ?? 'waiting',
        }).toList();

        // Merge — keep local status, add new entries
        for (final r in rawQ) {
          final ex = _queue.firstWhere(
              (q) => q['token'] == r['token'], orElse: () => <String, dynamic>{});
          if (ex.isEmpty) _queue.add(r);
        }
        _queue.sort((a, b) {
          final at = int.tryParse('${a['token']}'.replaceAll('T-','')) ?? 0;
          final bt = int.tryParse('${b['token']}'.replaceAll('T-','')) ?? 0;
          return at.compareTo(bt);
        });
        if (mounted) setState(() {});
        _updateCurrentCard();
      }
    } catch (_) {}
  }

  void _recalcIdx() {
    _qIdx      = 0;
    _doneCount = 0;
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i]['status'] == 'done') _doneCount++;
      if (_queue[i]['status'] != 'waiting') _qIdx = i + 1;
    }
    // Skip to first waiting
    while (_qIdx < _queue.length && _queue[_qIdx]['status'] != 'waiting') _qIdx++;
  }

  void _updateCurrentCard() {
    if (_queue.isEmpty) {
      setState(() {
        _curTok  = '—';
        _curName = _isClinicDay ? 'No patients today' : 'No bookings yet';
        _curInfo = '—';
      });
      return;
    }
    if (_qIdx < _queue.length) {
      final p = _queue[_qIdx];
      setState(() {
        _curTok  = p['token'] as String;
        _curName = p['name']  as String;
        _curInfo = 'Patient ID: ${p['patId']}';
      });
    } else {
      setState(() {
        _curTok  = '—';
        _curName = 'Queue Complete';
        _curInfo = 'All seen today 🎉';
      });
    }
  }

  // ══════════════════════════════════════════════════════════
  //  MARK DONE  —  markDone() from HTML
  // ══════════════════════════════════════════════════════════
  Future<void> _markDone() async {
    if (!_isClinicDay) { _toast('⚠️ இன்று clinic day இல்லை!'); return; }
    if (_qIdx >= _queue.length) { _toast('⚠️ Queue empty!'); return; }

    final current = _queue[_qIdx];
    setState(() => _markingDone = true);
    try {
      final result = await ApiService.markDone(current['id'] as int);
      if (result['success'] != true) { _toast('❌ ${result['message']}'); return; }

      setState(() {
        _queue[_qIdx]['status'] = 'done';
        _doneCount++;
        _qIdx++;
        while (_qIdx < _queue.length && _queue[_qIdx]['status'] != 'waiting') _qIdx++;
      });
      _updateCurrentCard();
      if (_qIdx >= _queue.length) _toast('🎉 Queue complete!');
      else _toast('✅ Done!');
    } catch (_) {
      _toast('❌ Server error!');
    } finally {
      setState(() => _markingDone = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  MARK SKIP  —  markSkip() from HTML
  // ══════════════════════════════════════════════════════════
  Future<void> _markSkip() async {
    if (!_isClinicDay) { _toast('⚠️ இன்று clinic day இல்லை!'); return; }
    if (_qIdx >= _queue.length) { _toast('⚠️ Queue empty!'); return; }

    final current = _queue[_qIdx];
    setState(() => _markingSkip = true);
    try {
      final result = await ApiService.markSkip(current['id'] as int);
      if (result['success'] != true) { _toast('❌ ${result['message']}'); return; }

      setState(() {
        _queue[_qIdx]['status'] = 'skipped';
        _qIdx++;
        while (_qIdx < _queue.length && _queue[_qIdx]['status'] != 'waiting') _qIdx++;
      });
      _updateCurrentCard();
      _toast('⏭️ Skipped!');
    } catch (_) {
      _toast('❌ Server error!');
    } finally {
      setState(() => _markingSkip = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  ADD DATE  —  addDate() from HTML
  // ══════════════════════════════════════════════════════════
  Future<void> _addDate() async {
    if (_schDate.isEmpty)      { _toast('⚠️ Please select a date!'); return; }
    if (_schOpenTime == null)  { _toast('⚠️ Please select an opening time!'); return; }
    if (_schCloseTime == null) { _toast('⚠️ Please select a closing time!'); return; }

    // Min 3 days ahead
    final selected = DateTime.parse(_schDate);
    final today    = DateTime.now();
    final diff     = selected.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (diff < 3) { _toast('⚠️ Date must be at least 3 days from today'); return; }

    final maxPat = int.tryParse(_maxCtrl.text) ?? 20;
    setState(() => _addingDate = true);
    _toast('⏳ Adding date...');

    try {
      final result = await ApiService.addClinicDate(
        clinicId:    _clinicId,
        date:        _schDate,
        openingTime: _schOpenTime!,
        closingTime: _schCloseTime!,
        maxPatients: maxPat,
      );
      if (result['success'] != true) { _toast('❌ ${result['message']}'); return; }

      setState(() {
        _schDate = ''; _schOpenTime = null; _schCloseTime = null;
        _maxCtrl.text = '20';
      });
      _toast('✅ Date added!');
      await _loadScheduleDates();
    } catch (_) {
      _toast('❌ Server error!');
    } finally {
      setState(() => _addingDate = false);
    }
  }

  // Load scheduled dates list
  Future<void> _loadScheduleDates() async {
    setState(() => _loadingSch = true);
    try {
      final result = await ApiService.getClinicDates(_clinicId);
      if (result['success'] == true) {
        final today = _todayStr();
        setState(() {
          _scheduleDates = (result['dates'] as List)
              .map((d) => {
                    'id':           d['id'],
                    'date':         d['schedule_date'] as String,
                    'openingTime':  d['opening_time'] ?? '',
                    'closingTime':  d['closing_time'] ?? '',
                    'maxPatients':  d['max_patients'] ?? 20,
                    'bookedCount':  d['booked_count'] ?? 0,
                  })
              .where((d) => (d['date'] as String).compareTo(today) >= 0)
              .toList()
            ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
        });
      }
    } catch (_) {
    } finally {
      setState(() => _loadingSch = false);
    }
  }

  // Logout
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
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildNavyHeader(),
        Expanded(child: _tab == 0 ? _buildQueueBody() : _buildScheduleBody()),
        _buildBottomNav(),
      ]),
    );
  }

  // ── Navy Header (.dhdr) ───────────────────────────────────
  Widget _buildNavyHeader() {
    final waitCount  = _queue.where((p) => p['status'] == 'waiting').length;
    final totalCount = _queue.where((p) => p['status'] != 'skipped').length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_blue1, _blue2],
        ),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(children: [

          // .dtop — back + name + clinic ID badge
          Row(children: [
            GestureDetector(
              onTap: _logout,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('‹', style: TextStyle(fontSize: 22, color: Colors.white))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // .dgreet
              Text(_greeting,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
              // .dname
              Text(_tab == 0 ? (_docName.isEmpty ? 'Dr. —' : _docName)
                             : (_docName.isEmpty ? 'Dr. —' : _docName),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
            ])),
            // Clinic ID badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_clinicId,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),

          if (_tab == 0) ...[
            const SizedBox(height: 12),
            // Active date bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Text('📅', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Lang.t('doc_active_queue'),
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65))),
                  Text(_activeDateLabel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            // .dstats — 3 stat boxes
            Row(children: [
              _statBox('$totalCount', 'Total'),
              const SizedBox(width: 10),
              _statBox('$_doneCount', 'Done'),
              const SizedBox(width: 10),
              _statBox('$waitCount', 'Waiting'),
            ]),
          ],

          if (_tab == 1) ...[
            const SizedBox(height: 8),
            Text(Lang.t('doc_schedule'),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
          ],
        ]),
      )),
    );
  }

  Widget _statBox(String num, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(children: [
        // .dsnum
        Text(num, style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
        // .dslbl
        Text(label, style: TextStyle(
            fontSize: 11, color: Colors.white.withOpacity(0.65))),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  QUEUE BODY
  // ══════════════════════════════════════════════════════════
  Widget _buildQueueBody() {
    if (_loadingQ) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _p, strokeWidth: 2.5),
          SizedBox(height: 12),
          Text('⏳ Loading queue...', style: TextStyle(color: _dim)),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: () => _buildDocQueue(forceRebuild: true),
      color: _p,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Current token card (.ctok)
          _buildCurrentTokenCard(),
          const SizedBox(height: 14),
          // Queue list
          _buildQueueList(),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Current Token Card (.ctok) ────────────────────────────
  Widget _buildCurrentTokenCard() {
    final isComplete = _qIdx >= _queue.length && _queue.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _p.withOpacity(0.18), blurRadius: 40, offset: const Offset(0, 8))],
        border: Border.all(color: _bd),
      ),
      child: Column(children: [
        // "Currently Seeing" label (.ctok-l)
        Text(
          isComplete ? '🎉 Queue Complete' : '🔴 Currently Seeing',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: _dim, letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),

        // Big token number (.ctok-n)
        Text(_curTok,
            style: TextStyle(
              fontSize: 72, fontWeight: FontWeight.w900, height: 1,
              color: isComplete ? _ok : _p,
            )),

        // Patient name (.cpt-n)
        Text(_curName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        // Info (.cpt-t)
        Text(_curInfo,
            style: const TextStyle(fontSize: 12, color: _dim)),

        const SizedBox(height: 14),

        // Preview mode banner (non-clinic-day)
        if (!_isClinicDay && _queue.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFfff8e1),
              border: Border.all(color: const Color(0xFFffe082), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Text('👁️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Lang.t('doc_preview_mode'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _warn)),
                const SizedBox(height: 3),
                Text('$_activeDateLabel — ${Lang.t("doc_clinic_day")}',
                    style: const TextStyle(fontSize: 12, color: _dim)),
              ])),
            ]),
          ),

        // Done / Skip buttons (.actbtns) — only on clinic day
        if (_isClinicDay && !isComplete && _queue.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            // ✅ Done button (.bdone)
            Expanded(child: GestureDetector(
              onTap: (_markingDone || _markingSkip) ? null : _markDone,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_ok, Color(0xFF2ecc71)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: _markingDone
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(Lang.t('doc_done_next'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
            )),
            const SizedBox(width: 10),
            // ⏭️ Skip button (.bskip)
            Expanded(child: GestureDetector(
              onTap: (_markingDone || _markingSkip) ? null : _markSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _warn, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: _markingSkip
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _warn))
                  : Text(Lang.t('doc_skip'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _warn))),
              ),
            )),
          ]),
        ],
      ]),
    );
  }

  // ── Queue List (.qlist) ───────────────────────────────────
  Widget _buildQueueList() {
    final waitCount = _queue.where((p) => p['status'] == 'waiting').length;

    return Column(children: [
      // .shdr
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          _isClinicDay ? "Today's Queue" : "Upcoming Queue 👁️",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: _p, borderRadius: BorderRadius.circular(20)),
          child: Text('$waitCount ${Lang.t("doc_patients")}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
      const SizedBox(height: 10),

      if (_queue.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(children: [
            const Text('📋', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(Lang.t('doc_no_queue'),
                style: TextStyle(fontWeight: FontWeight.w800, color: _dim)),
            const SizedBox(height: 6),
            Text(Lang.t('doc_queue_wait'),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        )
      else
        Column(children: _queue.map((p) => _buildQueueItem(p)).toList()),
    ]);
  }

  // ── Queue Item (.qitem) ───────────────────────────────────
  Widget _buildQueueItem(Map<String, dynamic> p) {
    final status   = p['status'] as String;
    final token    = (p['token'] as String).replaceAll('T-', '');
    final isPreview = status == 'waiting' && !_isClinicDay;

    // Colors by status (CSS .waiting .done .skipped .preview)
    Color leftBorder, badgeBg, badgeColor, pillBg, pillColor;
    String pillText;

    if (isPreview) {
      leftBorder = const Color(0xFF64b5f6);
      badgeBg    = const Color(0xFFe3f2fd); badgeColor = const Color(0xFF1565c0);
      pillBg     = const Color(0xFFe3f2fd); pillColor  = const Color(0xFF1565c0);
      pillText   = 'Upcoming';
    } else if (status == 'done') {
      leftBorder = _ok;
      badgeBg    = const Color(0xFFe8f8ef); badgeColor = _ok;
      pillBg     = const Color(0xFFe8f8ef); pillColor  = _ok;
      pillText   = 'Done ✓';
    } else if (status == 'skipped') {
      leftBorder = _warn;
      badgeBg    = const Color(0xFFfff3e0); badgeColor = _warn;
      pillBg     = const Color(0xFFfff3e0); pillColor  = _warn;
      pillText   = 'Absent';
    } else {
      leftBorder = _pl;
      badgeBg    = const Color(0xFFe8f5f0); badgeColor = _p;
      pillBg     = const Color(0xFFe8f5f0); pillColor  = _p;
      pillText   = 'Waiting';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: leftBorder, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(children: [
          // .qbadge — token number circle
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(token,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: badgeColor))),
          ),
          const SizedBox(width: 12),
          // Name + token info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name'] as String,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${p['token']} · ID: ${p['patId']}',
                style: const TextStyle(fontSize: 11, color: _dim)),
          ])),
          // .qpill status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
            child: Text(pillText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pillColor)),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SCHEDULE BODY  (#s-doc-sch)
  // ══════════════════════════════════════════════════════════
  Widget _buildScheduleBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Info alert (.alrt)
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFfff8f0),
            border: Border.all(color: const Color(0xFFffe0cc), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ℹ️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
             Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Lang.t('doc_schedule_title'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _a)),
              SizedBox(height: 3),
              Text(Lang.t('doc_schedule_sub'),
                  style: TextStyle(fontSize: 12, color: _dim)),
            ])),
          ]),
        ),
        const SizedBox(height: 14),

        // Add date card
        _buildAddDateCard(),
        const SizedBox(height: 14),

        // Scheduled dates list
        _buildScheduleList(),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Add Date Card ─────────────────────────────────────────
  Widget _buildAddDateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bd),
        boxShadow: [BoxShadow(color: _p.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Lang.t('doc_add_date_title'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _dim, letterSpacing: 1)),
        const SizedBox(height: 14),

        // Date picker
        const Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final minDate = DateTime.now().add(const Duration(days: 3));
            final picked  = await showDatePicker(
              context: context,
              initialDate: minDate,
              firstDate: minDate,
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: _p, onPrimary: Colors.white),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() => _schDate =
                  '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _bg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _schDate.isEmpty ? _bd : _p, width: 2),
            ),
            child: Row(children: [
              const Text('📅', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                _schDate.isEmpty ? 'Select date' : _formatDate(_schDate),
                style: TextStyle(
                  fontSize: 15, color: _schDate.isEmpty ? Colors.grey : const Color(0xFF1a2e2a),
                  fontWeight: _schDate.isEmpty ? FontWeight.normal : FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Opening time slots (.sch-open-grid)
        Text(Lang.t('doc_opening_time'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 3.2,
          children: _openTimes.map((t) => _timeSlot(t, isOpen: true)).toList(),
        ),
        const SizedBox(height: 14),

        // Closing time slots (.sch-slot-grid)
        Text(Lang.t('doc_closing_time'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 3.2,
          children: _closeTimes.map((t) => _timeSlot(t, isOpen: false)).toList(),
        ),
        const SizedBox(height: 14),

        // Max patients
        Text(Lang.t('doc_max_patients'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _bg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bd, width: 2),
          ),
          child: Row(children: [
            const SizedBox(width: 13),
            const Text('👥', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _maxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none, hintText: '20',
                isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
              style: const TextStyle(fontSize: 15, color: Color(0xFF1a2e2a)),
            )),
          ]),
        ),
        const SizedBox(height: 14),

        // Add button
        GestureDetector(
          onTap: _addingDate ? null : _addDate,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: _addingDate ? null : const LinearGradient(colors: [_p, _pl]),
              color: _addingDate ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _addingDate ? null :
                  [BoxShadow(color: _p.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Center(child: _addingDate
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(Lang.t('doc_add_btn'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
        ),
      ]),
    );
  }

  // Time slot button (.slot)
  Widget _timeSlot(String time, {required bool isOpen}) {
    final isSelected = isOpen
        ? _schOpenTime == time
        : _schCloseTime == time;

    return GestureDetector(
      onTap: () => setState(() {
        if (isOpen) _schOpenTime = time;
        else _schCloseTime = time;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? (isOpen ? _ok : _p) : _bg,
          border: Border.all(
              color: isSelected ? (isOpen ? _ok : _p) : _bd, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text(time,
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : const Color(0xFF1a2e2a),
            ))),
      ),
    );
  }

  // ── Schedule List ─────────────────────────────────────────
  Widget _buildScheduleList() {
    if (_loadingSch) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: _p, strokeWidth: 2)),
      );
    }

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(Lang.t('doc_scheduled_dates'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: _p, borderRadius: BorderRadius.circular(20)),
          child: Text('${_scheduleDates.length}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
      const SizedBox(height: 10),
      if (_scheduleDates.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(children: [
            Text('📅', style: TextStyle(fontSize: 36)),
            SizedBox(height: 10),
            Text(Lang.t('doc_no_dates_yet'),
                style: TextStyle(fontWeight: FontWeight.w800, color: _dim)),
            SizedBox(height: 6),
            Text(Lang.t('doc_add_dates_hint'),
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        )
      else
        Column(children: _scheduleDates.map((d) => _buildSchDateCard(d)).toList()),
    ]);
  }

  Widget _buildSchDateCard(Map<String, dynamic> d) {
    final booked  = d['bookedCount'] as int;
    final maxP    = d['maxPatients'] as int;
    final openT   = d['openingTime'] as String;
    final closeT  = d['closingTime'] as String;
    final label   = _formatDate(d['date'] as String);
    final isFull  = booked >= maxP;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bd),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [
            if (openT.isNotEmpty) _badge('🟢 $openT', const Color(0xFFe8f8ef), _ok),
            if (openT.isNotEmpty) const Text('→', style: TextStyle(color: _dim, fontSize: 12)),
            _badge('🔴 $closeT', const Color(0xFFffeaea), _err),
          ]),
          const SizedBox(height: 4),
          Text('👥 $booked / $maxP patients booked',
              style: TextStyle(fontSize: 12, color: isFull ? _err : _dim,
                  fontWeight: isFull ? FontWeight.w700 : FontWeight.normal)),
        ])),
        if (booked == 0) ...[
          GestureDetector(
            onTap: () => _confirmDeleteDate(d),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFffeaea),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🗑️', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showEmergencyDateChange(
              context,
              clinicId:    _clinicId,
              oldDate:     d['date'] as String,
              bookedCount: booked,
              onSuccess:   _loadScheduleDates,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFfff8e1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('📅', style: TextStyle(fontSize: 16)),
            ),
          ),
        ] else
          GestureDetector(
            onTap: () => showEmergencyDateChange(
              context,
              clinicId:    _clinicId,
              oldDate:     d['date'] as String,
              bookedCount: booked,
              onSuccess:   _loadScheduleDates,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFfff8e1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('📅', style: TextStyle(fontSize: 16)),
            ),
          ),
      ]),
    );
  }

  Future<void> _confirmDeleteDate(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this date?'),
        content: Text(_formatDate(d['date'] as String)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final result = await ApiService.deleteClinicDate(d['id'] as int);
    if (result['success'] == true) {
      _toast('✅ Date deleted');
      _loadScheduleDates();
    } else {
      _toast('❌ ${result['message'] ?? 'Could not delete'}');
    }
  }

  Widget _badge(String t, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );

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
        _navBtn(0, '🏥', Lang.t('doc_tab_queue')),
        _navBtn(1, '📅', Lang.t('doc_tab_schedule')),
        Expanded(child: GestureDetector(
          onTap: _logout,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🚪', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 3),
              Text(Lang.t('logout_btn'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _dim)),
              const SizedBox(height: 5),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _navBtn(int index, String icon, String label) {
    final active = _tab == index;
    return Expanded(child: GestureDetector(
      onTap: () async {
        setState(() => _tab = index);
        if (index == 1 && _scheduleDates.isEmpty) await _loadScheduleDates();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFe8f5f0) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
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
