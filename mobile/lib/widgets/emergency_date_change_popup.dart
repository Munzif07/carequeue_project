// ============================================================
//  CareQueue — Emergency Date Change Popup Widget
//  Doctor-ஓட Schedule tab-ல் existing date → change
//  HTML: #change-date-popup → confirmChangeDate()
//  Usage: showEmergencyDateChange(context, clinicId, date, bookedCount)
//  File: lib/widgets/emergency_date_change_popup.dart
// ============================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ── Call this from DoctorDashboardScreen Schedule tab ──────
//
// In _buildSchDateCard() widget, add a "📅 Change Date" button:
//   onTap: () => showEmergencyDateChange(
//     context,
//     clinicId:    _clinicId,
//     oldDate:     d['date'],
//     bookedCount: d['bookedCount'],
//     onSuccess:   _loadScheduleDates,
//   );

Future<void> showEmergencyDateChange(
  BuildContext context, {
  required String clinicId,
  required String oldDate,
  required int bookedCount,
  required VoidCallback onSuccess,
}) async {
  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => _EmergencyDateChangeDialog(
      clinicId:    clinicId,
      oldDate:     oldDate,
      bookedCount: bookedCount,
      onSuccess:   onSuccess,
    ),
  );
}

class _EmergencyDateChangeDialog extends StatefulWidget {
  final String clinicId, oldDate;
  final int bookedCount;
  final VoidCallback onSuccess;

  const _EmergencyDateChangeDialog({
    required this.clinicId,
    required this.oldDate,
    required this.bookedCount,
    required this.onSuccess,
  });

  @override
  State<_EmergencyDateChangeDialog> createState() => _EmergencyDateChangeDialogState();
}

class _EmergencyDateChangeDialogState extends State<_EmergencyDateChangeDialog> {

  static const Color _p    = Color(0xFF1a6b5a);
  static const Color _pl   = Color(0xFF25a882);
  static const Color _bd   = Color(0xFFd4ede8);
  static const Color _dim  = Color(0xFF6b8f88);
  static const Color _bg   = Color(0xFFf0f7f5);
  static const Color _warn = Color(0xFFf39c12);

  String  _newDate   = '';
  bool    _changing  = false;
  String? _error;

  String _formatDate(String d) {
    try {
      final dt = DateTime.parse(d);
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const dw = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${dw[dt.weekday-1]}, ${dt.day} ${mo[dt.month-1]} ${dt.year}';
    } catch (_) { return d; }
  }

  Future<void> _pickDate() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _warn, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _newDate =
          '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
    }
  }

  Future<void> _confirmChange() async {
    if (_newDate.isEmpty) {
      setState(() => _error = 'New date select பண்ணுங்கள்!');
      return;
    }
    if (_newDate == widget.oldDate) {
      setState(() => _error = 'Different date select பண்ணுங்கள்!');
      return;
    }

    setState(() { _changing = true; _error = null; });
    try {
      final result = await ApiService.changeClinicDate(
        clinicId: widget.clinicId,
        oldDate:  widget.oldDate,
        newDate:  _newDate,
      );
      if (result['success'] != true) {
        setState(() { _error = result['message'] ?? 'Error!'; _changing = false; });
        return;
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Date changed! Tokens carried over.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF1a2e2a),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        ));
      }
    } catch (_) {
      setState(() { _error = 'Server error!'; _changing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Icon + Title
          const Text('📅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text('Emergency Date Change',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: _warn)),
          const SizedBox(height: 6),
          Text('Already booked patients-ஓட tokens same-a இருக்கும்',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _dim)),

          const SizedBox(height: 14),

          // Current date info box (.warn yellow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFfff8e1),
              border: Border.all(color: const Color(0xFFffe082), width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current Date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _warn)),
              const SizedBox(height: 4),
              Text(_formatDate(widget.oldDate),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${widget.bookedCount} patients booked',
                  style: const TextStyle(fontSize: 12, color: _dim)),
            ]),
          ),

          const SizedBox(height: 14),

          // New date picker
          Align(
            alignment: Alignment.centerLeft,
            child: const Text('New Date *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dim)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _bg,
                border: Border.all(color: _newDate.isEmpty ? _bd : _warn, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Text('📅', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Text(
                  _newDate.isEmpty ? 'Select new date' : _formatDate(_newDate),
                  style: TextStyle(
                    fontSize: 15,
                    color: _newDate.isEmpty ? Colors.grey : const Color(0xFF1a2e2a),
                    fontWeight: _newDate.isEmpty ? FontWeight.normal : FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
          ],

          const SizedBox(height: 14),

          // Info box: tokens carry over
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFe8f5f0),
              border: Border.all(color: _pl, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Booked patients-ஓட tokens carry over aagum',
                    style: TextStyle(fontSize: 12, color: _p)),
                SizedBox(height: 3),
                Text('📱 Patients-ஓட booking date automatically update aagum',
                    style: TextStyle(fontSize: 12, color: _p)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Cancel + Change buttons
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _p, width: 2),
                ),
                child: const Center(child: Text('Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _p))),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: _changing ? null : _confirmChange,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _changing ? null
                      : const LinearGradient(colors: [_warn, Color(0xFFe67e22)]),
                  color: _changing ? Colors.grey.shade300 : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: _changing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('📅 Change',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
            )),
          ]),
        ]),
      ),
    );
  }
}
