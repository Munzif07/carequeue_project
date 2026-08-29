// ============================================================
//  CareQueue — db.js  (XAMPP MySQL connection)
// ============================================================
const mysql = require('mysql2');

const db = mysql.createConnection({
  host:        'localhost',
  user:        'root',
  password:    '',          // XAMPP default — no password
  database:    'carequeue',
  dateStrings: true         // DATE columns as plain string (fixes timezone shift)
});

db.connect(err => {
  if (err) {
    console.error('❌ MySQL connection failed:', err.message);
    process.exit(1);
  }
  console.log('✅ MySQL Connected → carequeue DB');
});

module.exports = db;
