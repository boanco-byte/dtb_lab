const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'quanly_phongkham', // 👈 ĐÚNG database
  password: 'NTD24xyz@',    // 👈 Mật khẩu của bạn
  port: 5432,
  options: '-c search_path=quanly_phongkham,public' // 👈 QUAN TRỌNG
});

module.exports = pool;