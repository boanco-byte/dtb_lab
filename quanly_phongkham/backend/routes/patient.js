const express = require('express');
const router = express.Router();
const pool = require('../db');

router.use((req, res, next) => {
  const maBN = req.headers['x-mabn'];
  if (!maBN) return res.status(401).json({ error: 'Chưa xác thực' });
  req.maBN = maBN;
  next();
});

// Lấy danh sách lịch hẹn
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

// Đặt lịch mới (theo ngày và ca)
router.post('/dat-lich', async (req, res) => {
  try {
    const { ngay, caSo, maBS } = req.body;
    if (!ngay) {
      return res.status(400).json({ error: 'Thiếu ngày khám' });
    }
    await pool.query('CALL sp_dat_lich($1, $2, $3, $4)', [
      req.maBN, ngay, maBS || null, caSo || null
    ]);
    res.status(201).json({ message: 'Đặt lịch thành công' });
  } catch (err) {
    console.error('Lỗi đặt lịch:', err);
    res.status(500).json({ error: err.message });
  }
});

// Hủy lịch hẹn
router.put('/huy-lich/:maLH', async (req, res) => {
  try {
    const { maLH } = req.params;
    await pool.query('CALL sp_huy_lich($1)', [maLH]);
    res.json({ message: 'Hủy lịch thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lấy danh sách bác sĩ (không có chuyên khoa)
router.get('/bac-si', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT bs."MaBS", bs."HoTen", bs."SDT", bs."MaPK", pk."TenPhong"
      FROM "BacSi" bs
      LEFT JOIN "PhongKham" pk ON bs."MaPK" = pk."MaPK"
      ORDER BY bs."HoTen"
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Lịch sử khám + hóa đơn
router.get('/lich-su-kham', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ba."MaBA", ba."NgayTao", ba."ChanDoan", ba."TrieuChung",
              dt."MaDon", dt."SoLuong", dt."LieuDung", dt."HuongDan",
              t."TenThuoc", t."DonGia",
              hd."MaHD", hd."TongTien", hd."TrangThai" AS trang_thai_hoa_don,
              hd."NgayXuat"
       FROM "BenhAn" ba
       LEFT JOIN "DonThuoc" dt ON ba."MaBA" = dt."MaBA"
       LEFT JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
       LEFT JOIN "HoaDon" hd ON ba."MaBA" = hd."MaBA"
       WHERE ba."MaLH" IN (SELECT "MaLH" FROM "LichHen" WHERE "MaBN" = $1)
       ORDER BY ba."NgayTao" DESC, dt."MaDon"`,
      [req.maBN]
    );
    const map = new Map();
    result.rows.forEach(row => {
      const key = row.MaBA;
      if (!map.has(key)) {
        map.set(key, {
          MaBA: row.MaBA,
          NgayTao: row.NgayTao,
          ChanDoan: row.ChanDoan,
          TrieuChung: row.TrieuChung,
          hoaDon: row.MaHD ? {
            MaHD: row.MaHD,
            TongTien: row.TongTien,
            TrangThai: row.trang_thai_hoa_don,
            NgayXuat: row.NgayXuat
          } : null,
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

// Danh sách hóa đơn của bệnh nhân
router.get('/hoa-don', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT hd."MaHD", hd."NgayXuat", hd."TongTien", hd."PhuongThuc", 
              hd."TrangThai", hd."TienKham", hd."TienThuoc",
              ba."MaBA", ba."NgayTao" AS ngay_kham
       FROM "HoaDon" hd
       JOIN "BenhAn" ba ON hd."MaBA" = ba."MaBA"
       JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
       WHERE lh."MaBN" = $1
       ORDER BY hd."NgayXuat" DESC`,
      [req.maBN]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/hoa-don/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    const check = await pool.query(
      `SELECT hd.*, bn."MaBN"
       FROM "HoaDon" hd
       JOIN "BenhAn" ba ON hd."MaBA" = ba."MaBA"
       JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
       JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
       WHERE hd."MaHD" = $1 AND bn."MaBN" = $2`,
      [maHD, req.maBN]
    );
    if (check.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy hóa đơn hoặc không có quyền' });
    }
    const hoaDon = check.rows[0];
    const thuocResult = await pool.query(
      `SELECT dt.*, t."TenThuoc", t."DonGia", t."DonVi"
       FROM "DonThuoc" dt
       JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
       WHERE dt."MaBA" = $1`,
      [hoaDon.MaBA]
    );
    hoaDon.chi_tiet = thuocResult.rows;
    res.json(hoaDon);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;