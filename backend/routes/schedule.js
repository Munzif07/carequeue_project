// ============================================================
//  CareQueue — routes/schedule.js (COMPLETE VERSION)
//  Add Date, Get Dates (with bookedCount), Change Date
// ============================================================

const express = require('express');
const router  = express.Router();
const db      = require('../db');
const jwt     = require('jsonwebtoken');

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

// ── Optional patient decode (doesn't fail if no/other-role token) ──
function optionalPatientId(req) {
  const h = req.headers['authorization'];
  if (!h) return null;
  try {
    const decoded = jwt.verify(h.replace('Bearer ', ''), process.env.JWT_SECRET);
    if (decoded.role === 'patient') return decoded.id;
  } catch {}
  return null;
}

// ════════════════════════════════════════════════════════
//  GET CLINIC DATES (with booked count + "booked by me" flag)
//  GET /api/schedule/dates/:clinic_id
// ════════════════════════════════════════════════════════
router.get('/dates/:clinic_id', (req, res) => {
  const { clinic_id } = req.params;
  const patientId = optionalPatientId(req); // null if doctor / no token

  db.query(
    `SELECT
       cd.id,
       cd.clinic_id,
       cd.schedule_date,
       cd.opening_time,
       cd.closing_time,
       cd.max_patients,
       COUNT(b.id) AS booked_count,
       SUM(CASE WHEN b.patient_id = ? THEN 1 ELSE 0 END) AS my_booking_count
     FROM clinic_dates cd
     LEFT JOIN bookings b
       ON b.clinic_id = cd.clinic_id
       AND b.schedule_date = cd.schedule_date
       AND b.status != 'skipped'
     WHERE cd.clinic_id = ?
     GROUP BY cd.id
     ORDER BY cd.schedule_date ASC`,
    [patientId || 0, clinic_id],
    (err, rows) => {
      if (err) return res.json({ success: false, message: err.message });
      const dates = rows.map(r => ({
        ...r,
        already_booked_by_me: (r.my_booking_count || 0) > 0,
      }));
      res.json({ success: true, dates });
    }
  );
});

// ════════════════════════════════════════════════════════
//  ADD CLINIC DATE
//  POST /api/schedule/add
// ════════════════════════════════════════════════════════
router.post('/add', auth, (req, res) => {
  const { clinic_id, date, opening_time, closing_time, max_patients } = req.body;

  if (!clinic_id || !date || !opening_time || !closing_time)
    return res.json({ success: false, message: 'All fields required!' });

  // Min 3 days check
  const today    = new Date();
  today.setHours(0, 0, 0, 0);
  const selected = new Date(date);
  const diffDays = Math.floor((selected - today) / (1000 * 60 * 60 * 24));
  if (diffDays < 3)
    return res.json({ success: false, message: 'Minimum 3 days ahead date மட்டும்!' });

  // Check duplicate
  db.query(
    'SELECT id FROM clinic_dates WHERE clinic_id = ? AND schedule_date = ?',
    [clinic_id, date],
    (err, rows) => {
      if (rows && rows.length > 0)
        return res.json({ success: false, message: 'இந்த date already add பண்ணாச்சு!' });

      db.query(
        `INSERT INTO clinic_dates (clinic_id, schedule_date, opening_time, closing_time, max_patients)
         VALUES (?, ?, ?, ?, ?)`,
        [clinic_id, date, opening_time, closing_time, max_patients || 20],
        (err2, result) => {
          if (err2) return res.json({ success: false, message: err2.message });
          res.json({ success: true, message: 'Date added!', id: result.insertId });
        }
      );
    }
  );
});

// ════════════════════════════════════════════════════════
//  DELETE CLINIC DATE
//  DELETE /api/schedule/delete/:id
// ════════════════════════════════════════════════════════
router.delete('/delete/:id', auth, (req, res) => {
  const { id } = req.params;

  // Only delete if no bookings
  db.query(
    `SELECT COUNT(*) AS cnt FROM bookings b
     JOIN clinic_dates cd ON b.clinic_id = cd.clinic_id AND b.schedule_date = cd.schedule_date
     WHERE cd.id = ?`,
    [id],
    (err, rows) => {
      if (rows && rows[0].cnt > 0)
        return res.json({ success: false, message: 'Patients already booked — delete பண்ண முடியாது!' });

      db.query('DELETE FROM clinic_dates WHERE id = ?', [id], (err2) => {
        if (err2) return res.json({ success: false, message: err2.message });
        res.json({ success: true, message: 'Date deleted!' });
      });
    }
  );
});

// ════════════════════════════════════════════════════════
//  EMERGENCY DATE CHANGE
//  PUT /api/schedule/change-date
//  Moves all bookings from old_date → new_date
// ════════════════════════════════════════════════════════
router.put('/change-date', auth, (req, res) => {
  const { clinic_id, old_date, new_date } = req.body;

  if (!clinic_id || !old_date || !new_date)
    return res.json({ success: false, message: 'All fields required!' });

  if (old_date === new_date)
    return res.json({ success: false, message: 'New date must be different!' });

  // 1. Update clinic_dates schedule_date
  db.query(
    `UPDATE clinic_dates SET schedule_date = ?
     WHERE clinic_id = ? AND schedule_date = ?`,
    [new_date, clinic_id, old_date],
    (err) => {
      if (err) return res.json({ success: false, message: err.message });

      // 2. Move all bookings to new date (tokens carry over)
      db.query(
        `UPDATE bookings SET schedule_date = ?
         WHERE clinic_id = ? AND schedule_date = ?`,
        [new_date, clinic_id, old_date],
        (err2) => {
          if (err2) return res.json({ success: false, message: err2.message });
          res.json({ success: true, message: 'Date changed! Tokens carried over.' });
        }
      );
    }
  );
});

module.exports = router;
