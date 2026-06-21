const express = require('express');
const router = express.Router();
const pool = require('../db');

// ============================================================
// 1. QUẢN LÝ BỆNH NHÂN
// ============================================================
router.get('/', async (req, res) => {
  try {
    const { search } = req.query;
    let query = 'SELECT * FROM "BenhNhan"';
    const params = [];
    if (search) {
      query += ` WHERE "HoTen" ILIKE $1 OR "MaBN" ILIKE $1`;
      params.push(`%${search}%`);
    }
    query += ` ORDER BY "HoTen"`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/sdt/:sdt', async (req, res) => {
  try {
    const { sdt } = req.params;
    const result = await pool.query('SELECT * FROM "BenhNhan" WHERE "SDT" = $1', [sdt]);
    res.json(result.rows[0] || null);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { HoTen, NgaySinh, GioiTinh, SDT } = req.body;
    await pool.query('BEGIN');
    const countResult = await pool.query('SELECT COUNT(*) FROM "BenhNhan"');
    const count = parseInt(countResult.rows[0].count) + 1;
    const MaBN = 'BN' + String(count).padStart(5, '0');
    const result = await pool.query(
      `INSERT INTO "BenhNhan" ("MaBN", "HoTen", "NgaySinh", "GioiTinh", "SDT")
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [MaBN, HoTen, NgaySinh, GioiTinh, SDT]
    );
    await pool.query('COMMIT');
    res.status(201).json(result.rows[0]);
  } catch (err) {
    await pool.query('ROLLBACK');
    if (err.message.includes('chk_benhnhan_sdt')) {
      res.status(400).json({ error: 'Số điện thoại không hợp lệ!' });
    } else if (err.message.includes('duplicate key')) {
      res.status(400).json({ error: 'Số điện thoại đã tồn tại!' });
    } else {
      res.status(500).json({ error: err.message });
    }
  }
});

router.put('/:maBN', async (req, res) => {
  try {
    const { maBN } = req.params;
    const { HoTen, NgaySinh, GioiTinh, SDT } = req.body;
    const result = await pool.query(
      `UPDATE "BenhNhan" SET "HoTen" = $1, "NgaySinh" = $2, "GioiTinh" = $3, "SDT" = $4
       WHERE "MaBN" = $5 RETURNING *`,
      [HoTen, NgaySinh, GioiTinh, SDT, maBN]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy bệnh nhân' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    if (err.message.includes('chk_benhnhan_sdt')) {
      res.status(400).json({ error: 'Số điện thoại không hợp lệ!' });
    } else {
      res.status(500).json({ error: err.message });
    }
  }
});

router.delete('/:maBN', async (req, res) => {
  try {
    const { maBN } = req.params;
    const check = await pool.query(`SELECT EXISTS (SELECT 1 FROM "LichHen" WHERE "MaBN" = $1)`, [maBN]);
    if (check.rows[0].exists) {
      return res.status(400).json({ error: 'Không thể xóa bệnh nhân đã có lịch hẹn!' });
    }
    await pool.query('DELETE FROM "BenhNhan" WHERE "MaBN" = $1', [maBN]);
    res.json({ message: 'Xóa bệnh nhân thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// 2. QUẢN LÝ BÁC SĨ (cho admin)
// ============================================================
router.get('/bac-si', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT bs."MaBS", bs."HoTen", bs."SDT", bs."MaPK", pk."TenPhong",
             (SELECT COUNT(*) FROM "LichHen" WHERE "MaBS" = bs."MaBS" AND DATE("ThoiGianBatDau") = CURRENT_DATE) AS so_lich_hnay
      FROM "BacSi" bs
      LEFT JOIN "PhongKham" pk ON bs."MaPK" = pk."MaPK"
      ORDER BY bs."HoTen"
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Lỗi lấy danh sách bác sĩ:', err);
    res.status(500).json({ error: err.message });
  }
});

router.get('/bac-si/:maBS/ca-lam-viec', async (req, res) => {
  try {
    const { maBS } = req.params;
    const { ngay } = req.query;
    const ngayLam = ngay || new Date().toISOString().slice(0, 10);
    const result = await pool.query(
      `SELECT * FROM "CaLamViec" WHERE "MaBS" = $1 AND "NgayLam" = $2 ORDER BY "BatDau"`,
      [maBS, ngayLam]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Lỗi lấy ca làm việc:', err);
    res.status(500).json({ error: err.message });
  }
});

router.get('/bac-si/:maBS/lich-hen', async (req, res) => {
  try {
    const { maBS } = req.params;
    const { ngay } = req.query;
    const ngayLam = ngay || new Date().toISOString().slice(0, 10);
    const result = await pool.query(
      `SELECT lh.*, bn."HoTen" AS ten_benh_nhan
       FROM "LichHen" lh
       JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
       WHERE lh."MaBS" = $1 AND DATE(lh."ThoiGianBatDau") = $2
       ORDER BY lh."ThoiGianBatDau"`,
      [maBS, ngayLam]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Lỗi lấy lịch hẹn:', err);
    res.status(500).json({ error: err.message });
  }
});

router.put('/bac-si/:maBS', async (req, res) => {
  try {
    const { maBS } = req.params;
    const { HoTen, SDT, MaPK } = req.body;
    const result = await pool.query(
      `UPDATE "BacSi" SET "HoTen" = $1, "SDT" = $2, "MaPK" = $3 WHERE "MaBS" = $4 RETURNING *`,
      [HoTen, SDT, MaPK, maBS]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy bác sĩ' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// THÊM BÁC SĨ + TỰ ĐỘNG TẠO CA LÀM VIỆC 30 NGÀY
// ============================================================
router.post('/bac-si', async (req, res) => {
  try {
    const { MaBS, HoTen, SDT, MaPK } = req.body;
    if (!MaBS || !HoTen) {
      return res.status(400).json({ error: 'Thiếu thông tin bắt buộc (MaBS, HoTen)' });
    }

    // Bắt đầu transaction
    await pool.query('BEGIN');

    // Kiểm tra MaPK nếu có
    if (MaPK) {
      const check = await pool.query('SELECT 1 FROM "PhongKham" WHERE "MaPK" = $1', [MaPK]);
      if (check.rows.length === 0) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ error: 'Mã phòng khám không tồn tại!' });
      }
    }

    // Thêm bác sĩ
    const result = await pool.query(
      `INSERT INTO "BacSi" ("MaBS", "HoTen", "SDT", "MaPK") 
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [MaBS, HoTen, SDT, MaPK || null]
    );

    const newDoctor = result.rows[0];

    // Tạo ca làm việc cho 30 ngày tới, từ 8h-17h
    const insertCa = `
      INSERT INTO "CaLamViec" ("MaBS", "NgayLam", "BatDau", "KetThuc")
      SELECT $1, d.ngay, '08:00:00'::TIME, '17:00:00'::TIME
      FROM generate_series(
        CURRENT_DATE,
        CURRENT_DATE + 30,
        '1 day'::INTERVAL
      ) AS d(ngay)
      ON CONFLICT ("MaBS", "NgayLam") DO NOTHING
    `;
    await pool.query(insertCa, [MaBS]);

    await pool.query('COMMIT');

    res.status(201).json(newDoctor);
  } catch (err) {
    await pool.query('ROLLBACK');
    if (err.message.includes('duplicate key')) {
      res.status(400).json({ error: 'Mã bác sĩ đã tồn tại!' });
    } else {
      console.error('Lỗi thêm bác sĩ:', err);
      res.status(500).json({ error: err.message });
    }
  }
});

router.delete('/bac-si/:maBS', async (req, res) => {
  try {
    const { maBS } = req.params;
    const check = await pool.query(`SELECT EXISTS (SELECT 1 FROM "LichHen" WHERE "MaBS" = $1)`, [maBS]);
    if (check.rows[0].exists) {
      return res.status(400).json({ error: 'Không thể xóa bác sĩ đã có lịch hẹn!' });
    }
    await pool.query('DELETE FROM "BacSi" WHERE "MaBS" = $1', [maBS]);
    res.json({ message: 'Xóa bác sĩ thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// 3. QUẢN LÝ KHO THUỐC
// ============================================================
router.get('/thuoc', async (req, res) => {
  try {
    const result = await pool.query(`SELECT * FROM "Thuoc" ORDER BY "TenThuoc"`);
    res.json(result.rows);
  } catch (err) {
    console.error('Lỗi lấy danh sách thuốc:', err);
    res.status(500).json({ error: err.message });
  }
});

router.put('/thuoc/:maThuoc', async (req, res) => {
  try {
    const { maThuoc } = req.params;
    const { TenThuoc, DonVi, NhaSX, DonGia, SoLuongTon } = req.body;
    const result = await pool.query(
      `UPDATE "Thuoc" SET "TenThuoc" = $1, "DonVi" = $2, "NhaSX" = $3, "DonGia" = $4, "SoLuongTon" = $5 WHERE "MaThuoc" = $6 RETURNING *`,
      [TenThuoc, DonVi, NhaSX, DonGia, SoLuongTon, maThuoc]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy thuốc' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/thuoc', async (req, res) => {
  try {
    const { MaThuoc, TenThuoc, DonVi, NhaSX, DonGia, SoLuongTon } = req.body;
    if (!MaThuoc || !TenThuoc || !DonGia) {
      return res.status(400).json({ error: 'Thiếu thông tin bắt buộc' });
    }
    const result = await pool.query(
      `INSERT INTO "Thuoc" ("MaThuoc", "TenThuoc", "DonVi", "NhaSX", "DonGia", "SoLuongTon")
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [MaThuoc, TenThuoc, DonVi || 'Viên', NhaSX || null, DonGia, SoLuongTon || 0]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.message.includes('duplicate key')) {
      res.status(400).json({ error: 'Mã thuốc đã tồn tại!' });
    } else {
      res.status(500).json({ error: err.message });
    }
  }
});

router.delete('/thuoc/:maThuoc', async (req, res) => {
  try {
    const { maThuoc } = req.params;
    const check = await pool.query(`SELECT EXISTS (SELECT 1 FROM "DonThuoc" WHERE "MaThuoc" = $1)`, [maThuoc]);
    if (check.rows[0].exists) {
      return res.status(400).json({ error: 'Không thể xóa thuốc đã được kê trong đơn!' });
    }
    await pool.query('DELETE FROM "Thuoc" WHERE "MaThuoc" = $1', [maThuoc]);
    res.json({ message: 'Xóa thuốc thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// 4. BỆNH ÁN
// ============================================================
router.get('/benh-an', async (req, res) => {
  try {
    const { maBN } = req.query;
    let query = `
      SELECT ba.*, lh."MaBN", bn."HoTen" AS ten_benh_nhan, 
             bs."HoTen" AS ten_bac_si, lh."ThoiGianBatDau"
      FROM "BenhAn" ba
      LEFT JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
      LEFT JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
      LEFT JOIN "BacSi" bs ON lh."MaBS" = bs."MaBS"
      WHERE 1=1
    `;
    const params = [];
    if (maBN) {
      query += ` AND lh."MaBN" = $1`;
      params.push(maBN);
    }
    query += ` ORDER BY ba."NgayTao" DESC, ba."MaBA" DESC`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/benh-an/:maBA', async (req, res) => {
  try {
    const { maBA } = req.params;
    const result = await pool.query(
      `SELECT ba.*, lh."MaBN", bn."HoTen" AS ten_benh_nhan,
              bs."HoTen" AS ten_bac_si, lh."ThoiGianBatDau"
       FROM "BenhAn" ba
       LEFT JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
       LEFT JOIN "BenhNhan" bn ON lh."MaBN" = bn."MaBN"
       LEFT JOIN "BacSi" bs ON lh."MaBS" = bs."MaBS"
       WHERE ba."MaBA" = $1`,
      [maBA]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy bệnh án' });
    }
    const benhAn = result.rows[0];
    const thuocResult = await pool.query(
      `SELECT dt.*, t."TenThuoc", t."DonGia"
       FROM "DonThuoc" dt
       JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
       WHERE dt."MaBA" = $1`,
      [maBA]
    );
    benhAn.don_thuoc = thuocResult.rows;
    res.json(benhAn);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/benh-an', async (req, res) => {
  try {
    const { MaLH, ChanDoan, TrieuChung, GhiChu } = req.body;
    if (!MaLH) {
      return res.status(400).json({ error: 'Thiếu mã lịch hẹn' });
    }
    const check = await pool.query(
      `SELECT "MaLH" FROM "LichHen" WHERE "MaLH" = $1 AND "TrangThai" IN ('Chờ khám', 'Đang khám')`,
      [MaLH]
    );
    if (check.rows.length === 0) {
      return res.status(400).json({ error: 'Lịch hẹn không hợp lệ hoặc đã có bệnh án' });
    }
    const result = await pool.query(
      `INSERT INTO "BenhAn" ("MaLH", "ChanDoan", "TrieuChung", "GhiChu")
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [MaLH, ChanDoan, TrieuChung, GhiChu]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/benh-an/:maBA', async (req, res) => {
  try {
    const { maBA } = req.params;
    const { ChanDoan, TrieuChung, GhiChu } = req.body;
    const result = await pool.query(
      `UPDATE "BenhAn" SET "ChanDoan" = $1, "TrieuChung" = $2, "GhiChu" = $3 WHERE "MaBA" = $4 RETURNING *`,
      [ChanDoan, TrieuChung, GhiChu, maBA]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy bệnh án' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/benh-an/:maBA', async (req, res) => {
  try {
    const { maBA } = req.params;
    const check = await pool.query(`SELECT EXISTS (SELECT 1 FROM "DonThuoc" WHERE "MaBA" = $1)`, [maBA]);
    if (check.rows[0].exists) {
      return res.status(400).json({ error: 'Không thể xóa bệnh án đã có đơn thuốc' });
    }
    const checkInvoice = await pool.query(`SELECT EXISTS (SELECT 1 FROM "HoaDon" WHERE "MaBA" = $1)`, [maBA]);
    if (checkInvoice.rows[0].exists) {
      return res.status(400).json({ error: 'Không thể xóa bệnh án đã có hóa đơn' });
    }
    await pool.query(`DELETE FROM "BenhAn" WHERE "MaBA" = $1`, [maBA]);
    res.json({ message: 'Xóa bệnh án thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// 5. ROUTE ĐỘNG
// ============================================================
router.get('/:maBN', async (req, res) => {
  try {
    const { maBN } = req.params;
    const result = await pool.query('SELECT * FROM "BenhNhan" WHERE "MaBN" = $1', [maBN]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy bệnh nhân' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:maBN/benh-an', async (req, res) => {
  try {
    const { maBN } = req.params;
    const bnCheck = await pool.query('SELECT "MaBN" FROM "BenhNhan" WHERE "MaBN" = $1', [maBN]);
    if (bnCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy bệnh nhân' });
    }
    const result = await pool.query(
      `SELECT ba.*, bs."HoTen" AS ten_bac_si, lh."ThoiGianBatDau"
       FROM "BenhAn" ba
       LEFT JOIN "LichHen" lh ON ba."MaLH" = lh."MaLH"
       LEFT JOIN "BacSi" bs ON lh."MaBS" = bs."MaBS"
       WHERE lh."MaBN" = $1
       ORDER BY ba."NgayTao" DESC`,
      [maBN]
    );
    const benhAns = result.rows;
    for (let ba of benhAns) {
      const thuocResult = await pool.query(
        `SELECT dt.*, t."TenThuoc", t."DonGia" FROM "DonThuoc" dt JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc" WHERE dt."MaBA" = $1`,
        [ba.MaBA]
      );
      ba.don_thuoc = thuocResult.rows;
    }
    res.json(benhAns);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;