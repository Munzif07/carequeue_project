const { isOTPVerified, clearOTP } = require('./otp');
// ============================================================
//  CareQueue — routes/auth.js (COMPLETE VERSION)
//  Patient Register, Login, Profile, Update, Delete
//  Doctor Login
// ============================================================

const express = require('express');
const router  = express.Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const db      = require('../db');

// ── JWT Middleware ────────────────────────────────────────
function auth(req, res, next) {
  const h = req.headers['authorization'];
  if (!h) return res.json({ success: false, message: 'No token' });
  try {
    req.user = jwt.verify(h.replace('Bearer ', ''), process.env.JWT_SECRET);
    next();
  } catch {
    res.json({ success: false, message: 'Invalid token' });
  }
}

// ════════════════════════════════════════════════════════
//  PATIENT REGISTER
//  POST /api/auth/patient/register
// ════════════════════════════════════════════════════════
router.post('/patient/register', async (req, res) => {
  const { name, nic, phone, gmail, patid, clinic_id, password } = req.body;

  if (!name || !nic || !phone || !gmail || !patid || !clinic_id || !password) {
    return res.json({ success: false, message: 'All fields required!' });
  }

  // Must verify OTP before registering
  if (!isOTPVerified(gmail)) {
    return res.json({ success: false, message: 'Email not verified! Please verify OTP first.' });
  }

  // Check Gmail already exists
  db.query('SELECT id FROM patients WHERE gmail = ?', [gmail], async (err, rows) => {
    if (rows && rows.length > 0)
      return res.json({ success: false, message: 'Gmail already registered!' });

    // Check NIC already exists
    db.query('SELECT id FROM patients WHERE nic = ?', [nic], async (errNic, nicRows) => {
      if (nicRows && nicRows.length > 0)
        return res.json({ success: false, message: 'This NIC is already registered!' });

      // Check Patient ID already exists in this clinic
      db.query(
        'SELECT id FROM patients WHERE patid = ? AND clinic_id = ?',
        [patid, clinic_id],
        async (err2, rows2) => {
          if (rows2 && rows2.length > 0)
            return res.json({ success: false, message: 'Patient ID already used!' });

          const hashed = await bcrypt.hash(password, 10);
          db.query(
            `INSERT INTO patients (name, nic, phone, gmail, patid, clinic_id, password)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [name, nic, phone, gmail, patid, clinic_id, hashed],
            (err3, result) => {
              if (err3) return res.json({ success: false, message: 'DB error: ' + err3.message });

              const token = jwt.sign(
                { id: result.insertId, role: 'patient', gmail, patid, clinic_id },
                process.env.JWT_SECRET,
                { expiresIn: '30d' }
              );
              res.json({
                success: true,
                token,
                user: { id: result.insertId, name, gmail, patid, clinic_id }
              });
            }
          );
        }
      );
    });
  });
});

// ════════════════════════════════════════════════════════
//  PATIENT LOGIN
//  POST /api/auth/patient/login
// ════════════════════════════════════════════════════════
router.post('/patient/login', (req, res) => {
  const { gmail, password } = req.body;
  if (!gmail || !password)
    return res.json({ success: false, message: 'Gmail & Password required!' });

  db.query('SELECT * FROM patients WHERE gmail = ?', [gmail], async (err, rows) => {
    if (!rows || rows.length === 0)
      return res.json({ success: false, message: 'Gmail not found!' });

    const user  = rows[0];
    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.json({ success: false, message: 'Wrong password!' });

    const token = jwt.sign(
      { id: user.id, role: 'patient', gmail: user.gmail, patid: user.patid, clinic_id: user.clinic_id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );
    res.json({
      success: true,
      token,
      user: {
        id:        user.id,
        name:      user.name,
        gmail:     user.gmail,
        patid:     user.patid,
        clinic_id: user.clinic_id
      }
    });
  });
});

// ════════════════════════════════════════════════════════
//  PATIENT PROFILE — GET
//  GET /api/auth/patient/profile?patid=P-0001&clinic_id=CLN-2024-001
// ════════════════════════════════════════════════════════
router.get('/patient/profile', auth, (req, res) => {
  const { patid, clinic_id } = req.query;

  db.query(
    `SELECT p.id, p.name, p.nic, p.phone, p.gmail, p.patid, p.clinic_id,
            c.name AS clinic_name, c.doctor_name
     FROM patients p
     LEFT JOIN clinics c ON p.clinic_id = c.clinic_id
     WHERE p.patid = ? AND p.clinic_id = ?`,
    [patid, clinic_id],
    (err, rows) => {
      if (err || !rows || rows.length === 0)
        return res.json({ success: false, message: 'Patient not found!' });
      res.json({ success: true, user: rows[0] });
    }
  );
});

// ════════════════════════════════════════════════════════
//  PATIENT PROFILE — UPDATE
//  PUT /api/auth/patient/update
// ════════════════════════════════════════════════════════
router.put('/patient/update', auth, async (req, res) => {
  const { patid, clinic_id, name, phone, gmail, nic, old_password, new_password } = req.body;

  if (!name || !phone || !gmail || !nic)
    return res.json({ success: false, message: 'All fields required!' });

  // If password change requested
  if (old_password && new_password) {
    db.query(
      'SELECT password FROM patients WHERE patid = ? AND clinic_id = ?',
      [patid, clinic_id],
      async (err, rows) => {
        if (!rows || rows.length === 0)
          return res.json({ success: false, message: 'Patient not found!' });

        const match = await bcrypt.compare(old_password, rows[0].password);
        if (!match)
          return res.json({ success: false, message: 'Current password wrong!' });

        const hashed = await bcrypt.hash(new_password, 10);
        db.query(
          `UPDATE patients SET name=?, phone=?, gmail=?, nic=?, password=?
           WHERE patid=? AND clinic_id=?`,
          [name, phone, gmail, nic, hashed, patid, clinic_id],
          (err2) => {
            if (err2) return res.json({ success: false, message: err2.message });
            res.json({ success: true, message: 'Profile updated!' });
          }
        );
      }
    );
  } else {
    // No password change
    db.query(
      `UPDATE patients SET name=?, phone=?, gmail=?, nic=?
       WHERE patid=? AND clinic_id=?`,
      [name, phone, gmail, nic, patid, clinic_id],
      (err) => {
        if (err) return res.json({ success: false, message: err.message });
        res.json({ success: true, message: 'Profile updated!' });
      }
    );
  }
});

// ════════════════════════════════════════════════════════
//  PATIENT DELETE ACCOUNT
//  DELETE /api/auth/patient/delete
// ════════════════════════════════════════════════════════
router.delete('/patient/delete', auth, async (req, res) => {
  const { password } = req.body;
  const patient_id   = req.user.id; // from JWT — secure

  if (!password)
    return res.json({ success: false, message: 'Password required!' });

  db.query(
    'SELECT * FROM patients WHERE id = ?',
    [patient_id],
    async (err, rows) => {
      if (err) return res.json({ success: false, message: err.message });
      if (!rows || rows.length === 0)
        return res.json({ success: false, message: 'Patient not found!' });

      const match = await bcrypt.compare(password, rows[0].password);
      if (!match) return res.json({ success: false, message: 'Wrong password!' });

      // Delete bookings first (FK constraint), then patient
      db.query('DELETE FROM bookings WHERE patient_id = ?', [patient_id], (err2) => {
        if (err2) return res.json({ success: false, message: err2.message });
        db.query('DELETE FROM patients WHERE id = ?', [patient_id], (err3) => {
          if (err3) return res.json({ success: false, message: err3.message });
          res.json({ success: true, message: 'Account deleted successfully!' });
        });
      });
    }
  );
});

// ════════════════════════════════════════════════════════
//  DOCTOR LOGIN
//  POST /api/auth/doctor/login
// ════════════════════════════════════════════════════════
router.post('/doctor/login', (req, res) => {
  const { clinic_id, password, name } = req.body;
  if (!clinic_id || !password)
    return res.json({ success: false, message: 'Clinic ID & Password required!' });

  db.query(
    'SELECT * FROM clinics WHERE clinic_id = ?',
    [clinic_id],
    async (err, rows) => {
      if (!rows || rows.length === 0)
        return res.json({ success: false, message: 'Clinic not found!' });

      const clinic = rows[0];
      const match  = await bcrypt.compare(password, clinic.password);
      if (!match) return res.json({ success: false, message: 'Wrong password!' });

      const token = jwt.sign(
        { id: clinic.id, role: 'doctor', clinic_id: clinic.clinic_id },
        process.env.JWT_SECRET,
        { expiresIn: '7d' }
      );
      res.json({
        success: true,
        token,
        doctor: {
          id:          clinic.id,
          name:        name || clinic.doctor_name,
          clinic_id:   clinic.clinic_id,
          clinic_name: clinic.name
        }
      });
    }
  );
});

// ════════════════════════════════════════════════════════
//  PATIENT RESET PASSWORD (after OTP verified)
//  POST /api/auth/patient/reset-password
// ════════════════════════════════════════════════════════
router.post('/patient/reset-password', async (req, res) => {
  const { gmail, newPassword } = req.body;
  const { isOTPVerified, clearOTP } = require('./otp');

  if (!gmail || !newPassword)
    return res.json({ success: false, message: 'Gmail and new password required!' });

  if (newPassword.length < 6)
    return res.json({ success: false, message: 'Password must be at least 6 characters!' });

  // Must have verified OTP for 'forgot' purpose
  if (!isOTPVerified(gmail))
    return res.json({ success: false, message: 'OTP not verified! Please verify OTP first.' });

  db.query(
    'SELECT id FROM patients WHERE gmail = ?',
    [gmail.toLowerCase()],
    async (err, rows) => {
      if (err) return res.json({ success: false, message: err.message });
      if (!rows || rows.length === 0)
        return res.json({ success: false, message: 'No account found with this Gmail!' });

      const hashed = await bcrypt.hash(newPassword, 10);
      db.query(
        'UPDATE patients SET password = ? WHERE gmail = ?',
        [hashed, gmail.toLowerCase()],
        (err2) => {
          if (err2) return res.json({ success: false, message: err2.message });
          clearOTP(gmail); // Clear OTP after use
          res.json({ success: true, message: 'Password reset successfully!' });
        }
      );
    }
  );
});

module.exports = router;
