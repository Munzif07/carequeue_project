// ============================================================
//  CareQueue — routes/otp.js
//  OTP Send + Verify (Registration & Forgot Password)
// ============================================================
const express  = require('express');
const router   = express.Router();
const db       = require('../db');
const { sendNotificationEmail, transporter } = require('../emailService');

// In-memory OTP store: { gmail: { otp, expires, purpose } }
const otpStore = new Map();

// ── Generate 6-digit OTP ─────────────────────────────────
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ── Send OTP Email ────────────────────────────────────────
async function sendOTPEmail(gmail, otp, purpose) {
  const isReg = purpose === 'register';

  const subject = isReg
    ? '🔐 CareQueue — Email Verification OTP | சரிபார்ப்பு குறியீடு | සත්‍යාපන කේතය'
    : '🔑 CareQueue — Password Reset OTP | கடவுச்சொல் மீட்டமைப்பு | මුරපද යළි සැකසීම';

  const html = `
    <div style="font-family:Arial,sans-serif;max-width:500px;margin:auto;
                border:1px solid #e0e0e0;border-radius:12px;overflow:hidden;">
      <div style="background:#00897b;padding:20px;text-align:center;">
        <h2 style="color:white;margin:0;">🏥 CareQueue</h2>
        <p style="color:#e0f2f1;margin:4px 0;font-size:13px;">Sri Murugan Clinic</p>
      </div>
      <div style="padding:28px;">

        <!-- English -->
        <p style="font-size:15px;color:#1a2e2a;">
          ${isReg ? 'Your <b>Email Verification Code</b> for CareQueue registration:'
                  : 'Your <b>Password Reset Code</b> for CareQueue:'}
        </p>

        <!-- OTP Box -->
        <div style="text-align:center;margin:20px 0;">
          <div style="display:inline-block;background:#e8f5f1;border:2px dashed #00897b;
                      border-radius:12px;padding:16px 40px;">
            <p style="margin:0;font-size:36px;font-weight:900;
                      letter-spacing:10px;color:#00897b;">${otp}</p>
          </div>
        </div>
        <p style="text-align:center;color:#888;font-size:13px;margin-top:4px;">
          ⏰ This code expires in <b>10 minutes</b>
        </p>

        <hr style="border:none;border-top:1px solid #eee;margin:20px 0;">

        <!-- Tamil -->
        <div style="background:#fff8e1;padding:14px;border-radius:8px;margin:10px 0;">
          <p style="margin:0;color:#f57f17;font-weight:bold;font-size:13px;">🔐 தமிழ்</p>
          <p style="margin:6px 0;font-size:13px;">
            ${isReg ? 'உங்கள் CareQueue <b>மின்னஞ்சல் சரிபார்ப்பு குறியீடு</b>:'
                    : 'உங்கள் CareQueue <b>கடவுச்சொல் மீட்டமைப்பு குறியீடு</b>:'}
            <b style="color:#00897b;font-size:18px;letter-spacing:5px;"> ${otp}</b><br>
            <span style="color:#999;font-size:12px;">⏰ இந்த குறியீடு 10 நிமிடங்களில் காலாவதியாகும்</span>
          </p>
        </div>

        <!-- Sinhala -->
        <div style="background:#e8eaf6;padding:14px;border-radius:8px;margin:10px 0;">
          <p style="margin:0;color:#3949ab;font-weight:bold;font-size:13px;">🔐 සිංහල</p>
          <p style="margin:6px 0;font-size:13px;">
            ${isReg ? 'ඔබේ CareQueue <b>ඊමේල් සත්‍යාපන කේතය</b>:'
                    : 'ඔබේ CareQueue <b>මුරපද යළි සැකසීමේ කේතය</b>:'}
            <b style="color:#00897b;font-size:18px;letter-spacing:5px;"> ${otp}</b><br>
            <span style="color:#999;font-size:12px;">⏰ මෙම කේතය මිනිත්තු 10 කින් කල් ඉකුත් වේ</span>
          </p>
        </div>

        <p style="color:#aaa;font-size:12px;margin-top:16px;">
          If you did not request this, please ignore this email.
        </p>
      </div>
      <div style="background:#f5f5f5;padding:10px;text-align:center;">
        <p style="margin:0;color:#999;font-size:11px;">CareQueue — Sri Murugan Clinic</p>
      </div>
    </div>`;

  await transporter.sendMail({
    from: `"CareQueue 🏥" <${process.env.GMAIL_USER}>`,
    to:   gmail,
    subject, html,
  });
}

// ════════════════════════════════════════════════════════
//  POST /api/otp/send
//  Send OTP to Gmail
// ════════════════════════════════════════════════════════
router.post('/send', async (req, res) => {
  const { gmail, purpose, nic, patid, clinic_id } = req.body;

  if (!gmail || !purpose)
    return res.json({ success: false, message: 'Gmail and purpose required!' });

  // For register: check Gmail, NIC and Patient ID are not already registered
  if (purpose === 'register') {
    const [gmailRows] = await db.promise().query(
      'SELECT id FROM patients WHERE gmail = ?', [gmail]
    );
    if (gmailRows.length > 0)
      return res.json({ success: false, message: 'This Gmail is already registered!' });

    if (nic) {
      const [nicRows] = await db.promise().query(
        'SELECT id FROM patients WHERE nic = ?', [nic]
      );
      if (nicRows.length > 0)
        return res.json({ success: false, message: 'This NIC is already registered!' });
    }

    if (patid && clinic_id) {
      const [patidRows] = await db.promise().query(
        'SELECT id FROM patients WHERE patid = ? AND clinic_id = ?', [patid, clinic_id]
      );
      if (patidRows.length > 0)
        return res.json({ success: false, message: 'This Patient ID is already used!' });
    }
  }

  // For forgot: check Gmail exists
  if (purpose === 'forgot') {
    const [rows] = await db.promise().query(
      'SELECT id FROM patients WHERE gmail = ?', [gmail]
    );
    if (rows.length === 0)
      return res.json({ success: false, message: 'No account found with this Gmail!' });
  }

  const otp     = generateOTP();
  const expires = Date.now() + 10 * 60 * 1000; // 10 minutes

  otpStore.set(gmail.toLowerCase(), { otp, expires, purpose });

  try {
    await sendOTPEmail(gmail, otp, purpose);
    console.log(`✅ OTP sent [${purpose}] → ${gmail} : ${otp}`);
    res.json({ success: true, message: 'OTP sent to your Gmail!' });
  } catch (err) {
    console.error('❌ OTP email failed:', err.message);
    res.json({ success: false, message: 'Failed to send OTP email. Check Gmail config.' });
  }
});

// ════════════════════════════════════════════════════════
//  POST /api/otp/verify
//  Verify OTP
// ════════════════════════════════════════════════════════
router.post('/verify', (req, res) => {
  const { gmail, otp, purpose } = req.body;

  if (!gmail || !otp)
    return res.json({ success: false, message: 'Gmail and OTP required!' });

  const stored = otpStore.get(gmail.toLowerCase());

  if (!stored)
    return res.json({ success: false, message: 'OTP expired or not sent. Please request again.' });

  if (Date.now() > stored.expires) {
    otpStore.delete(gmail.toLowerCase());
    return res.json({ success: false, message: 'OTP expired! Please request a new one.' });
  }

  if (stored.otp !== otp.trim())
    return res.json({ success: false, message: 'Incorrect OTP! Please try again.' });

  if (purpose && stored.purpose !== purpose)
    return res.json({ success: false, message: 'Invalid OTP purpose.' });

  // OTP correct — don't delete yet (registration will use it)
  // Mark as verified
  stored.verified = true;
  otpStore.set(gmail.toLowerCase(), stored);

  res.json({ success: true, message: 'OTP verified!' });
});

// ════════════════════════════════════════════════════════
//  Helper: check if OTP verified (used by register route)
// ════════════════════════════════════════════════════════
function isOTPVerified(gmail) {
  const stored = otpStore.get(gmail.toLowerCase());
  if (!stored || !stored.verified) return false;
  if (Date.now() > stored.expires) {
    otpStore.delete(gmail.toLowerCase());
    return false;
  }
  return true;
}

function clearOTP(gmail) {
  otpStore.delete(gmail.toLowerCase());
}

module.exports = { router, isOTPVerified, clearOTP };
