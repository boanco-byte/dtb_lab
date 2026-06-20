const express = require('express');
const router = express.Router();
const pool = require('../db');

// Middleware kiểm tra bệnh nhân
router.use((req, res, next) => {
  const maBN = req.headers['x-mabn'];
  if (!maBN) {
    return res.status(401).json({ error: 'Chưa xác thực' });
  }
  req.maBN = maBN;
  next();
});

// ============================================================
// 1. LỊCH HẸN
// ============================================================

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

// Đặt lịch mới
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

// Hủy lịch hẹn
router.put('/huy-lich/:maLH', async (req, res) => {
  try {
    const { maLH } = req.params;
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
    await pool.query(`UPDATE "LichHen" SET "TrangThai" = 'Đã hủy' WHERE "MaLH" = $1`, [maLH]);
    res.json({ message: 'Hủy lịch thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// 2. BÁC SĨ (để bệnh nhân chọn khi đặt lịch)
// ============================================================

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

// ============================================================
// 3. LỊCH SỬ KHÁM (BỆNH ÁN + ĐƠN THUỐC + HÓA ĐƠN)
// ============================================================

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
       WHERE ba."MaLH" IN (
           SELECT "MaLH" FROM "LichHen" WHERE "MaBN" = $1
       )
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

// ============================================================
// 4. HÓA ĐƠN
// ============================================================

// Lấy danh sách hóa đơn của bệnh nhân
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

// Lấy chi tiết một hóa đơn (kèm đơn thuốc)
router.get('/hoa-don/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    // Kiểm tra hóa đơn thuộc về bệnh nhân này
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

    // Lấy chi tiết đơn thuốc (nếu có)
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