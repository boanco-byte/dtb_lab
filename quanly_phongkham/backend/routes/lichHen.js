const express = require('express');
const router = express.Router();
const pool = require('../db');

// Đặt lịch (admin)
router.post('/dat', async (req, res) => {
  try {
    const { maBN, ngay, maBS, caSo } = req.body;
    if (!maBN || !ngay) {
      return res.status(400).json({ error: 'Thiếu thông tin bắt buộc' });
    }
    await pool.query('CALL sp_dat_lich($1, $2, $3, $4)', [
      maBN, ngay, maBS || null, caSo || null
    ]);
    res.status(201).json({ message: 'Đặt lịch thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lấy danh sách lịch hẹn
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT lh.*, bn."HoTen" AS ten_benh_nhan, bs."HoTen" AS ten_bac_si
      FROM "LichHen" lh
      JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
      JOIN "BacSi" bs ON lh."MaBS" = bs."MaBS"
      ORDER BY lh."ThoiGianBatDau" DESC
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Cập nhật trạng thái lịch hẹn
router.put('/:maLH/trang-thai', async (req, res) => {
  try {
    const { maLH } = req.params;
    const { trangThai } = req.body;
    const validStatuses = ['Chờ khám', 'Đang khám', 'Đã khám', 'Đã hủy', 'Hoàn thành'];
    if (!validStatuses.includes(trangThai)) {
      return res.status(400).json({ error: 'Trạng thái không hợp lệ' });
    }
    await pool.query('UPDATE "LichHen" SET "TrangThai" = $1 WHERE "MaLH" = $2', [trangThai, maLH]);
    res.json({ message: 'Cập nhật trạng thái thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Hủy lịch (admin)
router.put('/huy/:maLH', async (req, res) => {
  try {
    await pool.query('CALL sp_huy_lich($1)', [req.params.maLH]);
    res.json({ message: 'Hủy lịch thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Tạo bệnh án từ lịch hẹn
router.post('/:maLH/benh-an', async (req, res) => {
  try {
    const { maLH } = req.params;
    const { ChanDoan, TrieuChung, GhiChu } = req.body;
    const check = await pool.query(
      `SELECT "MaLH" FROM "LichHen" WHERE "MaLH" = $1 AND "TrangThai" = 'Đã khám'`,
      [maLH]
    );
    if (check.rows.length === 0) {
      return res.status(400).json({ error: 'Lịch hẹn chưa ở trạng thái Đã khám' });
    }
    const exist = await pool.query(`SELECT "MaBA" FROM "BenhAn" WHERE "MaLH" = $1`, [maLH]);
    if (exist.rows.length > 0) {
      return res.status(400).json({ error: 'Bệnh án đã tồn tại' });
    }
    const result = await pool.query(
      `INSERT INTO "BenhAn" ("MaLH", "ChanDoan", "TrieuChung", "GhiChu")
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [maLH, ChanDoan || '', TrieuChung || '', GhiChu || '']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/dat', async (req, res) => {
  try {
    const { maBN, ngay, maBS, caSo } = req.body;
    if (!maBN || !ngay) {
      return res.status(400).json({ error: 'Thiếu thông tin bắt buộc' });
    }
    console.log('🟢 Đặt lịch với:', { maBN, ngay, maBS, caSo });
    await pool.query('CALL sp_dat_lich($1, $2, $3, $4)', [
      maBN, ngay, maBS || null, caSo || null
    ]);
    res.status(201).json({ message: 'Đặt lịch thành công' });
  } catch (err) {
    console.error('🔴 Lỗi đặt lịch:', err);  // 👈 LOG LỖI CHI TIẾT
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;