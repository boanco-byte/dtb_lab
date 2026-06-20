const express = require('express');
const router = express.Router();
const pool = require('../db');

// ============================================================
// 1. CÁC ROUTE CỤ THỂ (ĐẶT TRƯỚC)
// ============================================================

// Lấy danh sách hóa đơn chưa thanh toán
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

// Lấy danh sách hóa đơn theo ngày (hoặc 100 gần nhất)
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

// Thanh toán hóa đơn (POST) – đặt trước route GET động
router.post('/hoa-don/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    await pool.query('CALL sp_thanh_toan_hoa_don($1)', [maHD]);
    res.json({ message: 'Thanh toán thành công' });
  } catch (err) {
    console.error('Lỗi thanh toán hóa đơn:', err);
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// 2. ROUTE ĐỘNG (ĐẶT CUỐI CÙNG)
// ============================================================

// Lấy chi tiết một hóa đơn (GET) – chỉ bắt khi maHD là số nguyên
router.get('/:maHD', async (req, res) => {
  try {
    const { maHD } = req.params;
    // Kiểm tra maHD có phải số nguyên không
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

module.exports = router;