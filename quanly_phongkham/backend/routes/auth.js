const express = require('express');
const router = express.Router();
const pool = require('../db');

// Đăng nhập
router.post('/login', async (req, res) => {
  try {
    const { maBN, matKhau } = req.body;
    if (!maBN || !matKhau) {
      return res.status(400).json({ error: 'Thiếu mã bệnh nhân hoặc mật khẩu' });
    }

    // Kiểm tra bệnh nhân có tồn tại và khớp mật khẩu
    const result = await pool.query(
      `SELECT bn.*, tk."MatKhauHash"
       FROM "BenhNhan" bn
       JOIN "TaiKhoanBenhNhan" tk ON bn."MaBN" = tk."MaBN"
       WHERE bn."MaBN" = $1`,
      [maBN]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Tài khoản không tồn tại' });
    }

    const user = result.rows[0];
    // So sánh mật khẩu (dùng bcrypt hoặc pgcrypto). Ở đây dùng pgcrypto -> dùng hàm crypt trong query
    const check = await pool.query(
      `SELECT crypt($1, $2) = $2 AS match`,
      [matKhau, user.MatKhauHash]
    );

    if (!check.rows[0].match) {
      return res.status(401).json({ error: 'Sai mật khẩu' });
    }

    // Trả về thông tin bệnh nhân (không bao gồm hash)
    delete user.MatKhauHash;
    res.json({ message: 'Đăng nhập thành công', user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;