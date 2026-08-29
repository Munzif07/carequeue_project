const express  = require('express');
const router   = express.Router();
const db       = require('../db');
const jwt      = require('jsonwebtoken');
const { sendNotificationEmail } = require('../emailService');

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

// ════════════════════════════
//  Helper — check & send email
// ════════════════════════════
async function checkAndNotify(currentToken, patientToken, patientName, gmail, clinicName) {
  const diff = patientToken - currentToken;
  const data = { patientName, currentToken, yourToken: patientToken, clinicName };

  if (diff === 3)      return sendNotificationEmail(gmail, 'ready',   data);
  if (diff === 1)      return sendNotificationEmail(gmail, 'urgent',  data);
  if (diff === 0)      return sendNotificationEmail(gmail, 'yourturn',data);
  return null; // no notification due for this patient
}

// ════════════════════════════
//  GET LIVE QUEUE
// ════════════════════════════
router.get('/live/:clinic_id/:date', auth, (req, res) => {
  const { clinic_id, date } = req.params;
  db.query(
    `SELECT b.id, b.token_number, b.status, b.schedule_date,
            p.name AS patient_name, p.patid, p.phone
     FROM bookings b
     JOIN patients p ON b.patient_id = p.id
     WHERE b.clinic_id = ? AND b.schedule_date = ?
     ORDER BY b.token_number ASC`,
    [clinic_id, date],
    (err, rows) => {
      if (err) return res.json({ success: false, message: err.message });
      res.json({ success: true, queue: rows });
    }
  );
});

// ════════════════════════════
//  MARK DONE + EMAIL
// ════════════════════════════
router.put('/done/:booking_id', auth, (req, res) => {
  const { booking_id } = req.params;

  db.query(`UPDATE bookings SET status = 'done' WHERE id = ?`, [booking_id], (err) => {
    if (err) return res.json({ success: false, message: err.message });

    db.query(
      `SELECT b.token_number, b.clinic_id, b.schedule_date, c.name AS clinic_name
       FROM bookings b
       JOIN clinics c ON b.clinic_id = c.clinic_id
       WHERE b.id = ?`,
      [booking_id],
      (err2, rows) => {
        if (err2 || !rows.length)
          return res.json({ success: true, message: 'Marked done' });

        const { token_number: currentToken, clinic_id, schedule_date, clinic_name } = rows[0];

        // Get all waiting patients
        db.query(
          `SELECT b.token_number, p.name AS patient_name, p.gmail
           FROM bookings b
           JOIN patients p ON b.patient_id = p.id
           WHERE b.clinic_id = ? AND b.schedule_date = ? AND b.status = 'waiting'
           ORDER BY b.token_number ASC`,
          [clinic_id, schedule_date],
          async (err3, patients) => {
            if (err3) return res.json({ success: true, message: 'Marked done' });

            // Send emails one-by-one (not all at once) so Gmail doesn't
            // silently throttle/drop a burst of near-simultaneous sends.
            // Failures are collected and reported back instead of only
            // being logged on the server.
            const failed = [];
            for (const p of patients) {
              const ok = await checkAndNotify(
                currentToken, p.token_number, p.patient_name, p.gmail, clinic_name
              );
              if (ok === false) failed.push(p.gmail);
            }

            res.json({
              success: true,
              message: failed.length
                ? `Marked done. ${failed.length} notification(s) failed to send.`
                : 'Marked done & notifications sent!',
              failedEmails: failed,
            });
          }
        );
      }
    );
  });
});

// ════════════════════════════
//  MARK SKIP
// ════════════════════════════
router.put('/skip/:booking_id', auth, (req, res) => {
  const { booking_id } = req.params;
  db.query(`UPDATE bookings SET status = 'skipped' WHERE id = ?`, [booking_id], (err) => {
    if (err) return res.json({ success: false, message: err.message });
    res.json({ success: true, message: 'Marked as skipped!' });
  });
});

// ════════════════════════════
//  UPCOMING QUEUE (Doctor)
// ════════════════════════════
router.get('/upcoming/:clinic_id', auth, (req, res) => {
  const { clinic_id } = req.params;
  const today = new Date().toISOString().split('T')[0];

  db.query(
    `SELECT schedule_date FROM clinic_dates
     WHERE clinic_id = ? AND schedule_date >= ?
     ORDER BY schedule_date ASC LIMIT 1`,
    [clinic_id, today],
    (err, dateRows) => {
      if (err) return res.json({ success: false, message: err.message });
      if (!dateRows || !dateRows.length)
        return res.json({ success: true, queue: [], date: null });

      const nextDate = dateRows[0].schedule_date;
      db.query(
        `SELECT b.id, b.token_number, b.status, b.schedule_date,
                p.name AS patient_name, p.patid, p.phone
         FROM bookings b
         JOIN patients p ON b.patient_id = p.id
         WHERE b.clinic_id = ? AND b.schedule_date = ?
         ORDER BY b.token_number ASC`,
        [clinic_id, nextDate],
        (err2, rows) => {
          if (err2) return res.json({ success: false, message: err2.message });
          res.json({ success: true, queue: rows, date: nextDate });
        }
      );
    }
  );
});

module.exports = router;
