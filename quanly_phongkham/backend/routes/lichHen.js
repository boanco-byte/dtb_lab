const express = require('express');
const router = express.Router();
const pool = require('../db');

// Gọi stored procedure sp_dat_lich
router.post('/dat', async (req, res) => {
  try {
    const { maBN, thoiGian, maBS } = req.body;
    await pool.query('CALL sp_dat_lich($1, $2, $3)', [maBN, thoiGian, maBS]);
    res.status(201).json({ message: 'Đặt lịch thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lấy danh sách lịch hẹn (kèm tên bệnh nhân, bác sĩ)
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
    await pool.query('UPDATE "LichHen" SET "TrangThai" = $1 WHERE "MaLH" = $2', [trangThai, maLH]);
    res.json({ message: 'Cập nhật trạng thái thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// Hủy lịch hẹn (admin)
router.put('/huy/:maLH', async (req, res) => {
  try {
    const { maLH } = req.params;
    // Kiểm tra lịch tồn tại và trạng thái có thể hủy
    const check = await pool.query(
      `SELECT "TrangThai" FROM "LichHen" WHERE "MaLH" = $1`,
      [maLH]
    );
    if (check.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy lịch hẹn' });
    }
    const status = check.rows[0].TrangThai;
    if (!['Chờ khám', 'Đang khám'].includes(status)) {
      return res.status(400).json({ error: 'Không thể hủy lịch đã hoàn thành hoặc đã hủy' });
    }

    await pool.query(
      `UPDATE "LichHen" SET "TrangThai" = 'Đã hủy' WHERE "MaLH" = $1`,
      [maLH]
    );
    res.json({ message: 'Hủy lịch thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;