const express = require('express');
const router = express.Router();
const pool = require('../db');

router.post('/login', async (req, res) => {
  try {
    const { sdt, matKhau } = req.body;
    console.log('📩 Nhận request đăng nhập:', { sdt, matKhau }); // log để debug

    if (!sdt || !matKhau) {
      return res.status(400).json({ error: 'Thiếu số điện thoại hoặc mật khẩu' });
    }

    // Tìm bệnh nhân theo số điện thoại
    const userResult = await pool.query(
      `SELECT "MaBN", "HoTen", "SDT" FROM "BenhNhan" WHERE "SDT" = $1`,
      [sdt]
    );
    if (userResult.rows.length === 0) {
      return res.status(401).json({ error: 'Số điện thoại không tồn tại' });
    }
    const user = userResult.rows[0];
    const maBN = user.MaBN;

    // Lấy mật khẩu hash
    const passResult = await pool.query(
      `SELECT "MatKhauHash" FROM "TaiKhoanBenhNhan" WHERE "MaBN" = $1`,
      [maBN]
    );
    if (passResult.rows.length === 0) {
      return res.status(401).json({ error: 'Tài khoản chưa được kích hoạt' });
    }
    const hash = passResult.rows[0].MatKhauHash;

    // Kiểm tra mật khẩu
    const check = await pool.query(
      `SELECT crypt($1, $2) = $2 AS match`,
      [matKhau, hash]
    );
    if (!check.rows[0].match) {
      return res.status(401).json({ error: 'Sai mật khẩu' });
    }

    res.json({ message: 'Đăng nhập thành công', user });
  } catch (err) {
    console.error('Lỗi đăng nhập:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;