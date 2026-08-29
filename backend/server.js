// ============================================================
//  CareQueue — server.js
//  Run: node server.js
// ============================================================
const express = require('express');
const cors    = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/booking',  require('./routes/booking'));
app.use('/api/queue',    require('./routes/queue'));
app.use('/api/schedule', require('./routes/schedule'));
app.use('/api/otp',      require('./routes/otp').router);

// Health check
app.get('/api/ping', (_, res) => res.json({ success: true, msg: 'CareQueue API running!' }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ CareQueue Server → http://localhost:${PORT}`);
});
