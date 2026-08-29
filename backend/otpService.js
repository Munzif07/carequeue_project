// ============================================================
//  CareQueue — otpService.js
//  In-memory OTP store (expires in 10 minutes)
// ============================================================
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: { user: process.env.GMAIL_USER, pass: process.env.GMAIL_PASS },
});

// In-memory OTP store: { gmail: { otp, expiresAt } }
const _store = {};

// ── Generate 6-digit OTP ──────────────────────────────────
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ── Send OTP to Gmail ─────────────────────────────────────
async function sendOTP(gmail) {
  const otp = generateOTP();
  const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

  _store[gmail.toLowerCase()] = { otp, expiresAt };

  const html = `
    <div style="font-family:Arial,sans-serif;max-width:500px;margin:auto;
                border:1px solid #e0e0e0;border-radius:12px;overflow:hidden;">
      <div style="background:#00897b;padding:20px;text-align:center;">
        <h2 style="color:white;margin:0;">🏥 CareQueue</h2>
        <p style="color:#e0f2f1;margin:5px 0;font-size:13px;">Email Verification</p>
      </div>
      <div style="padding:28px;text-align:center;">
        <p style="font-size:16px;color:#333;">Your one-time verification code:</p>
        <div style="background:#f5f5f5;border-radius:10px;padding:20px;margin:16px 0;">
          <span style="font-size:38px;font-weight:900;letter-spacing:10px;
                       color:#00897b;font-family:monospace;">${otp}</span>
        </div>
        <p style="font-size:13px;color:#888;">
          ⏱ This code expires in <strong>10 minutes</strong>.<br>
          Do not share this code with anyone.
        </p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0;">
        <p style="font-size:12px;color:#aaa;">
          தமிழ்: இந்த குறியீடு 10 நிமிடங்களில் காலாவதியாகும்.<br>
          සිංහල: මෙම කේතය විනාඩි 10 කින් කල් ඉකිවේ.
        </p>
      </div>
      <div style="background:#f5f5f5;padding:10px;text-align:center;">
        <p style="margin:0;color:#999;font-size:11px;">CareQueue — Sri Murugan Clinic</p>
      </div>
    </div>
  `;

  await transporter.sendMail({
    from: `"CareQueue 🏥" <${process.env.GMAIL_USER}>`,
    to: gmail,
    subject: `${otp} — CareQueue Verification Code`,
    html,
  });

  console.log(`✅ OTP sent to ${gmail}`);
  return true;
}

// ── Verify OTP ────────────────────────────────────────────
function verifyOTP(gmail, otp) {
  const key = gmail.toLowerCase();
  const entry = _store[key];

  if (!entry) return { valid: false, reason: 'OTP not found. Please request a new one.' };
  if (Date.now() > entry.expiresAt) {
    delete _store[key];
    return { valid: false, reason: 'OTP expired. Please request a new one.' };
  }
  if (entry.otp !== otp.toString().trim()) {
    return { valid: false, reason: 'Incorrect OTP. Please try again.' };
  }

  delete _store[key]; // consume OTP — one use only
  return { valid: true };
}

// ── Cleanup expired OTPs every 15 min ────────────────────
setInterval(() => {
  const now = Date.now();
  Object.keys(_store).forEach(k => {
    if (_store[k].expiresAt < now) delete _store[k];
  });
}, 15 * 60 * 1000);

module.exports = { sendOTP, verifyOTP };
