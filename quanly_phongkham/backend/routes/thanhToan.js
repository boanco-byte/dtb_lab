const express = require('express');
const router = express.Router();
const pool = require('../db');

// Gọi stored procedure sp_thanh_toan_hoa_don
router.post('/hoa-don/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    await pool.query('CALL sp_thanh_toan_hoa_don($1)', [maHD]);
    res.json({ message: 'Thanh toán thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lấy danh sách hoá đơn chưa thanh toán
router.get('/chua-thanh-toan', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT hd.*, bn."HoTen" AS ten_benh_nhan
      FROM "HoaDon" hd
      JOIN "BenhAn" ba ON hd."MaBA" = ba."MaBA"
      JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
      JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
      WHERE hd."TrangThai" = 'Chưa thanh toán'
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;