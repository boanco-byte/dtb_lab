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
    res.json({ tong: parseFloat(result.rows[0].tong) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Doanh thu theo khoảng ngày (lấy tất cả loại)
router.get('/doanh-thu-ngay', async (req, res) => {
  try {
    const { tuNgay, denNgay } = req.query;
    if (!tuNgay || !denNgay) {
      return res.status(400).json({ error: 'Thiếu tham số tuNgay hoặc denNgay' });
    }
    const result = await pool.query(`
      SELECT DATE("NgayGhiNhan") AS ngay, SUM("DoanhThu") AS tong
      FROM "ChiTietDoanhThu"
      WHERE "NgayGhiNhan" BETWEEN $1 AND $2
      GROUP BY ngay
      ORDER BY ngay ASC
    `, [tuNgay, denNgay]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// (Tùy chọn) Doanh thu theo loại
router.get('/doanh-thu-ngay-theo-loai', async (req, res) => {
  try {
    const { tuNgay, denNgay, loai } = req.query;
    if (!tuNgay || !denNgay || !loai) {
      return res.status(400).json({ error: 'Thiếu tham số' });
    }
    const result = await pool.query(`
      SELECT DATE("NgayGhiNhan") AS ngay, SUM("DoanhThu") AS tong
      FROM "ChiTietDoanhThu"
      WHERE "NgayGhiNhan" BETWEEN $1 AND $2 AND "Loai" = $3
      GROUP BY ngay
      ORDER BY ngay ASC
    `, [tuNgay, denNgay, loai]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});