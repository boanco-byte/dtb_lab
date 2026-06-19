const express = require('express');
const router = express.Router();
const pool = require('../db');

// Doanh thu theo tháng
router.get('/doanh-thu-thang', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT EXTRACT(YEAR FROM "NgayGhiNhan") AS nam,
             EXTRACT(MONTH FROM "NgayGhiNhan") AS thang,
             SUM("DoanhThu") AS tong
      FROM "ChiTietDoanhThu"
      GROUP BY nam, thang
      ORDER BY nam DESC, thang DESC
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Tổng doanh thu hôm nay
router.get('/hom-nay', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT COALESCE(SUM("DoanhThu"), 0) AS tong
      FROM "ChiTietDoanhThu"
      WHERE "NgayGhiNhan" = CURRENT_DATE
    `);
    res.json({ tong: result.rows[0].tong });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;