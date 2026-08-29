// ============================================================
//  CareQueue — API Service (api_service.dart)
//  Node.js backend-உடன் communicate பண்றோம்
//  File location: lib/services/api_service.dart
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/session.dart';

class ApiService {
  // ── Base URL ──────────────────────────────────────────────
  // Android Emulator: 10.0.2.2
  // Real device (same WiFi): உங்கள் PC IP (e.g. 192.168.1.5)
  static const String baseUrl = 'http://172.24.61.237:3000/api';

  // ── Headers with JWT ─────────────────────────────────────
  static Future<Map<String, String>> _headers() async {
    final token = await Session.token;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ════════════════════════════════════════════════════════
  //  AUTH
  // ════════════════════════════════════════════════════════

  // Patient Login — POST /api/auth/patient/login
  static Future<Map<String, dynamic>> patientLogin(
      String gmail, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/patient/login'),
      headers: await _headers(),
      body: jsonEncode({'gmail': gmail, 'password': password}),
    );
    return _parse(res);
  }

  // Patient Register — POST /api/auth/patient/register
  static Future<Map<String, dynamic>> patientRegister({
    required String name,
    required String nic,
    required String phone,
    required String gmail,
    required String patId,
    required String clinicId,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/patient/register'),
      headers: await _headers(),
      body: jsonEncode({
        'name':      name,
        'nic':       nic,
        'phone':     phone,
        'gmail':     gmail,
        'patid':     patId,
        'clinic_id': clinicId,
        'password':  password,
      }),
    );
    return _parse(res);
  }

  // Doctor Login — POST /api/auth/doctor/login
  static Future<Map<String, dynamic>> doctorLogin(
      String clinicId, String password, String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/doctor/login'),
      headers: await _headers(),
      body: jsonEncode({
        'clinic_id': clinicId,
        'password':  password,
        'name':      name,
      }),
    );
    return _parse(res);
  }

  // ════════════════════════════════════════════════════════
  //  SCHEDULE
  // ════════════════════════════════════════════════════════

  // Get clinic dates — GET /api/schedule/dates/:clinic_id
  static Future<Map<String, dynamic>> getClinicDates(String clinicId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/schedule/dates/$clinicId'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // Add date — POST /api/schedule/add
  static Future<Map<String, dynamic>> addClinicDate({
    required String clinicId,
    required String date,
    required String openingTime,
    required String closingTime,
    required int maxPatients,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/schedule/add'),
      headers: await _headers(),
      body: jsonEncode({
        'clinic_id':    clinicId,
        'date':         date,
        'opening_time': openingTime,
        'closing_time': closingTime,
        'max_patients': maxPatients,
      }),
    );
    return _parse(res);
  }

  // ════════════════════════════════════════════════════════
  //  BOOKING
  // ════════════════════════════════════════════════════════

  // Book token — POST /api/booking/book
  static Future<Map<String, dynamic>> bookToken({
    required int patientId,
    required String clinicId,
    required String date,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/booking/book'),
      headers: await _headers(),
      body: jsonEncode({
        'patient_id': patientId,
        'clinic_id':  clinicId,
        'schedule_date': date,
      }),
    );
    return _parse(res);
  }

  // Get my bookings — GET /api/booking/my/:patient_id
  static Future<Map<String, dynamic>> getMyBookings([int patientId = 0]) async {
    final res = await http.get(
      Uri.parse('$baseUrl/booking/my'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // ════════════════════════════════════════════════════════
  //  OTP
  // ════════════════════════════════════════════════════════

  // Send OTP — POST /api/otp/send
  static Future<Map<String, dynamic>> sendOTP({
    required String gmail,
    required String purpose, // 'register' | 'forgot'
    String? nic,
    String? patId,
    String? clinicId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'gmail': gmail,
        'purpose': purpose,
        if (nic != null) 'nic': nic,
        if (patId != null) 'patid': patId,
        if (clinicId != null) 'clinic_id': clinicId,
      }),
    );
    return _parse(res);
  }

  // Verify OTP — POST /api/otp/verify
  static Future<Map<String, dynamic>> verifyOTP({
    required String gmail,
    required String otp,
    required String purpose,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'gmail': gmail, 'otp': otp, 'purpose': purpose}),
    );
    return _parse(res);
  }

  // Reset Password — POST /api/auth/patient/reset-password
  static Future<Map<String, dynamic>> resetPassword({
    required String gmail,
    required String newPassword,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/patient/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'gmail': gmail, 'newPassword': newPassword}),
    );
    return _parse(res);
  }

  // ════════════════════════════════════════════════════════
  //  QUEUE
  // ════════════════════════════════════════════════════════

  // Live queue — GET /api/queue/live/:clinic_id/:date
  static Future<Map<String, dynamic>> getLiveQueue(
      String clinicId, String date) async {
    final res = await http.get(
      Uri.parse('$baseUrl/queue/live/$clinicId/$date'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // Mark done — PUT /api/queue/done/:booking_id
  static Future<Map<String, dynamic>> markDone(int bookingId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/queue/done/$bookingId'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // Mark skip — PUT /api/queue/skip/:booking_id
  static Future<Map<String, dynamic>> markSkip(int bookingId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/queue/skip/$bookingId'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // ════════════════════════════════════════════════════════
  //  HELPER
  // ════════════════════════════════════════════════════════
  static Map<String, dynamic> _parse(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Invalid server response'};
    }
  }

  // ════════════════════════════════════════════════════════
  //  PROFILE  (Step 7-ல் add பண்றோம்)
  // ════════════════════════════════════════════════════════

  // ── Get Profile — GET /api/auth/patient/profile ──────────
  static Future<Map<String, dynamic>> getMyProfile(
      String patId, String clinicId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/patient/profile?patid=$patId&clinic_id=$clinicId'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // ── Update Profile — PUT /api/auth/patient/update ────────
  static Future<Map<String, dynamic>> updateProfile({
    required String patId,
    required String clinicId,
    required String name,
    required String phone,
    required String gmail,
    required String nic,
    String? oldPassword,
    String? newPassword,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/auth/patient/update'),
      headers: await _headers(),
      body: jsonEncode({
        'patid':        patId,
        'clinic_id':    clinicId,
        'name':         name,
        'phone':        phone,
        'gmail':        gmail,
        'nic':          nic,
        if (oldPassword != null) 'old_password': oldPassword,
        if (newPassword != null) 'new_password': newPassword,
      }),
    );
    return _parse(res);
  }

  // ── Delete Account — DELETE /api/auth/patient/delete ─────
  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
    String? patId,
    String? clinicId,
  }) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/auth/patient/delete'),
      headers: await _headers(),
      body: jsonEncode({'password': password}),
    );
    return _parse(res);
  }

  // ── Change Clinic Date (Emergency) ───────────────────────
  // PUT /api/schedule/change-date
  static Future<Map<String, dynamic>> changeClinicDate({
    required String clinicId,
    required String oldDate,
    required String newDate,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/schedule/change-date'),
      headers: await _headers(),
      body: jsonEncode({
        'clinic_id': clinicId,
        'old_date':  oldDate,
        'new_date':  newDate,
      }),
    );
    return _parse(res);
  }

  // ── Delete Clinic Date ────────────────────────────────────
  // DELETE /api/schedule/delete/:id
  static Future<Map<String, dynamic>> deleteClinicDate(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/schedule/delete/$id'),
      headers: await _headers(),
    );
    return _parse(res);
  }
}
