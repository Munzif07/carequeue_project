// ============================================================
//  CareQueue — Session Utility (session.dart)
//  Login data save/load — SharedPreferences use பண்றோம்
//  File location: lib/utils/session.dart
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class Session {
  // ── Keys ─────────────────────────────────────────────────
  static const _kName     = 'cq_name';
  static const _kGmail    = 'cq_gmail';
  static const _kPatId    = 'cq_patid';
  static const _kClinicId = 'cq_clinic_id';
  static const _kRole     = 'cq_role';    // 'patient' or 'doctor'
  static const _kToken    = 'cq_token';   // JWT token

  // ── Save (after login/register) ──────────────────────────
  static Future<void> save({
    required String name,
    required String gmail,
    required String patId,
    required String clinicId,
    required String role,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName,     name);
    await prefs.setString(_kGmail,    gmail);
    await prefs.setString(_kPatId,    patId);
    await prefs.setString(_kClinicId, clinicId);
    await prefs.setString(_kRole,     role);
    await prefs.setString(_kToken,    token);
  }

  // ── Load ─────────────────────────────────────────────────
  static Future<Map<String, String>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_kRole);
    if (role == null) return null; // Not logged in

    return {
      'name':      prefs.getString(_kName)     ?? '',
      'gmail':     prefs.getString(_kGmail)    ?? '',
      'patId':     prefs.getString(_kPatId)    ?? '',
      'clinicId':  prefs.getString(_kClinicId) ?? '',
      'role':      role,
      'token':     prefs.getString(_kToken)    ?? '',
    };
  }

  // ── Clear (Logout) ───────────────────────────────────────
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── Quick getters ─────────────────────────────────────────
  static Future<String?> get role async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  static Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<bool> get isLoggedIn async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kRole);
  }
}
