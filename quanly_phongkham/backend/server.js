const express = require('express');
const cors = require('cors');
const pool = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

// Import routes
const benhNhanRoutes = require('./routes/benhNhan');
const lichHenRoutes = require('./routes/lichHen');
const donThuocRoutes = require('./routes/donThuoc');
const thanhToanRoutes = require('./routes/thanhToan');
const thongKeRoutes = require('./routes/thongKe');
const authRoutes = require('./routes/auth');
const patientRoutes = require('./routes/patient');

// Routes
app.use('/api/benh-nhan', benhNhanRoutes);
app.use('/api/lich-hen', lichHenRoutes);
app.use('/api/don-thuoc', donThuocRoutes);
app.use('/api/thanh-toan', thanhToanRoutes);
app.use('/api/thong-ke', thongKeRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/patient', patientRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK' });
});

const PORT = 5000;
app.listen(PORT, () => {
  console.log(`Server chạy tại http://localhost:${PORT}`);
});


app.use('/api/auth', authRoutes);