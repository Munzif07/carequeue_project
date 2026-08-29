// ============================================================
//  CareQueue — emailService.js
//  NodeMailer — English + Tamil + Sinhala
// ============================================================
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_PASS,
  },
  pool: true,          // reuse one authenticated connection instead of
                        // opening a new SMTP login per email (bursts of
                        // fresh logins are what get throttled/dropped)
  maxConnections: 1,
  maxMessages: 50,
  rateDelta: 1000,      // together: max 3 emails per second
  rateLimit: 3,
});

// ════════════════════════════════════════════════════════
//  Email Templates — 3 Languages
// ════════════════════════════════════════════════════════
function getEmailContent(type, data) {
  const { patientName, currentToken, yourToken, clinicName } = data;
  const diff = yourToken - currentToken;

  const templates = {

    // ── Difference = 4 (Get Ready)
    ready: {
      subject: `🏥 CareQueue – Get Ready | தயாராகுங்கள் | සූදානම් වන්න`,
      html: `
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:1px solid #e0e0e0;border-radius:10px;overflow:hidden;">
          <div style="background:#00897b;padding:20px;text-align:center;">
            <h2 style="color:white;margin:0;">🏥 ${clinicName}</h2>
            <p style="color:#e0f2f1;margin:5px 0;">CareQueue Notification</p>
          </div>
          <div style="padding:25px;">

            <p style="font-size:16px;">Dear <strong>${patientName}</strong>,</p>

            <div style="background:#e8f5e9;border-left:4px solid #43a047;padding:15px;border-radius:5px;margin:15px 0;">
              <p style="margin:0;font-size:15px;">⏳ <strong>Your appointment is approaching. Please get ready!</strong></p>
            </div>

            <table style="width:100%;border-collapse:collapse;margin:15px 0;">
              <tr style="background:#f5f5f5;">
                <td style="padding:10px;border:1px solid #ddd;">Current Token</td>
                <td style="padding:10px;border:1px solid #ddd;text-align:center;font-size:20px;font-weight:bold;color:#e53935;">${currentToken}</td>
              </tr>
              <tr>
                <td style="padding:10px;border:1px solid #ddd;">Your Token</td>
                <td style="padding:10px;border:1px solid #ddd;text-align:center;font-size:20px;font-weight:bold;color:#00897b;">${yourToken}</td>
              </tr>
              <tr style="background:#f5f5f5;">
                <td style="padding:10px;border:1px solid #ddd;">Patients Ahead</td>
                <td style="padding:10px;border:1px solid #ddd;text-align:center;font-weight:bold;">${diff} patients</td>
              </tr>
            </table>

            <hr style="border:none;border-top:1px solid #eee;margin:20px 0;">

            <!-- Tamil -->
            <div style="background:#fff8e1;padding:15px;border-radius:5px;margin:10px 0;">
              <p style="margin:0;color:#f57f17;font-weight:bold;">🔔 தமிழ்</p>
              <p style="margin:8px 0;">அன்பான <strong>${patientName}</strong>,</p>
              <p style="margin:0;">உங்கள் முறை நெருங்கி வருகிறது. தயவுசெய்து தயாராகுங்கள்!<br>
              தற்போதைய டோக்கன்: <strong>${currentToken}</strong> | உங்கள் டோக்கன்: <strong>${yourToken}</strong><br>
              இன்னும் <strong>${diff}</strong> பேர் உங்களுக்கு முன்னால் உள்ளனர்.</p>
            </div>

            <!-- Sinhala -->
            <div style="background:#e8eaf6;padding:15px;border-radius:5px;margin:10px 0;">
              <p style="margin:0;color:#3949ab;font-weight:bold;">🔔 සිංහල</p>
              <p style="margin:8px 0;">ආදරණීය <strong>${patientName}</strong>,</p>
              <p style="margin:0;">ඔබේ පිළිගැනීමේ වේලාව ළඟා වෙමින් පවතී. කරුණාකර සූදානම් වන්න!<br>
              වත්මන් ටෝකනය: <strong>${currentToken}</strong> | ඔබේ ටෝකනය: <strong>${yourToken}</strong><br>
              ඔබට ඉදිරියෙන් <strong>${diff}</strong> දෙනෙකු සිටිති.</p>
            </div>

          </div>
          <div style="background:#f5f5f5;padding:12px;text-align:center;">
            <p style="margin:0;color:#999;font-size:12px;">CareQueue – ${clinicName} | Powered by Sri Murugan Clinic</p>
          </div>
        </div>
      `,
    },

    // ── Difference = 2 (Urgent — Come Now)
    urgent: {
      subject: `🚨 CareQueue – Come Now! | இப்போதே வாருங்கள்! | දැන් එන්න!`,
      html: `
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:1px solid #e0e0e0;border-radius:10px;overflow:hidden;">
          <div style="background:#e53935;padding:20px;text-align:center;">
            <h2 style="color:white;margin:0;">🏥 ${clinicName}</h2>
            <p style="color:#ffcdd2;margin:5px 0;">URGENT – CareQueue Alert</p>
          </div>
          <div style="padding:25px;">

            <p style="font-size:16px;">Dear <strong>${patientName}</strong>,</p>

            <div style="background:#ffebee;border-left:4px solid #e53935;padding:15px;border-radius:5px;margin:15px 0;">
              <p style="margin:0;font-size:16px;color:#b71c1c;">🚨 <strong>URGENT! Please come to the clinic immediately!</strong></p>
            </div>

            <table style="width:100%;border-collapse:collapse;margin:15px 0;">
              <tr style="background:#ffebee;">
                <td style="padding:10px;border:1px solid #ddd;">Current Token</td>
                <td style="padding:10px;border:1px solid #ddd;text-align:center;font-size:22px;font-weight:bold;color:#e53935;">${currentToken}</td>
              </tr>
              <tr>
                <td style="padding:10px;border:1px solid #ddd;">Your Token</td>
                <td style="padding:10px;border:1px solid #ddd;text-align:center;font-size:22px;font-weight:bold;color:#00897b;">${yourToken}</td>
              </tr>
              <tr style="background:#ffebee;">
                <td style="padding:10px;border:1px solid #ddd;">Patients Ahead</td>
                <td style="padding:10px;border:1px solid #ddd;text-align:center;font-weight:bold;color:#e53935;">${diff} patients only!</td>
              </tr>
            </table>

            <hr style="border:none;border-top:1px solid #eee;margin:20px 0;">

            <!-- Tamil -->
            <div style="background:#fff8e1;padding:15px;border-radius:5px;margin:10px 0;">
              <p style="margin:0;color:#f57f17;font-weight:bold;">🚨 தமிழ்</p>
              <p style="margin:8px 0;">அன்பான <strong>${patientName}</strong>,</p>
              <p style="margin:0;color:#b71c1c;"><strong>உடனடியாக மருத்துவமனைக்கு வாருங்கள்!</strong><br>
              தற்போதைய டோக்கன்: <strong>${currentToken}</strong> | உங்கள் டோக்கன்: <strong>${yourToken}</strong><br>
              இன்னும் <strong>${diff}</strong> பேர் மட்டுமே உங்களுக்கு முன்னால்!</p>
            </div>

            <!-- Sinhala -->
            <div style="background:#e8eaf6;padding:15px;border-radius:5px;margin:10px 0;">
              <p style="margin:0;color:#3949ab;font-weight:bold;">🚨 සිංහල</p>
              <p style="margin:8px 0;">ආදරණීය <strong>${patientName}</strong>,</p>
              <p style="margin:0;color:#b71c1c;"><strong>වහාම රෝහලට එන්න!</strong><br>
              වත්මන් ටෝකනය: <strong>${currentToken}</strong> | ඔබේ ටෝකනය: <strong>${yourToken}</strong><br>
              ඔබට ඉදිරියෙන් <strong>${diff}</strong> දෙනෙකු පමණයි!</p>
            </div>

          </div>
          <div style="background:#f5f5f5;padding:12px;text-align:center;">
            <p style="margin:0;color:#999;font-size:12px;">CareQueue – ${clinicName} | Powered by Sri Murugan Clinic</p>
          </div>
        </div>
      `,
    },

    // ── Difference = 0 (Your Turn!)
    yourturn: {
      subject: `✅ CareQueue – It's Your Turn! | உங்கள் முறை! | ඔබේ වාරය!`,
      html: `
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:1px solid #e0e0e0;border-radius:10px;overflow:hidden;">
          <div style="background:#2e7d32;padding:20px;text-align:center;">
            <h2 style="color:white;margin:0;">🏥 ${clinicName}</h2>
            <p style="color:#c8e6c9;margin:5px 0;">IT'S YOUR TURN!</p>
          </div>
          <div style="padding:25px;">

            <p style="font-size:16px;">Dear <strong>${patientName}</strong>,</p>

            <div style="background:#e8f5e9;border-left:4px solid #2e7d32;padding:15px;border-radius:5px;margin:15px 0;text-align:center;">
              <p style="margin:0;font-size:22px;color:#1b5e20;">✅ <strong>IT'S YOUR TURN! Please enter the doctor's room now.</strong></p>
            </div>

            <div style="text-align:center;margin:20px 0;">
              <div style="display:inline-block;background:#2e7d32;color:white;border-radius:50%;width:80px;height:80px;line-height:80px;font-size:32px;font-weight:bold;">
                ${yourToken}
              </div>
              <p style="color:#666;margin-top:10px;">Your Token Number</p>
            </div>

            <hr style="border:none;border-top:1px solid #eee;margin:20px 0;">

            <!-- Tamil -->
            <div style="background:#fff8e1;padding:15px;border-radius:5px;margin:10px 0;">
              <p style="margin:0;color:#f57f17;font-weight:bold;">✅ தமிழ்</p>
              <p style="margin:8px 0;">அன்பான <strong>${patientName}</strong>,</p>
              <p style="margin:0;color:#1b5e20;"><strong>இப்போது உங்கள் முறை!</strong> தயவுசெய்து டாக்டரின் அறைக்கு உள்ளே வாருங்கள்.<br>
              உங்கள் டோக்கன் எண்: <strong>${yourToken}</strong></p>
            </div>

            <!-- Sinhala -->
            <div style="background:#e8eaf6;padding:15px;border-radius:5px;margin:10px 0;">
              <p style="margin:0;color:#3949ab;font-weight:bold;">✅ සිංහල</p>
              <p style="margin:8px 0;">ආදරණීය <strong>${patientName}</strong>,</p>
              <p style="margin:0;color:#1b5e20;"><strong>දැන් ඔබේ වාරය!</strong> කරුණාකර දැන් වෛද්‍යවරයාගේ කාමරයට ඇතුළු වන්න.<br>
              ඔබේ ටෝකන් අංකය: <strong>${yourToken}</strong></p>
            </div>

          </div>
          <div style="background:#f5f5f5;padding:12px;text-align:center;">
            <p style="margin:0;color:#999;font-size:12px;">CareQueue – ${clinicName} | Powered by Sri Murugan Clinic</p>
          </div>
        </div>
      `,
    },
  };

  return templates[type] || null;
}

// ════════════════════════════════════════════════════════
//  Send Email Function
// ════════════════════════════════════════════════════════
async function sendNotificationEmail(toEmail, type, data) {
  const content = getEmailContent(type, data);
  if (!content) return false;

  try {
    await transporter.sendMail({
      from: `"CareQueue 🏥" <${process.env.GMAIL_USER}>`,
      to:   (toEmail || '').trim(),
      subject: content.subject,
      html:    content.html,
    });
    console.log(`✅ Email sent [${type}] → ${toEmail}`);
    return true;
  } catch (err) {
    console.error(`❌ Email failed → ${toEmail}:`, err.message);
    return false;
  }
}

module.exports = { sendNotificationEmail, transporter };
