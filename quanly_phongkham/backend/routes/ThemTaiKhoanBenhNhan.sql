CREATE EXTENSION IF NOT EXISTS pgcrypto;

SET search_path TO quanly_phongkham, public;

-- Bảng tài khoản bệnh nhân
CREATE TABLE IF NOT EXISTS "TaiKhoanBenhNhan" (
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MatKhauHash" VARCHAR(255) NOT NULL,
    PRIMARY KEY ("MaBN")
);

-- Thêm tài khoản mặc định cho các bệnh nhân hiện có (nếu chưa có)
INSERT INTO "TaiKhoanBenhNhan" ("MaBN", "MatKhauHash")
SELECT "MaBN", crypt('123456', gen_salt('bf'))
FROM "BenhNhan"
ON CONFLICT ("MaBN") DO NOTHING;