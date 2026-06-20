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

// Lấy lịch làm việc của bác sĩ theo ngày
router.get('/lich-lam-viec', async (req, res) => {
  try {
    const { ngay } = req.query;
    if (!ngay) {
      return res.status(400).json({ error: 'Thiếu tham số ngày' });
    }

    // Lấy tất cả bác sĩ
    const bsResult = await pool.query('SELECT "MaBS", "HoTen" FROM "BacSi" ORDER BY "HoTen"');

    // Lấy ca làm việc của từng bác sĩ trong ngày
    const result = [];
    for (let bs of bsResult.rows) {
      // Lấy ca làm việc
      const ca = await pool.query(
        `SELECT "BatDau", "KetThuc" FROM "CaLamViec" 
         WHERE "MaBS" = $1 AND "NgayLam" = $2`,
        [bs.MaBS, ngay]
      );
      // Nếu không có ca làm việc thì bỏ qua
      if (ca.rows.length === 0) continue;

      // Lấy lịch hẹn đã đặt trong ngày đó của bác sĩ
      const lichHen = await pool.query(
        `SELECT "ThoiGianBatDau", "ThoiGianKetThuc", "TrangThai", "MaBN"
         FROM "LichHen"
         WHERE "MaBS" = $1 AND DATE("ThoiGianBatDau") = $2
         AND "TrangThai" NOT IN ('Đã hủy')`,
        [bs.MaBS, ngay]
      );

      // Tạo danh sách các khung giờ (mỗi 30 phút hoặc 1 giờ)
      const slots = [];
      const batDau = ca.rows[0].BatDau;
      const ketThuc = ca.rows[0].KetThuc;
      let current = new Date(ngay + 'T' + batDau);
      const end = new Date(ngay + 'T' + ketThuc);
      while (current < end) {
        const next = new Date(current.getTime() + 30 * 60000); // 30 phút
        // Kiểm tra xem có lịch hẹn nào trùng với khoảng thời gian này không
        const busy = lichHen.rows.some(lh => {
          const start = new Date(lh.ThoiGianBatDau);
          const endApp = new Date(lh.ThoiGianKetThuc);
          return (current >= start && current < endApp) || (next > start && next <= endApp);
        });
        slots.push({
          start: current.toTimeString().slice(0,5),
          end: next.toTimeString().slice(0,5),
          busy: busy
        });
        current = next;
      }

      result.push({
        MaBS: bs.MaBS,
        HoTen: bs.HoTen,
        slots: slots
      });
    }

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;