const express = require('express');
const router = express.Router();
const pool = require('../db');

// ============================================================
// LẤY DANH SÁCH HÓA ĐƠN CHƯA THANH TOÁN
// ============================================================
router.get('/chua-thanh-toan', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT hd.*, bn."HoTen" AS ten_benh_nhan
      FROM "HoaDon" hd
      JOIN "BenhAn" ba ON hd."MaBA" = ba."MaBA"
      JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
      JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
      WHERE hd."TrangThai" = 'Chưa thanh toán'
      ORDER BY hd."NgayXuat" DESC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Lỗi lấy hóa đơn chưa thanh toán:', err);
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// LẤY DANH SÁCH HÓA ĐƠN THEO NGÀY
// ============================================================
router.get('/theo-ngay', async (req, res) => {
  try {
    const { ngay, trangThai } = req.query;
    let query = `
      SELECT hd.*, bn."HoTen" AS ten_benh_nhan, bn."MaBN"
      FROM "HoaDon" hd
      JOIN "BenhAn" ba ON hd."MaBA" = ba."MaBA"
      JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
      JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
      WHERE 1=1
    `;
    const params = [];
    if (ngay) {
      query += ` AND DATE(hd."NgayXuat") = $1`;
      params.push(ngay);
    }
    if (trangThai) {
      query += ` AND hd."TrangThai" = $${params.length + 1}`;
      params.push(trangThai);
    }
    query += ` ORDER BY hd."NgayXuat" DESC`;
    if (!ngay) {
      query += ` LIMIT 100`;
    }
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Lỗi lấy hóa đơn theo ngày:', err);
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// LẤY CHI TIẾT HÓA ĐƠN
// ============================================================
router.get('/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    if (!/^\d+$/.test(maHD)) {
      return res.status(400).json({ error: 'Mã hóa đơn không hợp lệ' });
    }
    const hdResult = await pool.query(`
      SELECT hd.*, bn."HoTen" AS ten_benh_nhan, bn."MaBN"
      FROM "HoaDon" hd
      JOIN "BenhAn" ba ON hd."MaBA" = ba."MaBA"
      JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
      JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
      WHERE hd."MaHD" = $1
    `, [maHD]);
    if (hdResult.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy hóa đơn' });
    }
    const hoaDon = hdResult.rows[0];
    const chiTietResult = await pool.query(`
      SELECT dt."MaDon", dt."SoLuong", dt."LieuDung", 
             t."TenThuoc", t."DonGia", t."DonVi"
      FROM "DonThuoc" dt
      JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
      WHERE dt."MaBA" = $1
    `, [hoaDon.MaBA]);
    hoaDon.chi_tiet = chiTietResult.rows;
    res.json(hoaDon);
  } catch (err) {
    console.error('Lỗi lấy chi tiết hóa đơn:', err);
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// THANH TOÁN TIỀN KHÁM
// ============================================================
router.post('/tien-kham/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    const { phuongThuc } = req.body;
    await pool.query('CALL sp_thanh_toan_tien_kham($1, $2)', [maHD, phuongThuc || 'Tiền mặt']);
    res.json({ message: 'Thanh toán tiền khám thành công' });
  } catch (err) {
    console.error('Lỗi thanh toán tiền khám:', err);
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// THANH TOÁN TIỀN THUỐC
// ============================================================
router.post('/tien-thuoc/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    const { phuongThuc } = req.body;
    await pool.query('CALL sp_thanh_toan_thuoc($1, $2)', [maHD, phuongThuc || 'Tiền mặt']);
    res.json({ message: 'Thanh toán tiền thuốc thành công' });
  } catch (err) {
    console.error('Lỗi thanh toán tiền thuốc:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;