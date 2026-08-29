// ============================================================
//  CareQueue — routes/booking.js + routes/queue.js (COMBINED)
//  Book Token, My Bookings, Live Queue, Done, Skip
// ============================================================

// ── BOOKING ROUTES (routes/booking.js) ───────────────────

const express  = require('express');
const router   = express.Router();
const db       = require('../db');
const jwt      = require('jsonwebtoken');
const { sendNotificationEmail } = require('../emailService');

function auth(req, res, next) {
  const h = req.headers['authorization'];
  if (!h) return res.json({ success: false, message: 'No token' });
  try { req.user = jwt.verify(h.replace('Bearer ', ''), process.env.JWT_SECRET); next(); }
  catch { res.json({ success: false, message: 'Invalid token' }); }
}

// ════════════════════════════════════════════════════════
//  BOOK TOKEN
//  POST /api/booking/book
// ════════════════════════════════════════════════════════
router.post('/book', auth, (req, res) => {
  const { clinic_id, schedule_date } = req.body;
  const patient_id = req.user.id; // from JWT

  if (!clinic_id || !schedule_date)
    return res.json({ success: false, message: 'clinic_id & schedule_date required!' });

  // 1. Check date exists and get max_patients
  db.query(
    'SELECT * FROM clinic_dates WHERE clinic_id = ? AND schedule_date = ?',
    [clinic_id, schedule_date],
    (err, dateRows) => {
      if (!dateRows || dateRows.length === 0)
        return res.json({ success: false, message: 'Date not found!' });

      const maxP = dateRows[0].max_patients;

      // 2. Check already booked by this patient for this date
      db.query(
        `SELECT id FROM bookings
         WHERE patient_id = ? AND clinic_id = ? AND schedule_date = ?`,
        [patient_id, clinic_id, schedule_date],
        (err2, existing) => {
          if (existing && existing.length > 0)
            return res.json({ success: false, message: 'Already booked for this date!' });

          // 3. Count current bookings
          db.query(
            `SELECT COUNT(*) AS cnt FROM bookings
             WHERE clinic_id = ? AND schedule_date = ? AND status != 'skipped'`,
            [clinic_id, schedule_date],
            (err3, countRows) => {
              const booked = countRows[0].cnt;
              if (booked >= maxP)
                return res.json({ success: false, message: 'Fully booked!' });

              const tokenNumber = booked + 1;

              // 4. Insert booking
              db.query(
                `INSERT INTO bookings (patient_id, clinic_id, schedule_date, token_number, status)
                 VALUES (?, ?, ?, ?, 'waiting')`,
                [patient_id, clinic_id, schedule_date, tokenNumber],
                (err4, result) => {
                  if (err4) return res.json({ success: false, message: err4.message });

                  // 5. Check current token & send immediate email if close
                  db.query(
                    `SELECT MAX(b.token_number) AS currentToken, c.name AS clinic_name,
                            p.name AS patient_name, p.gmail
                     FROM bookings b
                     JOIN clinics c ON b.clinic_id = c.clinic_id
                     JOIN patients p ON p.id = ?
                     WHERE b.clinic_id = ? AND b.schedule_date = ? AND b.status = 'done'`,
                    [patient_id, clinic_id, schedule_date],
                    (err5, cr) => {
                      if (!err5 && cr && cr[0] && cr[0].currentToken) {
                        const currentToken = cr[0].currentToken;
                        const diff = tokenNumber - currentToken;
                        const data = {
                          patientName:  cr[0].patient_name,
                          currentToken: currentToken,
                          yourToken:    tokenNumber,
                          clinicName:   cr[0].clinic_name,
                        };
                        if (diff === 3)      sendNotificationEmail(cr[0].gmail, 'ready',    data);
                        else if (diff === 1) sendNotificationEmail(cr[0].gmail, 'urgent',   data);
                        else if (diff === 0) sendNotificationEmail(cr[0].gmail, 'yourturn', data);
                      }
                    }
                  );

                  res.json({
                    success: true,
                    token_number: tokenNumber,
                    booking_id:   result.insertId
                  });
                }
              );
            }
          );
        }
      );
    }
  );
});

// ════════════════════════════════════════════════════════
//  GET MY BOOKINGS
//  GET /api/booking/my
// ════════════════════════════════════════════════════════
router.get('/my', auth, (req, res) => {
  const patient_id = req.user.id;
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

  db.query(
    `SELECT
       b.id, b.token_number, b.schedule_date, b.status,
       b.clinic_id, b.booked_at,
       c.name       AS clinic_name,
       c.doctor_name,
       cd.opening_time,
       cd.closing_time
     FROM bookings b
     JOIN clinics c      ON b.clinic_id = c.clinic_id
     LEFT JOIN clinic_dates cd
       ON b.clinic_id = cd.clinic_id AND b.schedule_date = cd.schedule_date
     WHERE b.patient_id = ?
       AND b.schedule_date >= ?
       AND NOT (b.schedule_date = ? AND b.status IN ('done','skipped'))
     ORDER BY b.schedule_date ASC`,
    [patient_id, today, today],
    (err, rows) => {
      if (err) return res.json({ success: false, message: err.message });
      res.json({ success: true, bookings: rows });
    }
  );
});

module.exports = router;
