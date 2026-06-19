const express = require('express');
const router = express.Router();
const pool = require('../db');

// Middleware kiểm tra bệnh nhân (giả định gửi kèm maBN trong header)
router.use((req, res, next) => {
  const maBN = req.headers['x-mabn'];
  if (!maBN) {
    return res.status(401).json({ error: 'Chưa xác thực' });
  }
  req.maBN = maBN;
  next();
});

// Lấy danh sách lịch hẹn của bệnh nhân
router.get('/lich-hen', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT lh.*, bs."HoTen" AS ten_bac_si
       FROM "LichHen" lh
       JOIN "BacSi" bs ON lh."MaBS" = bs."MaBS"
       WHERE lh."MaBN" = $1
       ORDER BY lh."ThoiGianBatDau" DESC`,
      [req.maBN]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Đặt lịch mới (gọi sp_dat_lich)
router.post('/dat-lich', async (req, res) => {
  try {
    const { thoiGian, maBS } = req.body;
    if (!thoiGian) {
      return res.status(400).json({ error: 'Thiếu thời gian' });
    }
    await pool.query('CALL sp_dat_lich($1, $2, $3)', [req.maBN, thoiGian, maBS || null]);
    res.status(201).json({ message: 'Đặt lịch thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lấy lịch sử khám (bệnh án + đơn thuốc)
router.get('/lich-su-kham', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ba."MaBA", ba."NgayTao", ba."ChanDoan", ba."TrieuChung",
              dt."MaDon", dt."SoLuong", dt."LieuDung", dt."HuongDan",
              t."TenThuoc", t."DonGia"
       FROM "BenhAn" ba
       LEFT JOIN "DonThuoc" dt ON ba."MaBA" = dt."MaBA"
       LEFT JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
       WHERE ba."MaLH" IN (
           SELECT "MaLH" FROM "LichHen" WHERE "MaBN" = $1
       )
       ORDER BY ba."NgayTao" DESC, dt."MaDon"`,
      [req.maBN]
    );
    // Gom nhóm theo bệnh án
    const map = new Map();
    result.rows.forEach(row => {
      const key = row.MaBA;
      if (!map.has(key)) {
        map.set(key, {
          MaBA: row.MaBA,
          NgayTao: row.NgayTao,
          ChanDoan: row.ChanDoan,
          TrieuChung: row.TrieuChung,
          thuoc: []
        });
      }
      if (row.MaDon) {
        map.get(key).thuoc.push({
          TenThuoc: row.TenThuoc,
          SoLuong: row.SoLuong,
          LieuDung: row.LieuDung,
          HuongDan: row.HuongDan,
          DonGia: row.DonGia
        });
      }
    });
    res.json(Array.from(map.values()));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lấy danh sách bác sĩ (có thể lọc theo chuyên khoa)
router.get('/bac-si', async (req, res) => {
  try {
    const { chuyenKhoa } = req.query;
    let query = `
      SELECT bs."MaBS", bs."HoTen", bs."ChuyenKhoa", pk."TenPhong"
      FROM "BacSi" bs
      LEFT JOIN "PhongKham" pk ON bs."MaPK" = pk."MaPK"
      WHERE 1=1
    `;
    const params = [];
    if (chuyenKhoa) {
      query += ` AND bs."ChuyenKhoa" ILIKE $1`;
      params.push(`%${chuyenKhoa}%`);
    }
    query += ` ORDER BY bs."HoTen"`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// Hủy lịch hẹn (bệnh nhân tự hủy)
router.put('/huy-lich/:maLH', async (req, res) => {
  try {
    const { maLH } = req.params;
    // Kiểm tra lịch thuộc về bệnh nhân này và trạng thái cho phép hủy
    const check = await pool.query(
      `SELECT "TrangThai" FROM "LichHen" WHERE "MaLH" = $1 AND "MaBN" = $2`,
      [maLH, req.maBN]
    );
    if (check.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy lịch hẹn hoặc không có quyền' });
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