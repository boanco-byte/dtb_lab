const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',          // thay bằng user của bạn
  host: 'localhost',
  database: 'quanly_phongkham',
  password: 'NTD24xyz@', // thay bằng password
  port: 5432,
});

module.exports = pool;