const express = require('express');
const router = express.Router();
const pool = require('../db');

// Lấy danh sách bệnh nhân
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM "BenhNhan" ORDER BY "HoTen"');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Tìm theo số điện thoại
router.get('/sdt/:sdt', async (req, res) => {
  try {
    const { sdt } = req.params;
    const result = await pool.query('SELECT * FROM "BenhNhan" WHERE "SDT" = $1', [sdt]);
    res.json(result.rows[0] || null);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Thêm bệnh nhân mới
router.post('/', async (req, res) => {
  try {
    const { MaBN, HoTen, NgaySinh, GioiTinh, SDT } = req.body;
    const result = await pool.query(
      `INSERT INTO "BenhNhan" ("MaBN", "HoTen", "NgaySinh", "GioiTinh", "SDT")
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [MaBN, HoTen, NgaySinh, GioiTinh, SDT]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;