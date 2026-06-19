const express = require('express');
const router = express.Router();
const pool = require('../db');

// Lấy đơn thuốc theo bệnh án
router.get('/benh-an/:maBA', async (req, res) => {
  try {
    const { maBA } = req.params;
    const result = await pool.query(`
      SELECT dt.*, t."TenThuoc", t."DonGia"
      FROM "DonThuoc" dt
      JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
      WHERE dt."MaBA" = $1
    `, [maBA]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Thêm thuốc vào đơn (hoặc tạo đơn mới)
router.post('/', async (req, res) => {
  try {
    const { MaBA, MaThuoc, SoLuong, LieuDung, HuongDan } = req.body;
    const result = await pool.query(
      `INSERT INTO "DonThuoc" ("MaBA", "MaThuoc", "SoLuong", "LieuDung", "HuongDan", "TrangThai")
       VALUES ($1, $2, $3, $4, $5, 'Chờ xử lý') RETURNING *`,
      [MaBA, MaThuoc, SoLuong, LieuDung, HuongDan]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Xoá thuốc khỏi đơn (gọi sp_xu_ly_thuoc với hành động 'xoa')
router.delete('/', async (req, res) => {
  try {
    const { maBA, maThuoc } = req.body;
    await pool.query('CALL sp_xu_ly_thuoc($1, $2, $3)', ['xoa', maBA, maThuoc]);
    res.json({ message: 'Đã xoá thuốc khỏi đơn' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;